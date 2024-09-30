# Singlarity demo for the Brno group

**Starting point: deployed singularity**

## Managing the singularity system

* We run in a tmux session to keep things somewhat persistent

* First, set each of the env vars `$SINGULARITY_{HOSTNAME,VERSION,DEPLOYMENT_STATUS}`

    * See `.env` for an example/defaults

    * SINGULARITY_HOSTNAME is the domain name and if it is not set correctly,
    singularity will not work correctly so **double check this step**

    * SINGULARITY_VERSION and SINGULARITY_DEPLOYMENT_STATUS are used for
    display purposes in the website footer and their particular values
    are solely a matter of aesthetic covention

    * The former we usually set with $(git describe HEAD) or a tag and
    the latter is generally empty for a production deployment, (in staging)
    for a staging deployment like inst1.dev.underground.software, and
    (in development) by default and for a local development environment

* We use `podman-compose` to manage our set of rootless `podman` containers

    * The following commands must be run in the root of the singularity
    repository as the read from the `container-compose.yml` configuration file

    * Use `podman-compose build` to build allcontainers, or
    `podman-compose build <xxx>` to build just one container `<xxx>`

    * Use `podman-compose up -d` to bring up all the containers and
    run them in the background, and `podman-compose down` to bring them down

    * To see logs for all container, use `podman-compose logs`, and to see logs
    for only container `<xxx>`, use `podman-compose logs <xxx>`

    * To check which containers are running, use `podman ps`. Unlike the commands
    above, this one can be run in any directory as it interfaces with podman directly.

The rest of this guide assumes that the containers
have been started successfully with `podman-compose up -d`

## Production SSL certificates

Singularity generates self-signed-certificates by default, which are suitable for development use.

We use letsencrypt to obtain free SSL certificates for production use.

Use `sudo systemctl stop nginx && sudo certbot certonly -d <domain> && sudo systemctl start nginx`
and select option 1 when prompted to obtain or renew certifiates for a domain.

To install them in singularity, copy the files
`/etc/letsencrypt/archive/<domain>/{privkey,fullchain}<N>.pem` for the highest observed
value of `N` into some directory and rename them `{privkey,fullchain}.pem`.
Create a tar archive containing these two files and use
`podman volume import singularity_ssl-certs <tarball>` to install the certificate files.
If singularity is running when you perform this operation, use
`podman-compose exec nginx nginx -s reload` to make these changes effective.

## Managing users with warpdrive.sh

* Use the script `orbit/warpdrive.sh` to manage user credentials

* Use `orbit/warpdrive.sh -u <username> -i <ID> -n` to create a new
account with a student ID that can be used on the `/register` page
to display the username and a generated password a single time

* Use `orbit/warpdrive.sh -u <username> -p <password> -n`
to create a new account with a password that can be used to login immediately

* Use `orbit/warpdrive.sh -u <username> -p <password> -m`
oo change the password of an existing user

* Use `orbit/warpdrive.sh -u <usernme> -w`
to delete a user, that is to say, to withdraw them from the course

* Use `orbit/warpdrive.sh -r` to list all existing users, i.e. the roster of students

* Use `orbit/warpdrive.sh -h` to see further documentation on managing user credentials

## Setting up the submission grading repository

Invoke this script anywhere on the system outside of the containers
with `./<script> <path>` to setup the recieving git server.
When a student submits a non-corrupt patchset, singularity will
create a tag named with with the submission ID and push it to the repo.

```
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
```

When run on a previously created repository, this script simply
starts the http server that will recieve from the container.
We suggest running the script as either a backgroud process
on in its own tmux window.

Clone this repo from the server with ssh and checkout tags as decribed below.
The bare repository is located in `<path>/grading.git`.
Ignore any "warning: remote HEAD refers to nonexistent ref, unable to checkout" message.

Use `git fetch --tags` to update the local repo with new submissions.

## Managing assignments with configure.sh

* Use the script `denis/configure.sh` to manage the assignment database

* We named the container `denis` after an intern whose work we needed to
automate after he left to reutrn to unversity

* The palpable absence of denis was a key motivation for us to begin
the development of singularity

* Student submissions to assignment addresses will show up on `/dashboard`
only if they are known to denis

* Use `denis/configure.sh create -a <assignment> -i 0 -p 0 -f 0`
to create an assignment that a student will submit to the address
`<assignment>`@`<domain>`

* `<domain> = muni.kdlp.underground.software` in this demo

* The `-{i,p,f} 0` arguments specify unix timestamps at which to
trigger automation at an initial submission deadline, peer review
submission deadline, and final submission deadline respectively,
but as those events are not relevant to the desired workflow,
it suffices to specify an arbitary timestamp in the past such as 0
to disable the automation

* Use `denis/configure.sh remove -a <assignment>` to remove an assignment

* Use `denis/configure.sh dump` to see the list of assignments known to denis

Once you configure an assignement, a student can submit patchsets
and they will show up on the dashboard.

## Student configuration of `git send-email`

Students should add or update their `.gitconfig` to contain the following:

```
[user]
        name = Your Name Here
        email = <username>@<domain>
[sendemail]
        smtpUser = <username>
        smtpPass = <password>
        smtpserver = <domain>
        smtpserverport = 465
        smtpencryption = ssl
```

