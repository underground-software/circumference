#!/bin/sh

# example script to quickly regenerate a test assignment

cd "$(dirname "$0")"

./denis/configure.sh remove -a kdlp_test
./denis/configure.sh create -a kdlp_test -i "$(date -d '5 minutes' +%s)" -p "$(date -d '10 minutes' +%s)" -f "$(date -d '15 minutes' +%s)"
./denis/configure.sh reload
