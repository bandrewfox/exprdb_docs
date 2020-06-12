#!/bin/bash

date

sra_study=$1
sra_study_file=$2
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

if [ -z "$sra_study" ]
then
   error_exit "Usage: $0 [sra name for output folder] [s3 location for sra_study_file]"
fi

if [ -z "$sra_study_file" ]
then
   error_exit "Usage: $0 [sra name for output folder] [s3 location for sra_study_file]"
fi


if [ -z "$s3_url" ]
then
   s3_url="s3://sracopy-needlegenomics/"
fi

echo "sra_study: $sra_study sra_study_file: $sra_study_file s3_url: $s3_url"

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

# copy all files in the fastq directory to s3 destination
ena_study_file="$ena_study.meta.txt"
curl -o $ena_study_file "https://www.ebi.ac.uk/ena/portal/api/search?dataPortal=ena&query=study_accession%3D$ena_study&result=read_run&fields=all"

#aws s3 cp $sra_study_file - | cut -d\, -f1 | grep -v "^Run" > sra_runs.txt


for sra_run in `cat sra_runs.txt`; do
    #echo "the next sra_run is $sra_run"
    echo "aws batch submit-job --job-name sra-copy-job-cli-$sra_run --job-queue first-job-queue --job-definition sra-copy-job-defn --region us-east-1 --container-overrides command=sra-to-s3.sh,$sra_run,$sra_study"
done


rm -f sra_runs.txt
