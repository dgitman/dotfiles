#!/usr/bin/env bash
set -euo pipefail
# ------------------------------------------------------------------
#                  curl Format Example
#        Make curl display transfer information after a completed request.
# ------------------------------------------------------------------

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
url=${1:-https://wordpress.com/}

curl -w "@$script_dir/curl-format.txt" -o /dev/null -sS "$url"
