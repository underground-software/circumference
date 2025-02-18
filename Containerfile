FROM fedora:latest

RUN dnf update && \
	dnf install -y \
	podman \
	podman-compose \
	jq \
	ShellCheck \
	python3-flake8 \
	git

RUN sed -i 's/log_driver = "journald"/log_driver = "json-file"/' /usr/share/containers/containers.conf

RUN git clone https://github.com/underground-software/singularity && \
	mkdir singularity/{repos,docs}

COPY start.sh .

WORKDIR singularity

ENTRYPOINT ["/start.sh"]
