#!/usr/bin/env bash

set -euo pipefail

COMMANDS="help init status rpm_deploy config_deploy install uninstall start restart stop execute"

CLUSTER_NAME=
CLUSTER_CONFIG_DIR=
USER=
IDENTITY_KEY=
COORDINATOR_IP=
WORKER_IPS=
COORDINATOR_CONFIG_DIR=
WORKER_CONFIG_DIR=
CATALOG_CONFIG_DIR=

function help() {
  cat << EOF
$0 command CLUSTER_NAME [arguments]

Commands:
  help          -   display this window
  init          -   init the cluster topology
  tgz_deploy    -
    arguments:
        tgz     -   path to Presto tgz file
  config_deploy -   deploys configuration on the cluster
  install       -   install Presto on the cluster, requires tgz_deploy to be run first
  uninstall     -   uninstall Presto from the cluster, requires install to be run first
  status        -   display the status of the cluster
  start         -   start Presto on the cluster
  restart       -   restart Presto on the cluster
  stop          -   stop Presto on the cluster
EOF
}

function init() {
    CLUSTER_NAME="$1"
    CLUSTER_CONFIG_DIR="$HOME/.presto-admin-sh/$CLUSTER_NAME"
    if [[ -d "$CLUSTER_CONFIG_DIR" ]]; then
        _err "Cluster $CLUSTER_NAME configuration, already exists under $CLUSTER_CONFIG_DIR"
    fi

    read -p "What remote user should be used to connect cluster nodes: " USER
    read -p "What identity key file should be used to connect cluster nodes: " IDENTITY_KEY
    read -p "What is the IP of coordinator: " COORDINATOR_IP
    read -p "What are the IPs of workers: " WORKER_IPS

    _test_cluster

    mkdir -p "$CLUSTER_CONFIG_DIR"
    echo $USER >> "$CLUSTER_CONFIG_DIR/user"
    echo $COORDINATOR_IP >> "$CLUSTER_CONFIG_DIR/coordinator"
    echo $WORKER_IPS >> "$CLUSTER_CONFIG_DIR/workers"

    cp "$(eval echo $IDENTITY_KEY)" "$CLUSTER_CONFIG_DIR/identity"

    _load_cluster "$CLUSTER_NAME"

    mkdir -p "$COORDINATOR_CONFIG_DIR"
    mkdir -p "$WORKER_CONFIG_DIR"
    mkdir -p "$CATALOG_CONFIG_DIR"

    # Configure coordinator
    cat << EOF > "$COORDINATOR_CONFIG_DIR/config.properties"
coordinator=true
node-scheduler.include-coordinator=false
http-server.http.port=8080
query.max-memory=50GB
query.max-memory-per-node=1GB
query.max-total-memory-per-node=2GB
discovery-server.enabled=true
discovery.uri=http://$COORDINATOR_IP:8080
EOF

    # Configure workers
    cat << EOF > "$WORKER_CONFIG_DIR/config.properties"
coordinator=false
http-server.http.port=8080
query.max-memory=50GB
query.max-memory-per-node=1GB
query.max-total-memory-per-node=2GB
discovery.uri=http://$COORDINATOR_IP:8080
EOF

    # Configure catalogs
    cat << EOF > "$CATALOG_CONFIG_DIR/tpch.properties"
connector.name=tpch
tpch.splits-per-node=4
EOF
    cat << EOF > "$CATALOG_CONFIG_DIR/tpcds.properties"
connector.name=tpcds
tpcds.splits-per-node=4
EOF
    cat << EOF > "$CATALOG_CONFIG_DIR/jmx.properties"
connector.name=jmx
EOF
}

function status() {
    _load_cluster "$1"
    _test_cluster
    _sudo_execute 'status presto-server || true'
}

function start() {
    _load_cluster "$1"
    _sudo_execute 'start presto-server || true'
}

function restart() {
    _load_cluster "$1"
    _sudo_execute 'restart presto-server || true'
}

function stop() {
    _load_cluster "$1"
    _sudo_execute 'stop presto-server || true'
}

