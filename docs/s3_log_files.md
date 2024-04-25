# S3 Log Files

Steps to download and parse AWS S3 log files for PDC buckets using the [AWS CLI](https://docs.aws.amazon.com/cli/) tool.

For more examples on the CLI see https://docs.aws.amazon.com/cli/latest/userguide/cli-services-s3-commands.html


## Downloading a list of logs files

Download a list of logs files in the `pdc-describe-logs` bucket that are for production, pre-curation, and the date that we are interested in:

```
aws s3 ls s3://pdc-describe-logs/pdc-describe-prod-precuration2024-04-24 > s3_logs.txt
```

Get the filenames only (must use single quotes!):

```
awk '{ print $4 }' s3_logs.txt > s3_logs_names.txt
```


## Downloading a single file
Download a single file from AWS:

```
aws s3 cp s3://pdc-describe-logs/pdc-describe-prod-precuration2024-04-24-23-49-47-328D98C6D7777E50 ./s3_log_data/
```


## Downloading a batch of log files:

Since the `aws s3 cp` command does not support partial names to download only certain files, we have to rely on the output from the `aws s3 ls` command to do this.

We do this by generating a bash file to download all the files from S3 that the `aws s3 ls` command generated:

```
while read -r line; do echo "aws s3 cp s3://pdc-describe-logs/$line ./s3_log_data/"; done <s3_logs_names.txt > s3_download.sh
```

Run the download script to download each file:

```
mkdir -p ./s3_log_data
chmod u+x s3_download.sh
./s3_download.sh
```


## Finding information about a DOI in the log files:
Now that we have downloaded the files that we are interested, we can grep them and reference a particular DOI (e.g. `10.34770/xtje-mj26`)

```
grep -n xtje-mj26 ./s3_log_data/* > s3_doi.txt
```

Find all files that reference a particular DOI (e.g. `10.34770/xtje-mj26`) excluding GET and HEAD requests:

```
grep -n xtje-mj26 ./s3_log_data/* | grep -v -e GET -e HEAD
```

Notice that in the previous example we are using a partial DOI (e.g. `xtje-mj26` instead of `10.34770/xtje-mj26`) because the `/` requires special encoding.


## A semi-complete script:
```
AWS_DATE=2024-04-23
AWS_DOI=xtje-mj26

aws s3 ls s3://pdc-describe-logs/pdc-describe-prod-precuration$AWS_DATE > s3_logs.txt
awk '{ print $4 }' s3_logs.txt > s3_logs_names.txt
while read -r line; do echo "aws s3 cp s3://pdc-describe-logs/$line ./s3_log_data/"; done <s3_logs_names.txt > s3_download.sh

mkdir -p ./s3_log_data
chmod u+x s3_download.sh
./s3_download.sh

grep -n $AWS_DOI ./s3_log_data/* | grep -v -e GET -e HEAD
```
