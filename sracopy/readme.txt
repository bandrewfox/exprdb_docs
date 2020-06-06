


# get the sratoolkit from ncbi or my s3
wget https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/2.10.7/sratoolkit.2.10.7-centos_linux64.tar.gz
aws s3 cp --profile=s3user s3://nf-aio-try2-needlegenomics/sratoolkit.2.10.7-centos_linux64.tar.gz .

# extract programs
tar zxvf sratoolkit.2.10.7-centos_linux64.tar.gz

# set path
export PATH=$PATH:/mnt/data/SRA/sratoolkit.2.10.7-centos_linux64/bin/

# test (takes about 10 seconds and makes 2 lines of output
fastq-dump --stdout -X 2 SRR390728

# config open the interactive thing then close - there is probably a way to do this command line
vdb-config -i
#
vdb-config --set-aws-credentials ~/.aws/credentials
vdb-config --report-cloud-identity yes

# get make a list of accessions from the SRA run selector
https://trace.ncbi.nlm.nih.gov/Traces/study/?go=home

# download fastq file for an accession using the jwt file 
fasterq-dump -p SRR10662897

# copy file to s3
aws s3 cp --profile=s3user  SRR10662897.fastq s3://nf-aio-try2-needlegenomics/SRP235677/


##### to run a new instance in us-east-1 for free connections to ncbi
# start a d2.2xlarge instance

aws configure

# check all available media
sudo fdisk -l
# use the first one
sudo mkfs.ext4 /dev/xvdc
# mount it to /mnt
sudo mount -t ext4 /dev/xvdc /mnt

df -h


# alternatively, get them all at once (might not need vdb-config? or aws cred?)
prefetch -p --option-file SRP235677.acc.txt
fasterq-dump -p --split-files SRR10662*/*sra
aws s3 cp SRP235677 s3://nf-aio-try2-needlegenomics/ --recursive


# submit alignment (may need to add another aws cred profile)
aws batch submit-job --job-name nf-core-rnaseq \
   --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694  \
   --job-definition nextflow --container-overrides  \
   command=nf-core/rnaseq,"--reads","'s3://nf-aio-try2-needlegenomics/SRP235677/*fastq'","--genome","GRCh37","--skipTrimming","--skipQC","--singleEnd"



# starting a new m5.xlarge instance (Project=nextflow, 80GB EBS storage)
aws configure
aws s3 cp s3://nf-aio-try2-needlegenomics/sratoolkit.2.10.7-centos_linux64.tar.gz .
tar zxvf sratoolkit.2.10.7-centos_linux64.tar.gz


# not sur ehow to do this with just a simple command. Instead need to open this and then exit before prefetch works
sratoolkit.2.10.7-centos_linux64/bin/vdb-config -i

sratoolkit.2.10.7-centos_linux64/bin/prefetch -p SRR7469669
sratoolkit.2.10.7-centos_linux64/bin/fasterq-dump -p --split-files SRR7469669/SRR7469669.sra

aws s3 cp SRR7469669 s3://nf-aio-try2-needlegenomics/SRP151960/ --recursive



# more .ncbi/user-settings.mkfg
## auto-generated configuration file - DO NOT EDIT ##

/LIBS/GUID = "6a6a4ef7-89ce-44ff-954f-aa79fc2cf275"
/config/default = "false"
/repository/user/ad/public/apps/file/volumes/flatAd = "."
/repository/user/ad/public/apps/refseq/volumes/refseqAd = "."
/repository/user/ad/public/apps/sra/volumes/sraAd = "."
/repository/user/ad/public/apps/sraPileup/volumes/ad = "."
/repository/user/ad/public/apps/sraRealign/volumes/ad = "."
/repository/user/ad/public/root = "."
/repository/user/default-path = "/home/ec2-user/ncbi"


####

Dockerfile:
From amazonlinux:latest
#RUN apt-get update && apt-get --quiet install --yes curl uuid-runtime && apt-get clean
RUN curl -o /root/sratoolkit.tar.gz  https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/current/sratoolkit.current-centos_linux64.tar.gz
RUN yum install -y tar gzip util-linux
RUN mkdir /root/sra
RUN mkdir /root/.ncbi
RUN tar -xvf /root/sratoolkit.tar.gz --strip-components=1 -C /root/sra/
ENV PATH=/root/sra/bin:${PATH}
RUN printf '/LIBS/GUID = "%s"\n' `uuidgen` > /root/.ncbi/user-settings.mkfg
RUN cat /root/.ncbi/user-settings.mkfg

docker build -t sracopy .
docker run -t -i sracopy


