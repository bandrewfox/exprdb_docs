
#### Build the AWS Batch env from AWS Console for Batch

# This is a good walk through which I followed carefully:
https://stackify.com/aws-batch-guide/

# First, make a launch template for a 100 GB disk in case some fastq files are really big
https://aws.amazon.com/premiumsupport/knowledge-center/batch-ebs-volumes-launch-template/

# if you want to change the docker settings on the container host, edit cloud-init.mime.txt
# then paste the output of this unix command into the launch-template-data.json file:
base64 -w 0 cloud-init-user-data.txt >> launch-template-data.json
vi launch-template-data.json

# make the launch template available on EC2
aws ec2 --region us-east-1 create-launch-template --cli-input-json file://launch-template-data.json

# if you edit the json template and don't want to make a new AWS Batch Computer Env, then make a new version and set as default
aws ec2 --region us-east-1 create-launch-template-version --launch-template-name increase-volume-100gb-docker80gb --cli-input-json file://launch-template-data.json
aws ec2 --region us-east-1 modify-launch-template  --launch-template-name increase-volume-100gb-docker80gb --default-version 2

# Create a Compute Environment
- Managed
- name: compute-env-100gb-ebs
- Service role: Create new role
- Instance role: Create new role
- EC2 key pair: can add one if you want to be able to ssh to it
- Instance type: m5.2xlarge, max VCPUs 16
- Networking: default vpc and check off a few or all subnets
- add a tag: Project sracopy

# Create a Job Queue
- name: first-job-queue
- priority: 90
- connect to the compute env you just made

# Create an IAM role for an ECS service task with permissions to the S3 bucket
- Create a Role for an AWS Service
- choose Elastic Container Service Task
- Attach permissions: Create policy with json below and name: S3access-sracopy-needlegenomics (note the actual s3 path in there)
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::sracopy-needlegenomics",
                "arn:aws:s3:::sracopy-needlegenomics/*"
            ]
        }
    ]
}
- Role name: sracopy-ECStasks-s3

# Follow instructions below to make a docker image and save it to the AWS ECR

# Create a Job Definition
- name: sra-copy-job-defn
- attempts: 1
- exec timeout: 3600 seconds
- environment
- job role: sracopy-ECStasks-s3 (made this in the prev step - it can allow ECS tasks to access a specific s3 bucket)
- container image: (check ECR for the image path) [id].[dkr].ecr.us-east-1.amazonaws.com/sracopy:latest
- leave command blank (will override this when submitting job)

# Submit a job
- job name: think of something new
- Job definition: sra-copy-job-defn
- job queue: first-job-queue
- command: sra-to-s3.sh SRR00067 SRP00002  (but use your desired SRA runs)

# or submit a job using the aws cli:

## submit job from awscli to copy fastq files from sra to s3
# (keep everything as is except be sure to pick a unique job-name and the SRR and SRP accessions
aws batch submit-job --job-name sra-copy-job-cli-1 --job-queue first-job-queue --job-definition sra-copy-job-defn --region us-east-1 --container-overrides command=sra-to-s3.sh,SRR000067,SRP000002.5

# or put the accession file from SRA locater into the s3 bucket and run this:
./start-jobs.sh s3://sracopy-needlegenomics/studies/SRP151960.txt


#### make the docker image and upload it to Amazon ECR
# https://docs.aws.amazon.com/AmazonECR/latest/userguide/getting-started-cli.html

# Launch an instance in us-east-1 (that is closest to SRA and has free downloads):
# Pick an amazon linux 2 instance, m4.xlarge
# Attach IAM Role which connects EC2 with Full S3 access (for testing the Dockerfile and sra script)

# with this instance, install docker, start the service, allow ec2-user in docker group
sudo yum update -y
sudo amazon-linux-extras install -y docker
sudo service docker start
sudo usermod -a -G docker ec2-user
# log out and log in to get group perm, then next command should not be an error
docker info

