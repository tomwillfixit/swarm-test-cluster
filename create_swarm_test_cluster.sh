#!/bin/bash

#set environment variables

export AWS_ACCESS_KEY=<enter value here>
export AWS_SECRET_KEY=<enter value here>
export AWS_REGION=<enter value here>
export AWS_ZONE=<enter value here>
export AWS_VPC=<enter value here>
export AWS_SUBNET=<enter value here>
export AWS_INSTANCE_TYPE=<enter value here>

#hardcoded to t2.micro since it is just running a consul container
echo "Start Consul Machine and Service"
docker-machine create --driver amazonec2 \
    --amazonec2-access-key=${AWS_ACCESS_KEY} \
    --amazonec2-secret-key=${AWS_SECRET_KEY} \
    --amazonec2-region=${AWS_REGION} \
    --amazonec2-zone=${AWS_ZONE} \
    --amazonec2-vpc-id=${AWS_VPC} \
    --amazonec2-subnet-id=${AWS_SUBNET} \
    --amazonec2-instance-type=t2.micro \
    --amazonec2-tags="Name,consul-tc" \
    consul-tc

eval $(docker-machine env consul-tc)

docker run --name consul --restart=always -p 8400:8400 -p 8500:8500 \
  -p 55:53/udp -d progrium/consul -server -bootstrap-expect 1 -ui-dir /ui

docker-machine ls

echo "Start swarm-master-tc"

docker-machine create --driver amazonec2 \
    --amazonec2-access-key=${AWS_ACCESS_KEY} \
    --amazonec2-secret-key=${AWS_SECRET_KEY} \
    --amazonec2-region=${AWS_REGION} \
    --amazonec2-zone=${AWS_ZONE} \
    --amazonec2-vpc-id=${AWS_VPC} \
    --amazonec2-subnet-id=${AWS_SUBNET} \
    --amazonec2-instance-type=${AWS_INSTANCE_TYPE} \
    --amazonec2-tags="Name,swarm-master-tc" \
    --swarm \
    --swarm-master \
    --swarm-discovery="consul://$(docker-machine ip consul-tc):8500" \
    --engine-opt="cluster-store=consul://$(docker-machine ip consul-tc):8500" \
    --engine-opt="cluster-advertise=eth0:2376" \
    swarm-master-tc

docker-machine ls

echo "Start Swarm Nodes : swarm-node-tc-[1-4]"

for node_number in $(seq 1 4); do
docker-machine create --driver amazonec2 \
        --amazonec2-access-key=${AWS_ACCESS_KEY} \
        --amazonec2-secret-key=${AWS_SECRET_KEY} \
        --amazonec2-region=${AWS_REGION} \
        --amazonec2-zone=${AWS_ZONE} \
        --amazonec2-vpc-id=${AWS_VPC} \
        --amazonec2-subnet-id=${AWS_SUBNET} \
        --amazonec2-instance-type=${AWS_INSTANCE_TYPE} \
        --amazonec2-tags="Name,swarm-node-tc-${node_number}" \
        --swarm \
        --swarm-discovery="consul://$(docker-machine ip consul-tc):8500" \
        --engine-opt="cluster-store=consul://$(docker-machine ip consul-tc):8500" \
        --engine-opt="cluster-advertise=eth0:2376" \
        swarm-node-tc-${node_number}
done

docker-machine ls

sleep 5

echo "Switching to swarm-master : docker-machine env --swarm swarm-master-tc"

eval $(docker-machine env --swarm swarm-master-tc)

docker info | grep "^Nodes:"

echo "Finished"
