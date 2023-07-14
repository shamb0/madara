#!/bin/bash
ROOT_DIR="/tmp/madara"
LOG_DIR="$ROOT_DIR/logs"
CHAIN_SPEC_DIR="$ROOT_DIR/chain-spec"

function initialize(){
    # Create the root directory
    mkdir -p $ROOT_DIR

    # Create the log directory
    mkdir -p $LOG_DIR

	# Create the chainspec directory
	mkdir -p $CHAIN_SPEC_DIR
}

# Initialize the script
initialize

DEFAULT_CHAIN_SPEC="madara-local"

# Command to build the chainspec
CMD_BUILDSPEC="./target/release/madara \
	build-spec \
	--disable-default-bootnode"

# Utility function to generate the chainspec and update the global variable CS_PATH

function get_chain_spec_path() {
  local S1_CS_PATH="$CHAIN_SPEC_DIR/pre-chain-spec.json"
  local CS_PATH="$CHAIN_SPEC_DIR/chain-spec.json"

  if [[ -f "$CS_PATH" ]]; then
    echo "$CS_PATH"
  else
    # Create a file named pre-chain-spec.json in the temporary directory
    eval "$CMD_BUILDSPEC" --chain "$DEFAULT_CHAIN_SPEC" > "$S1_CS_PATH"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to create $S1_CS_PATH"
      exit 1
    fi

    # Create a file named chain-spec.json in the temporary directory
    eval "$CMD_BUILDSPEC" --chain "$S1_CS_PATH" --raw > "$CS_PATH"
    if [[ $? -ne 0 ]]; then
      echo "Error: Failed to create $CS_PATH"
      exit 1
    fi

    echo "$CS_PATH"
  fi
}

CS_PATH=$(get_chain_spec_path)

# Do something with the chain spec
echo "The chain spec path is: $CS_PATH"

# Build the command to run the validator node
CMD_BOOTNODE="./target/release/madara \
	--chain=$CS_PATH \
	--validator \
	--force-authoring \
	--rpc-cors=all \
	--rpc-external \
	--rpc-methods=unsafe"

CMD_VALIDATOR="./target/release/madara \
	--chain=$CS_PATH \
	--validator \
	--force-authoring \
	--rpc-cors=all \
	--rpc-external \
	--rpc-methods=unsafe \
	--bootnodes=/ip4/127.0.0.1/tcp/30331/p2p/12D3KooWMpdTSKB2FiCRCZsCA2JfASAZUQRFYkvrcQgq5mtEt1fw"

CMD_FULLNODE="./target/release/madara \
	--chain=$CS_PATH \
	--rpc-cors=all \
	--rpc-external \
	--rpc-methods=unsafe \
	--bootnodes=/ip4/127.0.0.1/tcp/30331/p2p/12D3KooWMpdTSKB2FiCRCZsCA2JfASAZUQRFYkvrcQgq5mtEt1fw"

# Display a menu to the user
function menu(){
    echo "1. Start nodes"
    echo "2. Stop nodes"
    echo "3. Exit"
    echo "4. Cleanup"
    echo "5. Show logs"
    echo "6. Monitor nodes"
    echo "7. Stop monitoring nodes"
    echo "8. Kill everything and cleanup"
    echo "9. Run testnet and monitoring"
    echo -n "Enter your choice: "
    read choice
    case $choice in
        1) start_nodes ;;
        2) stop_nodes ;;
        3) exit 0 ;;
        4) cleanup ;;
        5) show_logs ;;
        6) monitor_nodes ;;
        7) stop_monitoring_nodes ;;
        8) stop_nodes; stop_monitoring_nodes; cleanup; exit 0 ;;
        9) start_nodes; monitor_nodes; exit 0 ;;
        *) echo "Invalid choice" ;;
    esac
}

function start_nodes(){
    # Run bootnode A
	start_boot_node "boot-node-a" 30331 9931 9611 "bb2f8c969875fe4bd5ad7275b92e0b80a9f424243fe237fbd992d5990197e01d"

    # Run validator node A
    start_validator_node "validator-node-a" 30332 9932 9621 "bob"

    # Run validator node B
    start_validator_node "validator-node-b" 30333 9933 9631 "charlie"

    # Run validator node C
    start_validator_node "validator-node-c" 30334 9934 9641 "dave"

    # Run validator node D
    start_validator_node "validator-node-d" 30335 9935 9651 "eve"

    # Run validator node E
    start_validator_node "validator-node-e" 30336 9936 9661 "ferdie"

    # Run light client node A
    start_full_node "full-node-a" 30344 9944 "0000000000000000000000000000000000000000000000000000000000000001"
}

