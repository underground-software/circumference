# deployment before deployment

### run as root

1. install a text editor, git, and tmux

1. create singularity user: `useradd singularity`

dnf install -y vim git

1. Allow http & https traffic through the firewall

```
firewall-cmd --add-service=http --permanent
firewall-cmd --add-service=http
firewall-cmd --add-service=https --permanent
firewall-cmd --add-service=https
firewall-cmd --add-service=pop3s
firewall-cmd --add-service=pop3s --permanent
firewall-cmd --add-service=smtps
firewall-cmd --add-service=smtps --permanent
firewall-cmd --list-services
> dhcpv6-client http https mdns pop3s smtp smtps ssh
```

1. SELinux needs to chill

```
dnf install policycoreutils-devel -y

semanage port -a -t http_port_t -p tcp 995
semanage port -a -t http_port_t -p tcp 465
```

Use this to create loadable module:

```
# cat <<EOF > singularity_policy.te
module singularity_policy 1.0;


require {
    type httpd_t;
    type container_t;
    type container_file_t;
    class sock_file write;
    class unix_stream_socket connectto;
}

#============= httpd_t ==============
allow httpd_t container_file_t:sock_file write;
allow httpd_t container_t:unix_stream_socket connectto;
EOF

checkmodule -M -m -o singularity_policy.mod singularity_policy.te
semodule_package -o singularity_policy.pp -m singularity_policy.mod
semodule -i singularity_policy.pp
```

(if nginx was installed here we would need to restart it)

1. obtain cert and generate dhparams

```
dnf install -y certbot openssl
certbot certonly -d <FQDN>
openssl dhparam -out /etc/letsencrypt/ssl-dhparams.pem 4096
```

1. package certs for singularity

```

cp /etc/letsencrypt/archive/<FQDN>/fullchain1.pem fullchain.pem
cp /etc/letsencrypt/archive/<FQDN>/privkey1.pem privkey.pem
dnf install -y tar
tar cf cert.tar.gz fullchain.pem privkey.pem
chown singularity:singularity cert.tar.gz
mv cert.tar.gz /home/singularity/
```

Alternatively:

sudo tar -C /etc/letsencrypt/live/<FQDN>/ --create --numeric-owner --dereference fullchain.pem privkey.pem > /tmp/cert.tar
sudo chown singularity:singularity /tmp/cert.tar

1. configure nginx

dnf install -y nginx nginx-mod-stream

```
# cat <<EOF> /etc/nginx/nginx.conf
# For more information on configuration, see:
#   * Official English Documentation: http://nginx.org/en/docs/
#   * Official Russian Documentation: http://nginx.org/ru/docs/

user nginx;
worker_processes auto;
pcre_jit on;
error_log stderr warn;
pid /run/nginx.pid;

load_module "/usr/lib64/nginx/modules/ngx_stream_module.so";

events
{
	worker_connections 1024;
}

http
{
	server_tokens off;
	sendfile on;
	tcp_nopush on;
	keepalive_timeout   65;
	types_hash_max_size 4096;

	ssl_protocols TLSv1.2 TLSv1.3;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:2m;
	ssl_session_timeout 1h;
	ssl_session_tickets off;

        ssl_dhparam /etc/letsencrypt/ssl-dhparams.pem;
	ssl_certificate /etc/letsencrypt/live/<FQDN>/fullchain.pem;
	ssl_certificate_key /etc/letsencrypt/live/<FQDN>/privkey.pem;


	log_format main
		'$remote_addr - $remote_user [$time_local] "$request" '
		'$status $body_bytes_sent "$http_referer" '
		'"$http_user_agent" "$http_x_forwarded_for"';

	access_log /var/log/nginx/access.log main;


	include /etc/nginx/mime.types;
	default_type application/octet-stream;

	server
	{
		listen [::]:80 ipv6only=off;
		server_name  _;
		return 301 https://$host$request_uri;
	}
}

stream
{
	upstream https_default
	{
		server unix:/home/singularity/singularity/socks/https.sock;
	}
	upstream smtps_default
	{
		server unix:/home/singularity/singularity/socks/smtps.sock;
	}
	upstream pop3s_default
	{
		server unix:/home/singularity/singularity/socks/pop3s.sock;
	}

	map $ssl_preread_server_name $name
	{
		<FQDN> default;
	}
	server
	{
		listen [::]:443 ipv6only=off;
		proxy_pass https_$name;
		ssl_preread on;
	}
	server
	{
		listen [::]:465 ipv6only=off;
		proxy_pass smtps_$name;
		ssl_preread on;
	}
	server
	{
		listen [::]:995 ipv6only=off;
		proxy_pass pop3s_$name;
		ssl_preread on;
	}
}


systemctl enable --now nginx
```

1. install `podman` and `podman-compose`

```
dnf install -y podman-compose
(may need epel-release for podman-compose
```

1. Change permissions so nginx can access singularity socks drawer

```
chmod o+x /home/singularity/
```

1. drop privileges and deploy singularity from the existing README

Set up `root` matrix user with admin perms to be able to create rooms. This command will prompt for a password.

podman-compose exec submatrix register_new_matrix_user -c /etc/synapse/homeserver.yaml -a -u root