function tgz_deploy() {
    _load_cluster "$1"
    tgz_file="$2"
    if [[ ! -f "$tgz_file" ]]; then
        _err "TGZ file $tgz_file does not exists"
    fi
    _test_cluster

    for node in $COORDINATOR_IP $WORKER_IPS; do
        _log "Uploading: $tgz_file on $node"
        scp -i "$IDENTITY_KEY" "$tgz_file" "$USER@$node:/tmp/presto.tar.gz"
    done
}

function install() {
    _load_cluster "$1"

    _sudo_execute mkdir /usr/lib/presto && tar xvzf --strip 1 /tmp/presto.tar.gz /usr/lib/presto
}

function uninstall() {
    _load_cluster "$1"

    _sudo_execute rm -rf /tmp/presto-backup
    _sudo_execute mkdir /tmp/presto-backup && cp -R /usr/lib/presto/* /tmp/presto-backup
    _sudo_execute rm -rf /usr/lib/presto
}

function execute() {
    _load_cluster "$1"
    shift
    _execute "$@"
}

function config_deploy() {
    _load_cluster "$1"
    _log "Updating coordinator ($COORDINATOR_IP) configuration"
    _execute rm -rf /tmp/presto_config
    _execute mkdir -p /tmp/presto_config
    scp -i "$IDENTITY_KEY" "$COORDINATOR_CONFIG_DIR"/* "$USER@$COORDINATOR_IP:/tmp/presto_config"
    for worker in $WORKER_IPS; do
        _log "Updating worker ($worker) configuration"
        scp -i "$IDENTITY_KEY" "$WORKER_CONFIG_DIR"/* "$USER@$worker:/tmp/presto_config"
    done
    _sudo_execute cp '/tmp/presto_config/*' /etc/presto/conf

    _execute rm -rf /tmp/presto_config
    _execute mkdir -p /tmp/presto_config
    _sudo_execute mkdir -p /etc/presto/conf/catalog
    scp -i "$IDENTITY_KEY" "$CATALOG_CONFIG_DIR"/* "$USER@$COORDINATOR_IP:/tmp/"
    for node in $COORDINATOR_IP $WORKER_IPS; do
        _log "Updating catalog configuration ($node)"
        scp -i "$IDENTITY_KEY" "$CATALOG_CONFIG_DIR"/* "$USER@$node:/tmp/presto_config"
    done
    _sudo_execute cp '/tmp/presto_config/*' /etc/presto/conf/catalog
}

function _test_cluster() {
    #_execute rpm -qa presto-server-rpm
}

function _sudo_execute() {
    sudo=""
    if [[ "$USER" != "root" ]]; then
        sudo="sudo"
    fi

    _execute "$sudo" "$@"
}

function _execute() {
    for node in $COORDINATOR_IP $WORKER_IPS; do
        _log "Executing '$@' on $node:"
        ssh -t -i "$IDENTITY_KEY" "$USER@$node" "$@"
    done
}

function _load_cluster() {
    CLUSTER_NAME="$1"
    CLUSTER_CONFIG_DIR=$(eval echo "~/.presto-admin-sh/$CLUSTER_NAME")
    if [[ ! -d "$CLUSTER_CONFIG_DIR" ]]; then
        _err "Configuration for $CLUSTER_NAME does not exist under $CLUSTER_CONFIG_DIR"
    fi
    USER=$(cat $CLUSTER_CONFIG_DIR/user)
    COORDINATOR_IP=$(cat $CLUSTER_CONFIG_DIR/coordinator)
    WORKER_IPS=$(cat $CLUSTER_CONFIG_DIR/workers)
    IDENTITY_KEY="$CLUSTER_CONFIG_DIR/identity"
    COORDINATOR_CONFIG_DIR="$CLUSTER_CONFIG_DIR/configuration/coordinator"
    WORKER_CONFIG_DIR="$CLUSTER_CONFIG_DIR/configuration/worker"
    CATALOG_CONFIG_DIR="$CLUSTER_CONFIG_DIR/configuration/catalog"
}

function _log() {
    echo "$@"
}

function _err() {
  echo "Error: $@" >&2
  exit 1
}

if [[ $# = 0 || "$@" = *help* ]]; then
  help
  exit
fi

command="$1"
shift
echo $COMMANDS | tr ' ' '\n' | grep -qF "${command}" || _err "Invalid command: $command, try help command first."

$command "$@"
