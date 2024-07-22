#!/bin/sh

while true; do
	podman-compose exec pop /usr/local/bin/init_journal /var/lib/email/journal/journal /var/lib/email/journal/tmp /var/lib/email/mail/
	sleep 5m
done
