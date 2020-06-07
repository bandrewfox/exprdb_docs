#!/bin/bash

date

sra_run=$1
sra_study=$2
s3_url=$S3_URL

echo "Args: $@"
echo "jobId: $AWS_BATCH_JOB_ID"

# Standard function to print an error and exit with a failing return code
error_exit () {
  echo "Error: ${sra_run} - ${1}" >&2
  exit 1
}

# make sure commands can be found
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable."
which prefetch >/dev/null 2>&1 || error_exit "Unable to find ncbi tools 'prefetch' executable."
which fasterq-dump >/dev/null 2>&1 || error_exit "Unable to find ncbi tools 'fasterq-dump' executable."

if [ -z "$AWS_BATCH_JOB_ID" ]
then
   AWS_BATCH_JOB_ID="100"
else
   echo "\$AWS_BATCH_JOB_ID is NOT empty"
fi

if [ -z "$sra_run" ]
then
   sra_run="SRR000066"
fi

if [ -z "$sra_study" ]
then
   sra_study="$sra_run-study"
fi

if [ -z "$s3_url" ]
then
   s3_url="s3://sracopy-needlegenomics/"
fi

# make sure s3 url is ok (starts with s3://, ends with a slash, and is reachable
scheme="$(echo "${s3_url}" | cut -d: -f1)"
if [ "${scheme}" != "s3" ]; then
  error_exit "s3_url must be for an S3 object; expecting URL starting with s3:// this is yours:$s3_url"
fi
lastchar="$(echo "${s3_url}" | rev | cut -c 1)"
echo "last char in s3_url is:$lastchar."
if [ "${lastchar}" != "/" ]; then
  s3_url="$s3_url/"
fi
aws s3 ls $s3_url || error_exit "Error while trying 'aws s3 ls $s3_url'"

echo "Ready to run: SRA run=$sra_run, study=$sra_study, s3_url=$s3_url"
mkdir fastq_out
#mkdir $sra_study

# setting a new uuid for ncbi tools
printf '/LIBS/GUID = "%s"\n' `uuidgen` > ~/.ncbi/user-settings.mkfg
cat ~/.ncbi/user-settings.mkfg

## ok, now finally time to do the work

# get the .sra file and save it in the default location (./$sra_run/)
prefetch -p $sra_run

# extract the single end or paired end fastq files from sra file, save it to a directory 
fasterq-dump -p -O fastq_out --split-files $sra_run/$sra_run.sra

# copy all files in the fastq directory to s3 destination
aws s3 cp fastq_out $s3_url$sra_study/ --recursive


### done

