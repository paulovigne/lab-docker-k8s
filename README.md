# Download Files
You are able to do it on two ways:

### 1. Click on "<> Code" green button and "Download ZIP", unarchive at some place of your disk.

### 2. Install Git Client and clone entire repository:
- Windows and Mac [Git SCM](https://git-scm.com/download/win) or [Git For Windows](https://gitforwindows.org/)
- Linux, just use your package manager distro (yum, dnf, apt, apk)

```sh
git clone https://github.com/paulovigne/lab-docker-k8s.git
```

# Install Terraform
Follow the official Hashcorp instructions [here](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli), choose one of available instructions corresponding to your operacional system.

# Complete the credentials file
Get your aws credentials and insert intro `creds.txt` file on root repo directory:

```sh
[default]
aws_access_key_id=******************
aws_secret_access_key=******************
aws_session_token=******************
```

# Terraform
On your command line interface at the terraform file's directory, follow the steps:

- E.g. `lab-docker-k8s/docker`:

### Initialize Terraform
```sh
terraform init
```
### Plan and Apply
```sh
terraform plan
terraform apply
```
### Remove created resources
```sh
terraform destroy
```