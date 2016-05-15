# Troubleshooting

During the setup you may encounter a few issues.  All the issues that I hit and the solutions can be found below.

## 1 : AWS Auth Failure

If you see the following error then you might have a clock skew :
```
Running pre-create checks...
Error with pre-create check: "AuthFailure: AWS was not able to validate the provided access credentials\n\tstatus code: 401, request id: "
```

Solution :
```
sudo apt-get install ntpdate
sudo ntpdate ntp.ubuntu.com
```

## 2 : Unable to ssh into node

When a node is started Docker Machine hangs at the ssh login.  Looks like this :
```
Running pre-create checks...
Creating machine...
(172.0.5.2) Launching instance...
Waiting for machine to be running, this may take a few minutes...
Detecting operating system of created instance...
Waiting for SSH to be available...
```

Solution :
```
I needed to specify the subnet-id as well as the vpc-id at runtime.

--amazonec2-vpc-id=<enter vpc-id here>
--amazonec2-subnet-id=<enter subnet-id here>
```
