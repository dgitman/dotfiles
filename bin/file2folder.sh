#!/bin/bash
# Written by MKZA from customerhelp.co.za
find . -type f | while read file;
do
    f=$(basename "$file")
    f1=${f%.*}
    mkdir "$f1"
    mv "$f" "$f1"
done 
