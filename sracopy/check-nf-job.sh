#!/bin/bash

date

jobid=$1
outname=$2
s3_url="s3://nf-aio-try2-needlegenomics/"

# Standard function to print an error and exit with a failing return code
error_exit () {
  echo "Error: ${sra_run} - ${1}" >&2
  #exit 1
}

if [ -z "${outname}" ]; then
  echo "Usage: $0 jobid outname"
  exit
fi

# make sure commands can be found
which aws >/dev/null 2>&1 || error_exit "Unable to find AWS CLI executable."

# make sure s3 url is ok (starts with s3://, ends with a slash, and is reachable
scheme="$(echo "${s3_url}" | cut -d: -f1)"
if [ "${scheme}" != "s3" ]; then
  error_exit "s3_url must be for an S3 object; expecting URL starting with s3:// this is yours:$s3_url"
fi

# make sure the last char is not a slash
lastchar="$(echo "${s3_url}" | rev | cut -c 1)"
echo "last char in s3_url is: ($lastchar)"
if [ "${lastchar}" == "/" ]; then
  # remove the last char
  s3_url="$(echo "$s3_url" | rev | cut -c 2- | rev)"
fi

echo "# aws s3 ls $s3_url/_nextflow/logs/"
aws s3 ls $s3_url/_nextflow/logs/ || error_exit "Error while trying 'aws s3 ls $s3_url'"


logfile="$(aws s3 ls $s3_url/_nextflow/logs/ | grep $jobid | awk '{print $4}' | sort | tail -1)"
logfile="$s3_url/_nextflow/logs/$logfile"
echo "logfile=$logfile"

qc_dir="$(aws s3 cp $logfile - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'  | grep "^multiqc" | awk '{print $2}')"
merge_dir="$(aws s3 cp $logfile - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'  | grep "^merge_feature" | awk '{print $2}')"

if [ -z "${merge_dir}" ]; then
  echo "aws s3 cp $logfile - | grep COMPLETED"
  aws s3 cp $logfile - | grep COMPLETED | perl -ne '/name: *(\S+).*workDir: *(.*?)\]$/; print "$1\t$2\n"'
  exit
fi

echo "qc_dir=$qc_dir"
aws s3 ls $qc_dir/

echo "merge_dir=$merge_dir"
aws s3 ls $merge_dir/

##  get the files
echo "aws s3 cp $qc_dir/ $outname.multiqc --recursive"
echo "aws s3 cp $merge_dir/merged_gene_counts.txt $outname.merged_gene_counts.txt"
#aws s3 cp $qc_dir/ $outname.multiqc --recursive
#aws s3 cp $merge_dir/merged_gene_counts.txt $outname.merged_gene_counts.txt


