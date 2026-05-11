#!/bin/bash
# ------------------------------------------------------------------
#                  curl Format Example
#        This make curl display information on stdout after a completed transfer
# ------------------------------------------------------------------

curl -w "@curl-format.txt" -o /dev/null -s "http://wordpress.com/"