function stop_nodes(){
    echo "Stopping nodes"
    killall madara
}

function start_boot_node(){
    name=$1
    port=$2
    rpc_port=$3
	prometheus_port=$4
    node_key=$5
    base_path=$ROOT_DIR/$name
	madara_path=$ROOT_DIR/$name-madara
    log_file=$LOG_DIR/$name.log

    # Create the validator node base path directory
    mkdir -p $base_path
	mkdir -p $madara_path

    echo "Starting $name"
    run_cmd="$CMD_BOOTNODE --node-key $node_key --port $port --rpc-port $rpc_port --base-path $base_path --madara-path $madara_path &> $log_file &"
    echo "Running: $run_cmd"
    eval $run_cmd
}

function start_validator_node(){
    name=$1
    port=$2
    rpc_port=$3
    prometheus_port=$4
    key_alias=$5
    base_path=$ROOT_DIR/$name
	madara_path=$ROOT_DIR/$name-madara
    log_file=$LOG_DIR/$name.log

    # Create the validator node base path directory
    mkdir -p $base_path
	mkdir -p $madara_path

    echo "Starting $name"
    run_cmd="$CMD_VALIDATOR --$key_alias --port $port --rpc-port $rpc_port --prometheus-port $prometheus_port --base-path $base_path --madara-path $madara_path &> $log_file &"
    echo "Running: $run_cmd"
    eval $run_cmd
}

function start_full_node(){
    name=$1
    port=$2
    rpc_port=$3
    node_key=$4
    base_path=$ROOT_DIR/$name
	madara_path=$ROOT_DIR/$name-madara
    log_file=$LOG_DIR/$name.log

    # Create the validator node base path directory
    mkdir -p $base_path
	mkdir -p $madara_path

    echo "Starting $name"
    run_cmd="$CMD_FULLNODE --node-key $node_key --port $port --rpc-port $rpc_port --base-path $base_path --madara-path $madara_path &> $log_file &"
    echo "Running: $run_cmd"
    eval $run_cmd
}

function show_logs(){
    #Ask the user to select the node to show logs for
    echo "Select the node to show logs for"
    echo "1. Boot node A"
    echo "2. Validator node A"
	echo "3. Validator node B"
	echo "4. Validator node C"
	echo "5. Validator node D"
	echo "6. Validator node E"
    echo "7. Full node A"
    echo -n "Enter your choice: "
    read choice
    case $choice in
		1) show_node_logs "boot-node-a" ;;
        1) show_node_logs "validator-node-a" ;;
        2) show_node_logs "validator-node-b" ;;
		3) show_node_logs "validator-node-c" ;;
		4) show_node_logs "validator-node-d" ;;
		5) show_node_logs "validator-node-e" ;;
        3) show_node_logs "full-node-a" ;;
        *) echo "Invalid choice" ;;
    esac
}

# Show the logs for a node
function show_node_logs(){
    name=$1
    log_file=$LOG_DIR/$name.log
    echo "Showing logs for $name"
    tail -f $log_file
}

function monitor_nodes(){
    echo "Starting prometheus"
    prometheus --config.file infra/local-testnet/prometheus/prometheus.yml &> $LOG_DIR/prometheus.log &
    echo "Prometheus started"
    echo "Starting grafana"
    # Warning: this command assumes that grafana is installed using brew
    # and that the program is run on MacOS.
    # It does not impact the script if you don't run monitoring features.
    # TODO: make this more generic and cross-platform.
    brew services start grafana
    echo "Grafana started"
}

function stop_monitoring_nodes(){
    echo "Stopping prometheus"
    killall prometheus
    echo "Prometheus stopped"
    echo "Stopping grafana"
    brew services stop grafana
    echo "Grafana stopped"
}

function cleanup {
    echo "Cleaning up"
    rm -rf $ROOT_DIR
}

# Show the menu
menu
