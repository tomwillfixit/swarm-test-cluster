# swarm-test-cluster

Code used to start a Swarm Cluster for the purpose of running unit tests

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

  Using Docker Machine and Docker Swarm we will spread test execution across multiple physical Docker hosts and leverage these additional resources to reduce test execution time.
  
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

The test cluster will consist of a Swarm Master and 4 Swarm Nodes.  We will start 5 nodes called qanode[1-5]. qanode5 will become the master since it is the last to start.

We will pass the following AWS credentials on the command line :
```
--amazonec2-access-key
--amazonec2-secret-key 
--amazonec2-region
--amazonec2-zone 
--amazonec2-vpc-id 
```

Let's create 5 nodes.
```

for node in $(seq 1 5); do

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
  --swarm-opt replication \
  qanode$node
done

```

Check that the 5 nodes have started successfully :
```
docker-machine ls

Example Output :

qanode1     -    amazonec2   Running   tcp://52.38.179.183:2376  qanode5 (master)   v1.11.1   
qanode2     -    amazonec2   Running   tcp://52.38.97.178:2376   qanode5 (master)   v1.11.1   
qanode3     -    amazonec2   Running   tcp://52.38.66.28:2376    qanode5 (master)   v1.11.1   
qanode4     -    amazonec2   Running   tcp://52.38.49.16:2376    qanode5 (master)   v1.11.1   
qanode5     -    amazonec2   Running   tcp://52.38.49.15:2376    qanode5 (master)   v1.11.1

```

# Checkpoint reached : You now have a simple 5 node cluster !!

# Step 3 : Install Consul on the 5 nodes

The following command will use the "docker-machine ssh" command to login to each node, pull the Consul container and start it.

```
for node in $(seq 1 5); do

    ip_address=$(docker-machine ssh qanode${node} ip a ls dev eth0 | sed -n 's,.*inet \(.*\)/.*,\1,p')
    echo "Installing Consul on : $ip_address"
    docker-machine ssh qanode${node} sudo docker run -d --restart=always --name consul_node$node \
        -e CONSUL_BIND_INTERFACE=eth0 --net host consul agent -server \
        -retry-join ${ip_address} -bootstrap-expect 5 -ui -client 0.0.0.0
done
```

# Checkpoint reached : You now have Consul running across the cluster !!

## Teardown

If you want to teardown the Swarm Cluster you can run the following command.  Warning : This will delete any EC2 instances that Machine created so use at own risk.
```
docker-machine rm -f $(docker-machine ls -q)
```

