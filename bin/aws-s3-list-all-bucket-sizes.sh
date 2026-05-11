#!/usr/bin/env bash
set -euo pipefail
# ------------------------------------------------------------------
#                  AWS S3 List All Bucket Sizes
#        List total size for all Amazon Web Services S3 buckets using s3cmd.
# ------------------------------------------------------------------

command -v s3cmd >/dev/null 2>&1 || {
  echo "s3cmd is required but was not found in PATH." >&2
  exit 127
}

s3cmd ls | awk '{print $3}' | while IFS= read -r bucket; do
  [ -n "$bucket" ] || continue
  size=$(s3cmd du "$bucket" | awk '{print $1}')
  sizemb=$((size / 1024 / 1024))
  sizegb=$((sizemb / 1024))
  printf '%s %s GB %s MB %s bytes\n' "$bucket" "$sizegb" "$sizemb" "$size"
done
