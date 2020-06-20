
aws configure for us-west-2

# login creds to docker AWS ECR
aws ecr get-login --profile west  | awk '{print $6}' | docker login --username AWS --password-stdin 538908288835.dkr.ecr.us-west-2.amazonaws.com

# pull the nextflow repo
#docker pull 538908288835.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest

# edit the Dockerfile then: 

docker build -t nextflow .
docker images
docker run -ti nextflow err

docker tag nextflow:latest 538908288835.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest
docker push 538908288835.dkr.ecr.us-west-2.amazonaws.com/nextflow:latest



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



aws batch submit-job --job-name nf-core-rnaseq    --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694     --job-definition nextflow --container-overrides     command=nf-core/rnaseq,"--reads","'s3://sracopy-needlegenomics/honaker/Ctl1-edit*'","--genome","GRCh37","--singleEnd" > job.json


# find the outputs
 aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/logs/.nextflow.log.9ad4185e-78f9-4c00-8007-73aad2eb79cf.1 - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'  | egrep "^multiqc|^merge_feature"

aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/e8/7e84c227dfa58bab31ce56357f7ff3/merged_gene_counts.txt .
aws s3 cp s3://nf-aio-try2-needlegenomics/_nextflow/runs/6d/4784ee83c8a24a83ea51bacf1c0bd8 ./multiqc2 --recursive


# use ENA API to get all the fastq ftp locations using the PRJ id
curl -o files.txt 'https://www.ebi.ac.uk/ena/portal/api/search?dataPortal=ena&query=study_accession%3DPRJNA479536&result=read_run&fields=all'


# test run with a few samples

aws batch --profile west submit-job --job-name nf-core-rnaseq    --job-queue default-c1e558c0-9eaf-11ea-8877-0ae10a278694     --job-definition nextflow --container-overrides     command=nf-core/rnaseq,"--reads","'s3://sracopy-needlegenomics/SRP151960/SRR746974*.sra_{1,2}.fastq.gz'","--genome","GRCh37","-resume" > SRP151960-part74.job.json



# to make an interactive nexflow docker container (i.e. bash instead of directly starting)
pushd nf_bash
docker build -t nextflow_bash --build-arg USER_ID=$(id -u) --build-arg GROUP_ID=$(id -g) .
docker run -v /home/ec2-user/nf_work:/opt/work --rm -ti nextflow_bash bash


# just run a single one:
nextflow run nf-core/rnaseq --reads 's3://sracopy-needlegenomics/SRP151960/SRR7469696*.sra_{1,2}.fastq.gz' --genome GRCh37
