data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

data "aws_eip" "lb-ip-rancher-cluster-k3s-server-subnet-a" {
  id = aws_eip.lb-ip-rancher-cluster-k3s-server-subnet-a.id
}

data "aws_eip" "lb-ip-rancher-cluster-rke-ingress-subnet-a" {
  id = aws_eip.lb-ip-rancher-cluster-rke-ingress-subnet-a.id
}
