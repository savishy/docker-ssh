# docker-ssh #
This is a Centos 6 based Docker container that you can SSH into.

The Docker Image is [savishy/docker-ssh](http://hub.docker.com/r/savishy/docker-ssh/).

## About

This effort started because I needed a Docker container mimicking CentOS
systems, to develop Ansible playbooks on.

Possible uses:

1. As a reusable deployment target for Ansible playbooks.
1. As a Jenkins SSH Slave.

## How to use

### Pull the image

Simply pull the latest version of [savishy/docker-ssh](http://hub.docker.com/r/savishy/docker-ssh).

```
docker pull savishy/docker-ssh:latest
```

### Run a container

Run a container off of it.

```
$ docker run --name docker-ssh-container -d -d -p 2200:22 savishy/docker-ssh:latest
```

### Find out container IP

SSH to the container will require the container IP address. This can be obtained as:

```bash
$ docker inspect -f {{.NetworkSettings.IPAddress}} docker-ssh-container
172.17.0.3
```

### SSH into the container

SSH into the container using the `ansible_id_rsa` private key present in this repository.

```
ssh -i ansible_id_rsa root@172.17.0.2
```


## How To: Create a docker image and run a container

Execute the `create.sh` script. This does the following
* create key pair `ansible_id_rsa` and `ansible_id_rsa.pub`.
* Paste a local copy (in current working dir) which will be used for Docker image creation.
* Paste a copy to `$HOME/.ssh/`.
* Create a Docker Image `docker-ssh` which contains centos 6 *plus all customizations required for SSH into a CentOS container*.
* Run a container off it, `docker-ssh-container`.

Now, to SSH to it, Execute

```
ssh -i ~/.ssh/ansible_id_rsa root@172.17.0.2 -p 22
```
