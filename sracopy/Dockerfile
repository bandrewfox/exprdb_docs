From amazonlinux:latest

# install a few important packages
RUN yum install -y util-linux awscli
RUN yum install -y tar gzip which pigz

RUN mkdir /root/sra
RUN mkdir /root/.ncbi

# download sratoolkit and extract the executables to a fixed location
RUN curl -o /root/sratoolkit.tar.gz  https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-centos_linux64.tar.gz
RUN tar -xvf /root/sratoolkit.tar.gz --strip-components=1 -C /root/sra/

# add the sra tools to the path
ENV PATH=/root/sra/bin:${PATH}

# this isn't really needed here since the sra-to-s3.sh script will do this
# (if I only relied on this one then all my images would have the same UUID, and I don't think they want that)
RUN printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg
RUN cat /root/.ncbi/user-settings.mkfg

WORKDIR /root

# copy the script from local dir to the docker image, make sure it is executable
ADD sra-to-s3.sh /usr/local/bin/sra-to-s3.sh
RUN chmod a+x /usr/local/bin/sra-to-s3.sh

ADD ftp-to-s3.sh /usr/local/bin/ftp-to-s3.sh
RUN chmod a+x /usr/local/bin/ftp-to-s3.sh

ADD check_config.sh /usr/local/bin/check_config.sh
RUN chmod a+x /usr/local/bin/check_config.sh

# run this as a command so that the command can be ovveridden
# first two args are the ARS run and the SRA study
CMD ["sra-to-s3.sh"]
#ENTRYPOINT ["sra-to-s3.sh"]

