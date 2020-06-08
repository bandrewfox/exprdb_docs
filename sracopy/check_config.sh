#!/bin/bash

date

arg1=$1
arg2=$2
s3_url=$S3_URL

if [ -z "$s3_url" ]
then
   s3_url="s3://sracopy-needlegenomics/"
fi

echo "# Args: $@"
echo "# s3_url: $s3_url"
echo "# jobId: $AWS_BATCH_JOB_ID"

echo "# checking container"
echo "# df -h ."
df -h .

# make sure commands can be found
echo "making sure these commands are found: pigz, aws, prefetch, fasterq-dump"
which pigz >/dev/null 2>&1 || echo "ERROR: Unable to find pigz executable."
which aws >/dev/null 2>&1 || echo "ERROR: Unable to find AWS CLI executable."
which prefetch >/dev/null 2>&1 || echo "ERROR: Unable to find ncbi tools 'prefetch' executable."
which fasterq-dump >/dev/null 2>&1 || echo "ERROR: Unable to find ncbi tools 'fasterq-dump' executable."

echo "# checking connection to s3 url: $s3_url"

# make sure s3 url is ok (starts with s3://, ends with a slash, and is reachable
scheme="$(echo "${s3_url}" | cut -d: -f1)"
if [ "${scheme}" != "s3" ]; then
  echo "ERROR: s3_url must be for an S3 object; expecting URL starting with s3:// this is yours:$s3_url"
fi
lastchar="$(echo "${s3_url}" | rev | cut -c 1)"
echo "last char in s3_url is:$lastchar."
if [ "${lastchar}" != "/" ]; then
  s3_url="$s3_url/"
fi
echo "# aws s3 ls $s3_url"
aws s3 ls $s3_url || echo "ERROR: Error while trying 'aws s3 ls $s3_url'"


echo "# checking ncbi toolkit"
printf '/LIBS/GUID = "%s"\n' `uuidgen` > ~/.ncbi/user-settings.mkfg
cat ~/.ncbi/user-settings.mkfg

echo "# fastq-dump --stdout -X 2 SRR390728"
fastq-dump --stdout -X 2 SRR390728


echo "COMPLETED"

