/*====

Nota: Este arquivo não segue as boas práticas do Terraform, é apenas uma simplificação para
criação de laboratórios rápidos sem necessidade de conhecimento prévio da ferramenta.

Acrescente no diretório anterior do arquivo ".tf" o arquivo "creds.txt", contendo as
credenciais de acesso a sua conta AWS, lá deverá conter aws_access_key_id, aws_secret_access_key
e opcionalmente aws_session_token. Tal localização pode ser modificada pela variável
"aws-credential-file".

Para acessar a(s) VM(s) via SSH, será necessário utilizar a chave RSA privativa que é gerada
dinamicamente e disponibilizada no mesmo diretório do arquivo ".tf" com o nome de "id_rsa"

ssh -i id_rsa ec2-user@[ip ou nome da vm]

Utilize as variáveis "docker-vm-quantity" e "docker-vm-type" para respectivamente aumentar o
número de VMs e o tamanho de CPU e Memória. Exemplo para docker-vm-type temos:

t2.micro    => 1 vCPU / 1 GiB RAM
t3a.medium  => 2 vCPU / 4 GiB RAM

https://aws.amazon.com/ec2/instance-types/

Este Laboratório foi testado em:
  AWS Academy Lab Project - Cloud Web Application Builder
  Instruções do Laboratório: Criação de um Aplicativo Web Dimensionável e Altamente Disponível

======*/

/*====
Variables
======*/
variable "prefix" {
  description = "Prefix of this resources"
  default     = "docker"
}

variable "region" {
  description = "Region that the instances will be created"
  default     = "us-east-1"
}

variable "docker-vm-quantity" {
  description = "Quantity of vm nodes"
  type        = number
  default     = 3
}

variable "docker-vm-type" {
  description = "VM Size"
  default     = "t2.micro"
  #default     = "t3a.medium"
}

variable "enable-haproxy" {
  description = "false to Disable, true to Enable, cration of HAProxy VM"
  type        = bool
  default     = true
}

variable "haproxy-vm-type" {
  description = "VM Size"
  default     = "t2.micro"
}

variable "aws-credential-file" {
  description = "File with access key and token"
  default     = "../creds.txt"
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
  custom-data-docker = <<CUSTOM_DATA
#!/bin/bash
yum -y install wget jq git socat conntrack ipset docker
sysctl -w net.ipv4.conf.all.forwarding=1
systemctl start docker && systemctl enable docker
wget https://github.com/docker/compose/releases/download/v2.23.3/docker-compose-Linux-x86_64
sudo mv docker-compose-Linux-x86_64 /usr/local/bin/docker-compose
sudo chmod 755 /usr/local/bin/docker-compose
CUSTOM_DATA
}

locals {
  custom-data-haproxy = <<CUSTOM_DATA
#!/bin/bash
yum -y install wget jq git socat conntrack ipset haproxy
sysctl -w net.ipv4.conf.all.forwarding=1
sed -i 's/:5000/:80/g' /etc/haproxy/haproxy.cfg
systemctl start haproxy && systemctl enable haproxy
CUSTOM_DATA
}

/*====
Resources
======*/

provider "aws" {
  region                   = var.region
  shared_credentials_files = [var.aws-credential-file]
}

resource "tls_private_key" "ssh-key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "local_file" "private-key" {
  content  = tls_private_key.ssh-key.private_key_pem
  filename = "id_rsa"
}

resource "local_file" "public-key" {
  content  = tls_private_key.ssh-key.public_key_openssh
  filename = "id_rsa.pub"
}

resource "aws_key_pair" "vm" {
  key_name   = "${var.prefix}-pub-key"
  public_key = tls_private_key.ssh-key.public_key_openssh
}

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

resource "aws_instance" "docker-vm" {
  count                       = var.docker-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.docker-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.docker-sg.id]
  associate_public_ip_address = true
  instance_type               = var.docker-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.custom-data-docker)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-${count.index}"
    Env  = var.prefix
  }
}

resource "aws_instance" "docker-haproxy-vm" {
  count                       = var.enable-haproxy ? 1 : 0
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.docker-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.docker-sg.id]
  associate_public_ip_address = true
  instance_type               = var.haproxy-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.custom-data-haproxy)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-haproxy"
    Env  = var.prefix
  }
}

resource "aws_vpc" "docker-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
    Env  = var.prefix
  }
}

resource "aws_subnet" "docker-subnet-a" {
  vpc_id                  = aws_vpc.docker-vpc.id
  availability_zone       = "${var.region}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-a"
    Env  = var.prefix
  }
}

resource "aws_security_group" "docker-sg" {
  vpc_id = aws_vpc.docker-vpc.id

  dynamic "ingress" {
    for_each = local.allow-ports
    iterator = each
    content {
      description      = each.value.description
      protocol         = each.value.protocol
      self             = each.value.self
      from_port        = each.value.port
      to_port          = each.value.port
      cidr_blocks      = each.value.cidrblk
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
    }
  }

  egress = [
    {
      description      = "Allow All Egress Traffic"
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = {
    Name = "${var.prefix}-sg"
    Env  = var.prefix
  }
}

resource "aws_internet_gateway" "docker-gw" {
  vpc_id = aws_vpc.docker-vpc.id

  tags = {
    Name = "${var.prefix}-gw"
    Env  = var.prefix
  }
}

resource "aws_route_table" "docker-rt" {
  vpc_id = aws_vpc.docker-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.docker-gw.id
  }

  tags = {
    Name = "${var.prefix}-rt"
    Env  = var.prefix
  }
}

resource "aws_route_table_association" "docker-subnet-a" {
  subnet_id      = aws_subnet.docker-subnet-a.id
  route_table_id = aws_route_table.docker-rt.id
}

/*====
Output
======*/

output "docker_public_ip" {
  description = "Public IP address of the EC2 instance Docker"
  value       = aws_instance.docker-vm.*.public_ip
}

output "haproxy_public_ip" {
  description = "Public IP address of the EC2 instance HaProxy"
  value       = aws_instance.docker-haproxy-vm.*.public_ip
}