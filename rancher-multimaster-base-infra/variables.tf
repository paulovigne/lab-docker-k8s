variable "prefix" {
  description = "Prefix of this resources"
  default     = "k8s-multimaster"
}

variable "region" {
  description = "Region that the instances will be created"
  default     = "us-east-1"
}

variable "rancher-bootstrap-pass" {
  description = "Intial Rancher Password"
  default     = "admin"
}

variable "k3s-server-vm-type" {
  description = "VM Size"
  default     = "t3a.medium"
}

variable "rke-master-vm-type" {
  description = "VM Size"
  default     = "t3a.medium"
}

variable "rke-worker-vm-type" {
  description = "VM Size"
  default     = "t3a.large"
}

variable "k3s-server-vm-quantity" {
  description = "Quantity of k3s server nodes"
  type        = number
  default     = 3
}

variable "rke-master-vm-quantity" {
  description = "Quantity of rke k8s master nodes"
  type        = number
  default     = 3
}

variable "rke-worker-vm-quantity" {
  description = "Quantity of rke k8s worker nodes"
  type        = number
  default     = 3
}

variable "aws-credential-file" {
  description = "File with access key and token"
  default     = "../creds.txt"
}

variable "rancher-version" {
  description = "Rancher Console Version"
  default     = "2.10.1"
}

variable "k3s-version" {
  description = "K3S Kubernetes Version"
  default     = "v1.31.3+k3s1"
}

variable "rke-version" {
  description = "RKE Utility Version"
  default     = "1.7.1"
}

variable "rke-k8s-version" {
  description = "RKE Kubernetes Version"
  default     = "v1.31.3-rancher1-1"
}

variable "cert-manager-version" {
  description = "Cert Manager Version"
  default     = "v1.16.2"
}

locals {
  allow-ports = [{
    description = "All Ports Internal Access"
    protocol    = "-1"
    cidrblk     = []
    self        = true
    port        = "0"
    }, {
    description = "All Ports External Access"
    protocol    = "-1"
    cidrblk     = ["0.0.0.0/0"]
    self        = false
    port        = "0"
  }]
}

locals {
  share_token = base64encode("Token super secreto lab aws")
}

locals {
  k3s-data-nodes = <<CUSTOM_DATA
#!/bin/bash
yum install -y git wget jq bash-completion iptables bind-utils
CUSTOM_DATA
}

locals {
  rke-data-nodes = <<CUSTOM_DATA
#!/bin/bash
yum -y install wget jq git socat conntrack ipset docker bash-completion iptables bind-utils
sysctl -w net.ipv4.conf.all.forwarding=1
systemctl start docker && systemctl enable docker
usermod -G docker ec2-user
CUSTOM_DATA
}
