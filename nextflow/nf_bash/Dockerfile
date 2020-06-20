FROM centos:7 AS build

RUN yum update -y \
 && yum install -y \
    curl \
    java-1.8.0-openjdk \
    awscli \
 && yum clean -y all

ENV JAVA_HOME /usr/lib/jvm/jre-openjdk/

WORKDIR /opt/inst
RUN curl -s https://get.nextflow.io | bash
RUN mv nextflow /usr/local/bin

COPY nextflow.aws.sh /opt/bin/nextflow.aws.sh
RUN chmod +x /opt/bin/nextflow.aws.sh

WORKDIR /opt/work
#ENTRYPOINT ["/opt/bin/nextflow.aws.sh"]

ARG USER_ID
ARG GROUP_ID

RUN groupadd --gid $GROUP_ID usergroup
RUN adduser --uid $USER_ID --gid $GROUP_ID user
RUN passwd -d user
