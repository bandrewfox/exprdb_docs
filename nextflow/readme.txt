
MAke an IAM Role which connects EC2 with S3 and Batch and this custom policy
AWSS3FullAccess
AWSBatchFullAccess
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "iam:PassRole",
            "Resource": "arn:aws:iam::538908288835:role/NextflowAllinOne-1030am-Nextflo-IAMNextflowJobRole-1JUYANEZW01XL"
        }
    ]
}

# add EFS
sudo yum update -y
sudo yum install -y amazon-efs-utils
sudo mkdir /mnt/efs
# get this command from the EFS page on the AWS console
sudo mount -t efs fs-3338c836:/ /mnt/efs

## to make a docker host, start an AMI linux 2, and attach the IAM Role defined above
sudo amazon-linux-extras install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
# log out and log in to get group perm, then next command should not be an error
docker info

git clone https://bandrewfox@bitbucket.org/bandrewfox/exprdb_docs.git
mkdir ~/nf_work

##
aws configure for us-west-2
# add user, password and default region


# login creds to docker AWS ECR
aws ecr get-login --profile west  | awk '{print $6}' | docker login --username AWS --password-stdin 538908288835.dkr.ecr.us-west-2.amazonaws.com

### to modify the Docker container
# edit the Dockerfile then:
pushd ~/exprdb_docs/nextflow/nf_bash
docker build -t nextflow .
docker images
docker run -ti nextflow err

docker tag nextflow:latest 538908288835.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest
docker push 538908288835.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest



# submit alignment (may need to add another aws cred profile)
aws batch submit-job --job-name nf-core-rnaseq \
   --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694  \
   --job-definition nextflow --container-overrides  \
   command=nf-core/rnaseq,"--reads","'s3://nf-aio-try2-needlegenomics/SRP235677/*fastq'","--genome","GRCh37","--skipTrimming","--skipQC","--singleEnd"



aws batch submit-job --job-name nf-core-rnaseq    --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694     --job-definition nextflow --container-overrides     command=nf-core/rnaseq,"--reads","'s3://sracopy-needlegenomics/honaker/Ctl1-edit*'","--genome","GRCh37","--singleEnd" > job.json


# find the outputs
 aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/logs/.nextflow.log.9ad4185e-78f9-4c00-8007-73aad2eb79cf.1 - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'  | egrep "^multiqc|^merge_feature"

aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/e8/7e84c227dfa58bab31ce56357f7ff3/merged_gene_counts.txt .
aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/6d/4784ee83c8a24a83ea51bacf1c0bd8 ./multiqc2 --recursive


# use ENA API to get all the fastq ftp locations using the PRJ id
curl -o files.txt 'https://www.ebi.ac.uk/ena/portal/api/search?dataPortal=ena&query=study_accession%3DPRJNA479536&result=read_run&fields=all'


# test run with a few samples

aws batch --profile west submit-job --job-name nf-core-rnaseq    --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694     --job-definition nextflow --container-overrides     command=nf-core/rnaseq,"--reads","'s3://sracopy-needlegenomics/SRP151960/SRR746974*.sra_{1,2}.fastq.gz'","--genome","GRCh37","-resume" > SRP151960-part74.job.json

#####################

# to make nextflow with a bash entry point

# to make an interactive nexflow docker container (i.e. bash instead of directly starting)
pushd nf_bash
docker build -t nextflow_bash --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) .

docker run -v /home/ec2-user/nf_work:/opt/work --rm -ti nextflow_bash bash
su user
# or
docker run -v /mnt/efs/nf_work:/opt/work --rm -ti nextflow_bash bash

# just run a single one:
nextflow run nf-core/rnaseq --reads 's3://sracopy-needlegenomics/SRP151960/SRR7469696*.sra_{1,2}.fastq.gz' --genome GRCh37


