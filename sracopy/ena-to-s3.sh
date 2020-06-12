#!/bin/bash

date

ena_run=$1
ena_study=$2
s3_url=$S3_URL

echo "Args: $@"
echo "jobId: $AWS_BATCH_JOB_ID"

# Standard function to print an error and exit with a failing return code
error_exit () {
  echo "Error: ${ena_run} - ${1}" >&2
  exit 1
}

# make sure commands can be found
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable."
which curl >/dev/null 2>&1 || error_exit "Unable to curl command."

if [ -z "$AWS_BATCH_JOB_ID" ]
then
   AWS_BATCH_JOB_ID="100"
else
   echo "\$AWS_BATCH_JOB_ID is NOT empty"
fi

if [ -z "$ena_run" ]
then
   ena_run="SRR000066"
fi

if [ -z "$ena_study" ]
then
   ena_study="$ena_run-study"
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
echo "# aws s3 ls $s3_url"
aws s3 ls $s3_url || error_exit "Error while trying 'aws s3 ls $s3_url'"

echo "# df -h ."
df -h .

echo "# Ready to run: ENA run=$ena_run, study=$ena_study, s3_url=$s3_url"
mkdir -p fastq_out

## ok, now finally time to do the work

for ena_file in `echo "$ena_run" | sed "s/\;/\n/g"`; do
    ena_accession="$(echo "${ena_file}" | sed "s/.*\///")"
    echo "curl -o fastq_out/$ena_accession ftp://$ena_file"
done

exit

echo "# ls fastq_out"
ls -l fastq_out/*

# copy all files in the fastq directory to s3 destination
echo "# aws s3 cp fastq_out $s3_url$ena_study/ --recursive"
aws s3 cp fastq_out $s3_url$ena_study/ --recursive


echo "COMPLETED"
### done

