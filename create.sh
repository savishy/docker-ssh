#!/bin/bash
set -e
# do not prompt http://stackoverflow.com/a/15890748/682912
CONTAINER_NAME=docker-ssh-container
container_count=1
IMG_NAME=docker-ssh
KEY_NAME=ansible_id_rsa
KEY_PATH="~/.ssh/$KEY_NAME"

usage() {
  echo "
  This script creates a Docker container with ability to SSH into it.
  ** Note ** when running for the first time, use the -r flag (see below).
  Usage: $0 [OPTS]

  OPTS:
  -h | -?: print this usage and exit.

  -r: During the first run of this script, use this flag. This generates SSH keys.

  -p: Specify a list of ports to forward from host into the container. Format is
      -p P1:P1,P2:P2,....

  -c: Count of containers to create. default value is 1.

  "
}

cleanupOldContainers() {
  echo "-- delete old containers"
  prevContainers=`docker ps -aq -f "ancestor=$IMG_NAME"`
  if [[ ! "$prevContainers" == "" ]]; then
    echo $prevContainers | xargs docker rm -f
  fi
}

regenerateSSHkey() {
  echo "-- creating SSH key $KEY_PATH"
  echo "** Warning **: this step may fail during repeated runs -- WIP"
  if [ ! -e $KEY_PATH ]; then
    ssh-keygen -b 2048 -t rsa -f $KEY_PATH -q -N ""
  else
    echo "-- key exists at $KEY_PATH; skipping"
  fi
  cp -v $KEY_PATH .
  cp -v $KEY_PATH.pub .
  chmod 600 $KEY_PATH
  chmod 600 $KEY_PATH.pub

}

portForward() {
  IFS=',' read -ra PORTS <<< "$port_list"
  portForwards="-p 220$1:22"
  for i in "${PORTS[@]}"; do
      portForwards="$portForwards -p $i "
  done
  echo $portForwards
}

volumeMount() {
  IFS=',' read -ra VOLUMES <<< "$volume_mounts"
  volumeMounts=" "
  for i in "${VOLUMES[@]}"; do
    volumeMounts="$volumeMounts -v $i "
  done
  echo $volumeMounts
}

####################
# MAIN
# Parse commandline args
####################
while getopts "h?rp:v:c:" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    r)  regenssh=1
        ;;
    p)  port_list=$OPTARG
        ;;
    v)  volume_mounts=$OPTARG
        ;;
    c)  container_count=$OPTARG
        ;;
    esac
done

cleanupOldContainers

if [[ $regenssh ]]; then
  regenerateSSHkey
else
  echo "-- skipping SSH key creation at $KEY_PATH (run the script with $0 true to enable this)"
fi

echo "-- creating Docker Image"
docker build -q -t $IMG_NAME .

echo "-- Ports to Forward: $portForwards"
echo "-- Volumes to Mount: $volumeMounts"

echo "-- creating inventory file (for use by Ansible)"
>inventory

for i in $(seq 1 $container_count); do
  pf=`portForward $i`
  vm=`volumeMount`

  echo "-- running Docker container"
  set -x
  docker run -m "2048m" --memory-swap "4096m" -d $pf $vm --name $CONTAINER_NAME-$i $IMG_NAME
  set +x
  CONTAINER_ID=`docker ps -aq -f "name=$CONTAINER_NAME-$i"`
  ipAddr=`docker inspect -f {{.NetworkSettings.IPAddress}} $CONTAINER_NAME-$i`
  echo "-- container IP: $ipAddr"
  echo "-- removing any old entries from known_hosts"
  ssh-keygen -f "$HOME/.ssh/known_hosts" -R $ipAddr

  commonArgs="ansible_ssh_port=22 ansible_ssh_user='root' ansible_ssh_private_key_file=$KEY_PATH"
  inventoryLine="$CONTAINER_NAME ansible_ssh_host=$ipAddr $commonArgs"
  echo "$inventoryLine" >> inventory

  echo "-- docker container created with name $CONTAINER_NAME"
  echo "   and ID: $CONTAINER_ID"
  echo "-- To SSH into this container, do the following: "
  echo "   ssh -i $KEY_PATH root@$ipAddr"

done

echo "-----------------------------------------"
echo "-- inventory file created at ./inventory"
echo "-----------------------------------------"
