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

Utilize as variáveis "k8s-k3s-vm-quantity" e "k8s-k3s-vm-type" para respectivamente aumentar o
número de VMs e o tamanho de CPU e Memória. Exemplo para k8s-k3s-vm-type temos:

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
  default     = "k8s-k3s"
}

variable "region" {
  description = "Region that the instances will be created"
  default     = "us-east-1"
}

variable "k3s-server-vm-type" {
  description = "VM Size"
  default     = "t3a.medium"
}

variable "k3s-client-vm-quantity" {
  description = "Quantity of k3s worker nodes"
  type        = number
  default     = 3
}

variable "k3s-client-vm-type" {
  description = "VM Size"
  default     = "t3a.medium"
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
  k3s_token = base64encode("Token super secreto lab aws")
}

locals {
  custom-data-server = <<CUSTOM_DATA
#!/bin/bash
curl -sfL https://get.k3s.io | \
  K3S_TOKEN=${local.k3s_token} \
  sh -s - server \
  --node-taint CriticalAddonsOnly=true:NoExecute
sleep 5
yum install -y git curl wget jq
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
CUSTOM_DATA
}

locals {
  custom-data-client = <<CUSTOM_DATA
#!/bin/bash
curl -sfL https://get.k3s.io | K3S_URL=https://${aws_instance.k8s-k3s-server.private_ip}:6443 K3S_TOKEN=${local.k3s_token} sh -
yum install -y iscsi-initiator-utils.x86_64 libiscsi.x86_64 libiscsi-utils.x86_64 nfs-utils.x86_64
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
    values = ["amzn2-ami-hvm*"]
  }
}

resource "aws_instance" "k8s-k3s-server" {
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.k8s-k3s-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.k8s-k3s-sg.id]
  associate_public_ip_address = true
  instance_type               = var.k3s-server-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.custom-data-server)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-server"
    Env  = var.prefix
  }
}

resource "aws_instance" "k8s-k3s-client" {
  count                       = var.k3s-client-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.k8s-k3s-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.k8s-k3s-sg.id]
  associate_public_ip_address = true
  instance_type               = var.k3s-client-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.custom-data-client)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-client-${count.index}"
    Env  = var.prefix
  }
}

resource "aws_vpc" "k8s-k3s-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
    Env  = var.prefix
  }
}

resource "aws_subnet" "k8s-k3s-subnet-a" {
  vpc_id                  = aws_vpc.k8s-k3s-vpc.id
  availability_zone       = "${var.region}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-a"
    Env  = var.prefix
  }
}

resource "aws_subnet" "k8s-k3s-subnet-b" {
  vpc_id                  = aws_vpc.k8s-k3s-vpc.id
  availability_zone       = "${var.region}b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-b"
    Env  = var.prefix
  }
}

resource "aws_security_group" "k8s-k3s-sg" {
  vpc_id = aws_vpc.k8s-k3s-vpc.id

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

resource "aws_internet_gateway" "k8s-k3s-gw" {
  vpc_id = aws_vpc.k8s-k3s-vpc.id

  tags = {
    Name = "${var.prefix}-gw"
    Env  = var.prefix
  }
}

resource "aws_route_table" "k8s-k3s-rt" {
  vpc_id = aws_vpc.k8s-k3s-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.k8s-k3s-gw.id
  }

  tags = {
    Name = "${var.prefix}-rt"
    Env  = var.prefix
  }
}

resource "aws_route_table_association" "k8s-k3s-subnet-a" {
  subnet_id      = aws_subnet.k8s-k3s-subnet-a.id
  route_table_id = aws_route_table.k8s-k3s-rt.id
}

resource "aws_route_table_association" "k8s-k3s-subnet-b" {
  subnet_id      = aws_subnet.k8s-k3s-subnet-b.id
  route_table_id = aws_route_table.k8s-k3s-rt.id
}

resource "aws_eip" "lb-ip-k8s-k3s-subnet-a" {
  tags = {
    Name = "${var.prefix}-eip"
    Env  = var.prefix
  }
}

resource "aws_lb" "lb-k8s-k3s" {
  name               = "${var.prefix}-lb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.k8s-k3s-subnet-a.id
    allocation_id = aws_eip.lb-ip-k8s-k3s-subnet-a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.k8s-k3s-subnet-b.id
  }

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-lb"
    Env  = var.prefix
  }
}

resource "aws_lb_listener" "lb-k8s-k3s" {
  load_balancer_arn = aws_lb.lb-k8s-k3s.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg-k8s-k3s.arn
  }
}

resource "aws_lb_target_group" "lb-tg-k8s-k3s" {
  name     = "${var.prefix}-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.k8s-k3s-vpc.id

  tags = {
    Name = "${var.prefix}-tg"
    Env  = var.prefix
  }
}

resource "aws_lb_target_group_attachment" "lb-tga-k8s-k3s" {
  count            = length(aws_instance.k8s-k3s-client)
  target_group_arn = aws_lb_target_group.lb-tg-k8s-k3s.arn
  target_id        = aws_instance.k8s-k3s-client[count.index].id
  port             = 80
}

data "aws_eip" "lb-ip-k8s-k3s-subnet-a" {
  id = aws_eip.lb-ip-k8s-k3s-subnet-a.id
}

/*====
Output
======*/

output "lb-ip-k8s-k3s-subnet-a" {
  description = "Public IP of k3s LB region_a Ingress"
  value       = data.aws_eip.lb-ip-k8s-k3s-subnet-a.public_ip
}

output "k8s-k3s-server_public_ip" {
  description = "Public IP address of the EC2 instance k8s-k3s server"
  value       = aws_instance.k8s-k3s-server.*.public_ip
}

output "k8s-k3s-client_public_ip" {
  description = "Public IP address of the EC2 instance k8s-k3s client"
  value       = aws_instance.k8s-k3s-client.*.public_ip
}