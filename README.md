# swarm-test-cluster

Code used to start a Swarm Cluster for the purpose of running unit tests

![swarm](images/swarm.png)

## Goal

Create a seamlessly scalable test environment on which containerised unit tests can be run in a single container or across hundreds of containers.

Using 2 tools from the Docker ecosystem (Machine and Swarm) we can create a scalable test environment in AWS and seamlessly scale our tests across a Swarm cluster.

This walkthrough will include a number of "Checkpoints" which will help break the significant steps into smaller chunks.  If you hit a Checkpoint and everything has worked as expected then continue to the next step.  If you hit issues before reaching a Checkpoint then check for a solution in [Troubleshooting](Troubleshooting.md) before continuing.

There are a number of areas of enhancement that will become apparent as you work through the manual steps.  These will be added to [Enhancements] (Enhancements.md).

## Background

We have been running unit tests in containers for a number of years and while this provides us with better test stability, portability and reduced resource footprint there are some issues with the current approach. 

* We use a static testlist which defines the number of containers that will be required by a test run
* A test run is currently executed on a single docker host.  
* The number of containers used for a test run are restricted by the docker hosts memory, cpu, network and disk i/o

We have essentially hit a glass ceiling in our test execution times due to these restrictions.  

## Improvements

The new approach will address the issues listed above.  

* Dynamic testlist

  Some work will be required at the testsuite level to create a dynamic list of tests which containers will query at runtime.  We will store the testlist in a single mysql db container accessible to the entire cluster.  Each new test container will query which tests need to be run and will reserve a "chunk" of tests which will be run within the test container.  These "chunks" will be configurable to allow for larger numbers of tests to be run in each test container.  Note : It is important that the unit tests do not have dependencies on previously run tests.
  
* Swarm Test Cluster

  Using Docker Machine and Docker Swarm we will spread test execution across multiple Docker hosts and leverage these additional resources to reduce test execution time.
  
* Local Docker Registry

  The Swarm Cluster will have a single docker registry which will store any images required by the unit tests.  Each Docker host will pull from this local registry.  This gives us the additional benefit of reducing our reliance on the private docker registry shared across the rest of the organisation.
  
* Consul Monitoring

  We will use the progrium Consul docker image to monitor the test container health and to provide service discovery for shared test infrastructure containers within the cluster such as mysql, rabbitmq etc.

## Requirements

* Docker
* Docker Machine
* Docker Swarm
* AWS Account
* Packer (Not needed right now. In future we will use Packer to create the AMI used within the cluster.)

## Troubleshooting

When setting up the Swarm cluster the first time you may come across a few minor issues.  I've documented all the issues and solutions in [Troubleshooting] (Troubleshooting.md)

## Step 1 : Install tools 

Note : This work is being done on Ubuntu 16.04 but will be ported to Centos 7 in future.

Install Docker :
```
https://docs.docker.com/engine/installation/linux/ubuntulinux/
```
Install Docker Machine : 
```
curl -L https://github.com/docker/machine/releases/download/v0.6.0/docker-machine-`uname -s`-`uname -m` > /usr/local/bin/docker-machine && chmod +x /usr/local/bin/docker-machine
```

Install Docker Swarm :

You can install the Swarm binary but it is easier to use the Swarm Image.  The command below will pull the latest Swarm image and print out the help text.
```
docker run swarm --help

Example Output :

A Docker-native clustering system

Version: 1.2.2 (34e3da3)

Options:
  --debug			debug mode [$DEBUG]
  --log-level, -l "info"	Log level (options: debug, info, warn, error, fatal, panic)
  --experimental		enable experimental features
  --help, -h			show help
  --version, -v			print the version
  
Commands:
  create, c	Create a cluster
  list, l	List nodes in a cluster
  manage, m	Manage a docker cluster
  join, j	Join a docker cluster
  help		Shows a list of commands or help for one command

```
# Checkpoint: 
![Trophy](images/trophy.jpg)
# Congratulations! You have all the tools installed !!


## Step 2 : Create Swarm Test Cluster

The test cluster(tc) will consist of 1 Consul Node, a Swarm Master and 4 Swarm Nodes.  

* consul-tc
* swarm-master-tc
* swarm-node-tc-[1-4]

Docker Machine requires the following AWS credentials to start a Machine on AWS :
```
--amazonec2-access-key
--amazonec2-secret-key 
--amazonec2-region
--amazonec2-zone 
--amazonec2-vpc-id 
```

### Set Environment variables
```
export AWS_ACCESS_KEY=<enter value>
export AWS_SECRET_KEY=<enter value>
export AWS_REGION=<enter value>
export AWS_ZONE=<enter value>
export AWS_VPC=<enter value>
export AWS_SUBNET=<enter value>
export AWS_INSTANCE_TYPE=<enter value>

```
### Start Consul Machine and Service
```
docker-machine create --driver amazonec2 \
	--amazonec2-access-key=${AWS_ACCESS_KEY} \
	--amazonec2-secret-key=${AWS_SECRET_KEY} \
  	--amazonec2-region=${AWS_REGION} \
	--amazonec2-zone=${AWS_ZONE} \
	--amazonec2-vpc-id=${AWS_VPC} \
	--amazonec2-subnet-id=${AWS_SUBNET} \
	--amazonec2-instance-type=${AWS_INSTANCE_TYPE} \
	--amazonec2-tags="Name,consul-tc" \
  	consul-tc 
```

