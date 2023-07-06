#!/bin/bash

# https://betterdev.blog/minimal-safe-bash-script-template/
set -Eeuo pipefail
trap cleanup SIGINT SIGTERM ERR EXIT

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd -P)
TESTNET_CHANNEL=$(terraform workspace show)

cleanup() {
  trap - SIGINT SIGTERM ERR EXIT
  # script cleanup here
}

echo "$TESTNET_CHANNEL information:"
echo ""

total=0
export TESTNET_CHANNEL
export TZ=GMT

# Define a function to run on each host
do_work() {
    name="$1"
    ip="$2"
    machine_name=$(ssh root@"$ip" hostname)
    dir_name="${name}__${ip}"
    mkdir -p "workspace/${TESTNET_CHANNEL}/droplets/${dir_name}"
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    echo "$timestamp" >> "workspace/${TESTNET_CHANNEL}/droplets/${dir_name}/resource.log"
    record=$(ssh root@"$ip" "bash -s" < ./scripts/resource-usage-on-machine.sh)
    echo "$record" >> "workspace/${TESTNET_CHANNEL}/droplets/${dir_name}/resource.log"

    last_line=$(echo "$record" | tail -n 1)

    # This will be printed to the console
    echo "workspace/${TESTNET_CHANNEL}/droplets/${dir_name}/resource.log updated with PID count: $last_line" >&2

    echo $last_line  # This line will be piped to awk
}

# Export the function so that it's available to GNU Parallel
export -f do_work

# Use GNU Parallel to run the function on each IP in parallel and get total
total=$(cat workspace/${TESTNET_CHANNEL}/ip-list | parallel --timeout 30 --jobs 10 --colsep ' ' do_work | awk '{sum += $1} END {print sum}')

droplets_accessed=$(wc -l < workspace/${TESTNET_CHANNEL}/ip-list)

echo "$droplets_accessed droplets accessed in check."
echo "Grand total safenode processes: $total"

cleanup
