# swarm-test-cluster

Code used to start a Swarm Cluster for the purpose of running tests

## Goal

Create a seamlessly scalable test environment on which containerised unit tests can be run in a single container or across hundreds of containers.

Using 2 tools from the Docker ecosystem (Machine and Swarm) we can create a scalable test environment in AWS and seamlessly scale our tests across a Swarm cluster.

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


## Setup 

Note : This work is being done on Ubuntu but will be ported to Centos 7 in future.

Install Docker :
```
https://docs.docker.com/engine/installation/linux/ubuntulinux/
```
Install Docker Machine : 
```
curl -L https://github.com/docker/machine/releases/download/v0.6.0/docker-machine-`uname -s`-`uname -m` > /usr/local/bin/docker-machine && chmod +x /usr/local/bin/docker-machine
```

Install Docker Swarm :

You can install the Swarm binary but it easier to use the Swarm Image.  The command below will pull the latest Swarm image and print out the help text.
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


