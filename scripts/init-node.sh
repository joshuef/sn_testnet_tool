#!/bin/bash

node_url="$1"
if [[ -z "$node_url" ]]; then
  echo "A URL for the node binary must be passed to initialise the node."
  exit 1
fi

is_genesis="$2"
if [[ -z "$is_genesis" ]]; then
  echo "A true/false value must be passed to indicate whether this is the genesis node."
  exit 1
fi

bind_ip_address="$3"
if [[ -z "$bind_ip_address" ]]; then
  echo "A bind ip address must be passed to initialise the node."
  exit 1
fi

node_ip_address="$4"
if [[ "$is_genesis" == "true" && -z "$node_ip_address" ]]; then
  echo "A node ip address must be passed to initialise the node."
  exit 1
fi

port="$5"
if [[ -z "$port" ]]; then
  echo "A port must be passed to initialise the node."
  exit 1
fi

log_level="$6"
if [[ -z "$log_level" ]]; then
  echo "A log level must be passed to initialise the node."
  exit 1
fi

function install_heaptrack() {
  # This is the first package we attempt to install. There are issues with apt
  # when the machine is initially used. Sometimes it is still running in the
  # background, in which case there will be an error about a file being locked.
  # Other times, the heaptrack package won't be available because it seems to
  # be some kind of timing issue: if you run the install command too quickly
  # after the update command, apt will complain it can't find the package.
  sudo DEBIAN_FRONTEND=noninteractive apt update > /dev/null 2>&1
  sudo DEBIAN_FRONTEND=noninteractive apt-get update -y
  retry_count=1
  heaptrack_installed="false"
  while [[ $retry_count -le 20 ]]; do
    echo "Attempting to install heaptrack..."
    sudo DEBIAN_FRONTEND=noninteractive apt install heaptrack -y > /dev/null 2>&1
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "heaptrack installed successfully"
        heaptrack_installed="true"
        break
    fi
    echo "Failed to install heaptrack."
    echo "Attempted $retry_count times. Will retry up to 20 times. Sleeping for 10 seconds."
    ((retry_count++))
    sleep 10
    # Without running this again there are times when it will just fail on every retry.
    sudo DEBIAN_FRONTEND=noninteractive apt update > /dev/null 2>&1
  done
  if [[ "$heaptrack_installed" == "false" ]]; then
    echo "Failed to install heaptrack"
    exit 1
  fi
}

function install_node() {
  archive_name=$(awk -F '/' '{ print $4 }' <<< $node_url)
  wget ${node_url}
  tar xf $archive_name
  chmod +x sn_node
  mkdir -p ~/node_data
  mkdir -p ~/.safe/node
  mkdir -p ~/.safe/prefix_maps
  mkdir -p ~/logs
}

function setup_prefix_map() {
  if [[ "$is_genesis" == "false" ]]; then
    cp prefix-map ~/.safe/prefix_maps/prefix-map
    ln -s ~/.safe/prefix_maps/prefix-map ~/.safe/prefix_maps/default
  fi
}

function run_node() {
  export RUST_LOG=sn_node=trace,sn_dysfuction=debug,
  export TOKIO_CONSOLE_BIND="${bind_ip_address}:6669",
  if [[ "$is_genesis" == "true" ]]; then
    node_cmd=$(printf '%s' \
      "heaptrack ./sn_node " \
      "--first " \
      "--local-addr $node_ip_address:$port " \
      "--skip-auto-port-forwarding " \
      "--root-dir ~/node_data " \
      "--log-dir ~/logs " \
      "$log_level" \
    )
    echo "Launching node with: $node_cmd"
    nohup sh -c "$node_cmd" &
    sleep 5
    cp -H ~/.safe/prefix_maps/default ~/prefix-map
    sleep 5
  else
    node_cmd=$(printf '%s' \
      "heaptrack ./sn_node " \
      "--skip-auto-port-forwarding " \
      "--root-dir ~/node_data " \
      "--log-dir ~/logs " \
      "$log_level" \
    )
    echo "Launching node with: $node_cmd"
    nohup sh -c "$node_cmd" &
    sleep 5
  fi
}

install_heaptrack
install_node
setup_prefix_map
run_node
