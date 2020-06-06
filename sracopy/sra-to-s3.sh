#!/bin/bash

date

sra_run=$SRA_RUN
sra_study=$SRA_STUDY
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

if [ -z "$sra_study" ]
then
   sra_study="SRP000002"
fi

if [ -z "$sra_run" ]
then
   sra_run="SRR000066"
fi

if [ -z "$s3_url" ]
then
   s3_url="s3://sracopy-needlegenomics/"
fi

# make sure s3 url is ok
scheme="$(echo "${s3_url}" | cut -d: -f1)"
if [ "${scheme}" != "s3" ]; then
  error_exit "S3_URL must be for an S3 object; expecting URL starting with s3:// this is yours:$s3_url"
fi
lastchar="$(echo "${S3_URL}" | rev | cut -c 1)"
if [ "${lastchar}" != "/" ]; then
  s3_url="$s3_url/"
fi
aws s3 ls $s3_url || error_exit "Error while trying 'aws s3 ls $s3_url'"

echo "Ready to run: SRA run=$sra_run, study=$sra_study, s3_url=$s3_url"
mkdir $sra_study

# setting a new uuid for ncbi tools
printf '/LIBS/GUID = "%s"\n' `uuidgen` > ~/.ncbi/user-settings.mkfg
cat ~/.ncbi/user-settings.mkfg

prefetch -p $sra_run
fasterq-dump -p -O $sra_study --split-files $sra_run/$sra_run.sra
aws s3 cp $sra_study $s3_url/$sra_study/ --recursive