Where `<username>` and `<password>` are a set of credentials configured
above using `warpdrive.sh` and `<domain>` is the server hostname assigned
to the `SINGULARITY_HOSTNAME` environment variable at the begining of this guide.

With this configuration, a student can submit patchsets for a given assignment
configured using `configure.sh` described above by using:
`git send-email --to <assignment>@<domain> <patches...>`

Given that the submission address is correct, the dashboard will display
information about the submission, including whether the patchset contains
whitespace errors or does not apply. If the status column says
"pathchset applies" then singularity automation detected no immediate
problems with the patchset.

## Inspecting submissions with inspector.sh

* Use `mailman/inspector.sh` to examine student submissions and lack thereof

* Use `mailman/inspector.sh submissions` to see all student submissions

* Use `mailman/inspector.sh submissions -a <assigment>` to see all student
submissions for an assignment

* Use `mailman/inspector.sh submissions -u <username>` to see all student
submissions by a particular student

* Use `mailman/inspector.sh submissions -u <username> -a <assignment>` to see all student
submissions by a particular student for an assignment

* Use `mailman/inspector.sh missing -a <assignment>` to list students
who have not made any submission for an assignment

## Obtaining the student submission data

* The best way to view the contents of student submissions is to clone
the repository created with the script embedded above to your local
system via ssh

* Student patchset submissions are indexed by git tags named by submission ID

* Each submission ID tag contains the entire patchset content, including
the cover letter as an empty first commit and the "[PATCH x/y]" subject tag
lines that are normally stripped by `git am`.

* The raw email files submitted as a part of student patchsets are stored
in the volume called `singularity_email-mail`

* Use `podman volume export singularity_email-mail > email.tar` to export all
the email data from the container

* Use `podman-compose exec mailman /bin/ash` to run a shelll
in the mailman container, and `cd /var/lib/email/mail` to browse the directory
containing the raw email files

* Each email filename relates to its corresponding submission ID by addition of the
sequence number of the patchset plus one to the submission ID

* Example: A patchset with a cover letter and three patches has submission ID
`0000000066f9997900000019000000`, therefore the filename of the cover letter email
is `0000000066f9997900000019000001` and the filename of email patches 1,2 and 3
are `0000000066f9997900000019000002`, `0000000066f9997900000019000003`, and
`0000000066f9997900000019000004` respectively

## Backups

Singlarity includes two simple scripts for backing up and restoring data.

* Use `backup/backup.sh > <filename>.tar` to create a backup of all singularity data

* Use `backup/restore.sh < <filename>.tar` to restore singularity data
from a previously created backup

* Use `podman volume prune` when singularity is not running to delete all data

Singularity does not provide any further automation for this process, but there are many
options like cronjobs, sleeping in looping scripts, and naming the backup as a function
of `$(date +%s)` that can be used to build a more automated solution.

Note that the patchsets are pushed to a repository outside the container and are not
included in this backup system.

**IMPORTANT** When testing this last night, I discovered that restoring from backup is
currently broken: <https://github.com/underground-software/singularity/issues/179>

## Public dashboard discussion

We've created a demonstration of a public, unifed submission dashboard on the `muni-pubdash`
branch, however recommend against this approach for several reasons:

* The list of submissions will get lengthy and cumbersome to read

* There isn't much benefit to students in seeing all this informtion

* This approach is more inefficient on the backend

* There's no privacy issues or need for student aliases if the page requires authentication

Since the students must store their credentials to submit patchsets,
we believe that nearly everyone will havce little trouble loging into
their submission dashboard.

## Disabled pop service discussion

The `pop` service is enabled by default, however submissions will be hidden by default.
We have not discussed the relevant mechanisms here beause `pop` was not part of
the desired workflow, however as some have expressed desire for an
"authentic mailing list experience", we'd like to discuss this point in more detail.

## Markdown rendering by orbit

The `orbit` container will render content in the `docs` subdirectory tree as `HTML` and serve
the content over `http`, proxied to `https` via the `nginx` container. We serve a branch of
[ILKD_course_materials](https://github.com/underground-software/ILKD_course_materials)
on our instances, and we could adapt this for your workflow or your can continue to adapt your
existing web content as needed.

Either set the environment variable `COMPOSE_FILE="container-compose.yml:container-compose-dev.yml"` or
or invoke `podman-compose -f container-compose-dev.yml -f container-compose.yml build`
and `podman-compose -f container-compose-dev.yml -f container-compose.yml up -d`
to enable live editing of markdown content in a develpoment environment.
When the contains are started in this way, your edits to markdown files in the
`docs` subdirectory tree will be reflected in the `HTML` immediatly upon refreshing
the page page in your browser rather than requiring a rebuild of the `orbit` container.
This disables some security features and is not intended to be used in production.

## More features

Singularity contains a number of other features:

0. A custom-themed (and somewhat mobile friendly) cgit instance that implements http
authentication for clone using our credential system

0. A matrix server with accounts managed by our credential system
and limited by configurable federation

0. As mentioned above, a `pop` service enabling usage of email clients like `mutt`

0. Automated assignment of peer review for student patchsets

0. In development: A more advanced and detailed submission dashboard

- data relationships
