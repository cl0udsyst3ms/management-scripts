FROM centos:7
MAINTAINER "Marcin Taracha" <maarcintaracha@gmail.com>

RUN yum install -y epel-release \
	&& yum install -y unzip


RUN useradd -m developer -s /bin/bash -c "Docker image user"

ENV TERRAFORM_VERSION=0.8.2
COPY terraform_${TERRAFORM_VERSION}_linux_amd64.zip /tmp/terraform_linux_amd64.zip
RUN unzip /tmp/terraform_linux_amd64.zip -d /usr/local/bin

COPY terraform_plan_apply.sh /home/developer/

USER developer

ENTRYPOINT [ "/home/developer/terraform_plan_apply.sh" ]