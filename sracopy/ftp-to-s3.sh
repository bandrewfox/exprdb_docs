#!/bin/bash

date

# semi-colon separated list of ftp files without the "ftp://" URI
ftp_files=$1
s3_subdir=$2
s3_url=$S3_URL

echo "Args: $@"
echo "jobId: $AWS_BATCH_JOB_ID"
echo "# df -h ."
df -h .

# Standard function to print an error and exit with a failing return code
error_exit () {
  echo "Error: ${ftp_files} - ${1}" >&2
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

if [ -z "$ftp_files" ]
then
   ftp_files="ftp.sra.ebi.ac.uk/vol1/fastq/SRR746/008/SRR7469668/SRR7469668_1.fastq.gz;ftp.sra.ebi.ac.uk/vol1/fastq/SRR746/008/SRR7469668/SRR7469668_2.fastq.gz"
fi

if [ -z "$s3_subdir" ]
then
   s3_subdir="$AWS_BATCH_JOB_ID"
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

echo "# Ready to run ftp-to-s3"
echo "# ftp_files=$ftp_files"
echo "# s3_subdir=$s3_subdir"
echo "# s3_url=$s3_url"

## ok, now finally time to do the work

# read ftp file to stdout and send straight to s3
for cur_file_full_path in `echo "$ftp_files" | sed "s/\;/\n/g"`; do
    cur_filename="$(echo "${cur_file_full_path}" | sed "s/.*\///")"
    echo "curl ftp://$cur_file_full_path | aws s3 cp - $s3_url$s3_subdir/$cur_filename"
done

echo "COMPLETED"
### done

