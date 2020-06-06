From amazonlinux:latest
#RUN apt-get update && apt-get --quiet install --yes curl uuid-runtime && apt-get clean
RUN yum install -y util-linux awscli
RUN yum install -y tar gzip which

RUN mkdir /root/sra
RUN mkdir /root/.ncbi

RUN curl -o /root/sratoolkit.tar.gz  https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-centos_linux64.tar.gz

RUN tar -xvf /root/sratoolkit.tar.gz --strip-components=1 -C /root/sra/

ENV PATH=/root/sra/bin:${PATH}

RUN printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg

RUN cat /root/.ncbi/user-settings.mkfg

WORKDIR /root

ADD sra-to-s3.sh /usr/local/bin/sra-to-s3.sh
