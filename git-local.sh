#!/bin/sh

test -n "$1" || { echo "need path arg"; exit 1 ; }

# If the argument does not exist, configure it as our server
if test ! -e "$1"; then

	# Setup bare git repo ready to receive
	git init --bare "$1/grading.git"
	touch "$1/grading.git/git-daemon-export-ok"
	git -C "$1/grading.git" config http.receivepack true
	git -C "$1/grading.git" update-server-info

	# Setup cgi-based simple git server
	mkdir -p "$1/cgi-bin"
	cat <<EOF > "$1/cgi-bin/git-receive-pack"
#!/bin/sh
exec git http-backend
EOF
	chmod +x "$1/cgi-bin/git-receive-pack"

fi

# Run the server
python -m http.server -d "$1" --cgi 3366
