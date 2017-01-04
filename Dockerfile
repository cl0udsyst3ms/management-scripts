FROM centos:7
MAINTAINER "Marcin Taracha" <maarcintaracha@gmail.com>

RUN useradd -m developer -s /bin/bash -c "Docker image user"

ENV TERRAFORM_VERSION=0.8.2

COPY terraform${TERRAFORM_VERSION} /usr/local/bin/
COPY terraform_plan_apply.sh /home/developer/

USER developer

ENTRYPOINT [ "/home/developer/terraform_plan_apply.sh" ]