# Need ECR password for docker setup
# run this on an instance (or laptop) with correct IAM credentials
# if using awscli 2.0 then it is "get-login-password"
# copy the password which is printed to stdout
# aws ecr get-login --region us-east-1

# back on the instance with docker running, do this to save the password to the aws ecr repo
# docker login --username AWS 538908288835.dkr.ecr.us-east-1.amazonaws.com

# this does both in one line
aws ecr get-login --region us-east-1 | awk '{print $6}' | docker login --username AWS --password-stdin 538908288835.dkr.ecr.us-east-1.amazonaws.com


# can test/edit Dockerfile and sra-to-s3.sh now by building image, verifying it exists, running image
docker build -t sracopy .
docker images

# this will run the test script
docker run -t -i sracopy check_config.sh arg1 arg2

# this will run the sra copy script, but for a small SRA run
docker run -t -i sracopy

# From the AWS console (or with the following awscli command) make an ECR repository called sracopy
aws ecr create-repository --repository-name sracopy --image-scanning-configuration scanOnPush=true --region us-east-1
# tag the image, then push it to the ECR repo
docker tag sracopy:latest 538908288835.dkr.ecr.us-east-1.amazonaws.com/sracopy:latest
docker push 538908288835.dkr.ecr.us-east-1.amazonaws.com/sracopy:latest

### once that is all setup, it shouldn't need updating

# submit a test job
aws batch submit-job --job-name sra-copy-check-config-123 --job-queue first-job-queue --job-definition sra-copy-job-defn --region us-east-1 --container-overrides command=check_config.sh,myarg1,myarg2

# submit a big fastq file for copying
aws batch submit-job --job-name sra-copy-job-cli-SRR7469743-v2312 --job-queue first-job-queue --job-definition sra-copy-job-defn --region us-east-1 --container-overrides command=sra-to-s3.sh,SRR7469743,SRP151960

#### to perform the alignment with nextflow

## Genomics Workflow Core (GWFCore)
# I tried this but entered in the wrong s3 bucket, I think:
https://console.aws.amazon.com/cloudformation/home?#/stacks/new?stackName=GWFCore-Full&templateURL=https://s3.amazonaws.com/aws-genomics-workflows/templates/aws-genomics-root-novpc.template.yaml

## So I used the All-in-One Nextflow cloudformation stack
https://github.com/aws-samples/aws-genomics-workflows/blob/master/src/templates/nextflow/nextflow-aio.template.yaml

# I can't recall the exact settings I used



# submit alignment (may need to add another aws cred profile)
aws batch submit-job --job-name nf-core-rnaseq \
   --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694  \
   --job-definition nextflow --container-overrides  \
   command=nf-core/rnaseq,"--reads","'s3://nf-aio-try2-needlegenomics/SRP235677/*fastq'","--genome","GRCh37","--skipTrimming","--skipQC","--singleEnd"

#######    cli methods to do some of the aws setup

# compute env
vi compute-env.json
aws batch create-compute-environment --compute-environment-name spot-xlarge-80gb-docker-2 --cli-input-json file://compute-env.json --type MANAGED --service-role arn:aws:iam::538908288835:role/service-role/AWSBatchServiceRole




aws batch submit-job --job-name nf-core-rnaseq    --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694     --job-definition nextflow --container-overrides     command=nf-core/rnaseq,"--reads","'s3://sracopy-needlegenomics/honaker/Ctl1-edit*'","--genome","GRCh37","--singleEnd" > job.json


# find the outputs
 aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/logs/.nextflow.log.9ad4185e-78f9-4c00-8007-73aad2eb79cf.1 - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'  | egrep "^multiqc|^merge_feature"

aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/e8/7e84c227dfa58bab31ce56357f7ff3/merged_gene_counts.txt .
aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/6d/4784ee83c8a24a83ea51bacf1c0bd8 ./multiqc2 --recursive


# use ENA API to get all the fastq ftp locations using the PRJ id
curl -o files.txt 'https://www.ebi.ac.uk/ena/portal/api/search?dataPortal=ena&query=study_accession%3DPRJNA479536&result=read_run&fields=all'

