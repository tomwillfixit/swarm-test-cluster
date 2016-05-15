# swarm-test-cluster

Code used to start a Swarm Cluster for the purpose of running tests

## Goal

Create a seamlessly scalable test environment on which containerised unit tests can be run in a single container or across hundreds of containers.

Using 2 tools from the Docker ecosystem (Machine and Swarm) we can create a scalable test environment in AWS and seamlessly scale our tests across a Swarm cluster.

I'll put a number of "Checkpoints" into this tutorial which will help break the significant steps into smaller chunks.  If you hit a Checkpoint and everything has worked as expected then continue to the next step.  If you hit issues before reaching a Checkpoint then check for a solution in [Troubleshooting](Troubleshooting.md) before continuing.

## Background

We have been running unit tests in containers for a number of years and while this provides us with better test stability, portability and reduced resource footprint there are some issues with the current approach. 

* We use a static testlist which defines the number of containers that will be required by a test run
* A test run is currently executed on a single docker host.  
* The number of containers used for a test run are restricted by the docker hosts memory, cpu, network and disk i/o

We have essentially hit a glass ceiling in our test execution times due to these issues.  

## Improvements

The new approach will address the issues listed above.  

* Dynamic testlist

  Some work will be required at the testsuite level to create a dynamic list of tests which containers will query at runtime.  We will store the testlist in a single mysql db container accessible to the entire cluster.  Each new test container will query which tests need to be run and will reserve a "chunk" of tests which will be run within the test container.  These "chunks" will be configurable to allow for larger numbers of tests to be run in each test container.  Note : It is important that the unit tests do not have dependencies on previously run tests.
  
* Swarm Test Cluster

  Using Docker Machine and Docker Swarm we will spread test execution across multiple physical Docker hosts and leverage these addition resources to reduce test execution time.
  
* Local Docker Registry

  The Swarm Cluster will have a single docker registry which will store any images required by the unit tests.  Each Docker host will pull from this local registry.  This gives us the additional benefit of reducing our reliance on the private docker registry shared across the rest of the organisation.
  
* Consul Monitoring

  We will use the official Consul docker image to monitor the test container health and to provide service discovery for shared test infrastructure containers within the cluster such as mysql, rabbitmq etc.

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

# Checkpoint reached : Congrats you have all the tools installed !!


## Step 2 : Create Swarm Test Cluster

The test cluster will consist of a Swarm Master and 4 Swarm Nodes.  We will start 5 nodes and node1 will become the master.

Create a nodes.txt file with contents :
```
172.0.5.1:node1
172.0.5.2:node2
172.0.5.3:node3
172.0.5.4:node4
172.0.5.5:node5
```

We will pass the following AWS credentials in on the command line :
```
--amazonec2-access-key
--amazonec2-secret-key 
--amazonec2-region
--amazonec2-zone 
--amazonec2-vpc-id 
```

Let's create 5 nodes.
```

for node in `cat nodes.txt`
do
ip=`echo $node |cut -d":" -f1`
node_name=`echo $node |cut -d ":" -f2`

docker-machine create --driver amazonec2 \
  --amazonec2-access-key=<add your access key in here> \
  --amazonec2-secret-key=<add your secret key in here> \
  --amazonec2-region=us-west-2 \
  --amazonec2-zone=c \
  --amazonec2-vpc-id=<add in vpc-id here> \
  --amazonec2-subnet-id=<add in subnet-id here> \
  --engine-opt cluster-store=consul://localhost:8500 \
  --engine-opt cluster-advertise=eth0:2376 \
  --swarm --swarm-master --swarm-image swarm \
  --swarm-discovery consul://localhost:8500 \
  --swarm-opt replication --swarm-opt advertise=${ip}:3376 \
  $node_name
done

```

# Checkpoint reached : You now have a simple 5 node cluster !!

