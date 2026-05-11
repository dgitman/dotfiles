#!/usr/bin/env bash
set -euo pipefail
# Written by MKZA from customerhelp.co.za
#
# Run from the directory whose files you want to organize.

find . -maxdepth 1 -type f -print0 | while IFS= read -r -d '' file; do
    f=$(basename "$file")
    f1=${f%.*}
    if [ "$f1" = "$f" ]; then
        f1="${f}.folder"
    fi
    if [ -e "$f1" ]; then
        echo "Skipping $f: $f1 already exists" >&2
        continue
    fi
    mkdir "$f1"
    mv "$file" "$f1/"
done
