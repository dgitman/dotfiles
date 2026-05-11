#!/bin/bash
# ------------------------------------------------------------------
#                  AWS S3 List All Bucket Sizes
#        This lists the total size of all Aamazon Web Services S3 buckets using s3cmd
# ------------------------------------------------------------------
buckets=`s3cmd ls | awk '{FS=" ";print $3}'`
for bucket in $buckets
do
  size=`s3cmd du "$bucket" |awk '{FS=" ";print $1}'`
  sizemb=`expr $size / \\( 1024 \\* 1024 \\)`
  sizegb=`expr $sizemb / 1024`
  echo "$bucket ${sizegb} GB ${sizemb} MB ${size} bytes"
done
