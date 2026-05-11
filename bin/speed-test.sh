#!/usr/bin/env bash
set -euo pipefail
# scp-speed-test.sh
# Author: Alec Jacobson alecjacobsonATgmailDOTcom
#
# Test ssh connection speed by uploading and then downloading a 10000kB test
# file (optionally user-specified size)


if [[ "${1:-}" == "" ]]; then
  cat <<EOF
 Usage:
   ./speed-test.sh user@hostname[:port] [test file size in kBs]

EOF
  exit 1
fi

IFS=: read -r -a addr <<< "$1"
ssh_server=${addr[0]}
server_port=${addr[1]:-}
if [[ $server_port == "" ]]; then 
  server_port="22"
fi

#test_file=".scp-test-file"
test_file=$(mktemp)
remote_file="/tmp/$(basename "$test_file")"
cleanup() {
  rm -f "$test_file"
  ssh -p "$server_port" "$ssh_server" "rm -f '$remote_file'" >/dev/null 2>&1 || true
}
trap cleanup EXIT


# Optional: user specified test file size in kBs
if test -z "$2"
then
  # default size is 10kB ~ 10mB
  test_size="10000"
else
  test_size=$2
fi


# generate a 10000kB file of all zeros
echo "Generating $test_size kB test file..."
dd if=/dev/urandom of="$test_file" bs="$((test_size * 1024))" count=1 >/dev/null 2>&1

# upload test
echo "Testing upload to $ssh_server..."
up_speed=$(scp -v -P "$server_port" "$test_file" "$ssh_server:$remote_file" 2>&1 | \
  grep "Bytes per second" | \
  sed "s/^[^0-9]*\([0-9.]*\)[^0-9]*\([0-9.]*\).*$/\1/g")
up_speed=$(echo "($up_speed*0.0009765625*100.0+0.5)/1*0.01" | bc)

# download test
echo "Testing download from $ssh_server..."
down_speed=$(scp -v -P "$server_port" "$ssh_server:$remote_file" "$test_file" 2>&1 | \
  grep "Bytes per second" | \
  sed "s/^[^0-9]*\([0-9.]*\)[^0-9]*\([0-9.]*\).*$/\2/g")
down_speed=$(echo "($down_speed*0.0009765625*100.0+0.5)/1*0.01" | bc)

# clean up
echo "Removing test file on $ssh_server..."
ssh -p "$server_port" "$ssh_server" "rm -f '$remote_file'"
echo "Removing test file locally..."
rm -f "$test_file"
trap - EXIT

# print result
echo ""
echo "Upload speed:   $up_speed kB/s"
echo "Download speed: $down_speed kB/s"