### Start Consul service
```
eval $(docker-machine env consul-tc)

docker run --name consul --restart=always -p 8400:8400 -p 8500:8500 \
  -p 55:53/udp -d progrium/consul -server -bootstrap-expect 1 -ui-dir /ui

```
## Verify Consul started
```
docker-machine ls

NAME              ACTIVE   DRIVER      STATE     URL                       SWARM                      DOCKER    ERRORS
consul-tc         *        amazonec2   Running   tcp://*.*.*.*:2376                                v1.11.1   
```

# Checkpoint: 
![Trophy](images/trophy.jpg)
# Congratulations! You have Consul running !!

## Start Swarm Master
```
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
```

## Verify Swarm Master started
```
docker-machine ls

NAME              ACTIVE   DRIVER      STATE     URL                       SWARM                      DOCKER    ERRORS
consul-tc         *        amazonec2   Running   tcp://*.*.*.*:2376                                v1.11.1   
swarm-master-tc   -        amazonec2   Running   tcp://*.*.*.*:2376   	swarm-master-tc (master)   v1.11.1
```

# Checkpoint: 
![Trophy](images/trophy.jpg)
# Congratulations! You have created a Swarm Master !!


## Start Swarm Nodes
```
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
```
  
## Verify Swarm has started correctly
```
docker-machine ls

Switch to swarm-master :

eval $(docker-machine env --swarm swarm-master-tc)

List number of Nodes attached to Swarm :

docker info | grep "^Nodes:"
```

# Checkpoint: 
![Trophy](images/trophy.jpg)
# Congratulations! You now have a fully functional Swarm Cluster!!


## Step 3 : Create a docker-registry in the Swarm

Now that we have a Swarm running we will start a docker-registry that will allow each node in the cluster to access the same registry.

Switch to swarm-master (if not already done):
```
eval $(docker-machine env --swarm swarm-master-tc)
```

Start the docker-registry :

Code based on : https://github.com/jpetazzo/orchestration-workshop/blob/master/bin/setup-all-the-things.sh
```
docker-compose up -d

Scale up the docker-registry frontend :

docker-compose scale frontend=5
```

# Checkpoint: 
![Trophy](images/trophy.jpg)
# Congratulations! You now have docker-registry running in your cluster!!

## Step 4 : Push to registry and run containers across the Swarm

In this step we will pull an alpine linux image, modify the image, push to the registry and then each cluster node will run containers based on this modified image.

```
eval $(docker-machine env --swarm swarm-master-tc)

docker pull alpine:latest
docker run -it --cidfile="container_id" alpine:latest /bin/sh

echo "Tests will run from this container" > /tmp/output
exit
```

Save the change :
```
docker commit `cat container_id` localhost:5000/alpine:modified
```

Push the new image to the local docker-registry :
```
docker push localhost:5000/alpine:modified
```

If you see the following error :

Put http://localhost:5000/v1/repositories/alpine/: dial tcp 127.0.0.1:5000: getsockopt: connection refused

Then you will need to login to the AWS console and add port 5000 to the inbound port of the docker-machine security group.


At this point we have a modified image which each of the nodes can run.  Let's test this out.
```
for node_number in $(seq 1 4); do
    docker run -d 127.0.0.1:5000/alpine:modified /bin/sh -c "while(true); do cat /tmp/output;sleep 60; done"
done
```

Now check where the containers are running :
```
CONTAINER ID        IMAGE                            COMMAND                  CREATED              STATUS              PORTS                      NAMES
409cd9b4f853        127.0.0.1:5000/alpine:modified   "/bin/sh -c 'while(tr"   About a minute ago   Up About a minute                              swarm-master-tc/serene_ride
7e6603dee9b1        127.0.0.1:5000/alpine:modified   "/bin/sh -c 'while(tr"   About a minute ago   Up About a minute                              swarm-node-tc-4/loving_mcclintock
c5286db16822        127.0.0.1:5000/alpine:modified   "/bin/sh -c 'while(tr"   About a minute ago   Up About a minute                              swarm-node-tc-3/pedantic_goodall
263d988962c9        127.0.0.1:5000/alpine:modified   "/bin/sh -c 'while(tr"   About a minute ago   Up About a minute                              swarm-node-tc-1/small_sammet
eb33de99b305        127.0.0.1:5000/alpine:modified   "/bin/sh -c 'while(tr"   About a minute ago   Up About a minute                              swarm-master-tc/drunk_payne

```

You can see from the container names that the containers have started across different nodes.

# Congratulations!  
![Trophy](images/flag.jpg)
# You are now setup and ready to run your containerised unit tests across a Swarm Cluster!!


## Teardown

If you want to teardown the Swarm Cluster you can run the following command.  Warning : This will delete any EC2 instances that Machine created so use at own risk.
```
docker-machine rm -f $(docker-machine ls -q)
```

