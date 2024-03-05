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

Utilize as variáveis "rke2-agent-vm-quantity" e "<k3s ou rke2>-vm-type" para respectivamente aumentar o
número de VMs e o tamanho de CPU e Memória. Exemplo para rke2-agent-vm-type temos:

t3a.medium  => 2 vCPU / 4 GiB RAM
t3a.large  => 2 vCPU / 8 GiB RAM

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
  default     = "rancher-cluster"
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

variable "rke2-server-vm-type" {
  description = "VM Size"
  default     = "t3a.medium"
}

variable "rke2-agent-vm-type" {
  description = "VM Size"
  default     = "t3a.large"
}

variable "rke2-agent-vm-quantity" {
  description = "Quantity of k8s worker nodes"
  type        = number
  default     = 3
}

variable "aws-credential-file" {
  description = "File with access key and token"
  default     = "../creds.txt"
}

variable "rancher-version" {
  description = "Rancher Console Version"
  default     = "2.8.2"
}

variable "k3s-version" {
  description = "K3S Kubernetes Version"
  default     = "v1.27.9+k3s1"
}

variable "rke2-version" {
  description = "RKE2 Kubernetes Version"
  default     = "v1.27.10+rke2r1"
}

variable "cert-manager-version" {
  description = "RKE2 Kubernetes Version"
  default     = "v1.14.3"
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
  k3s-data-server = <<CUSTOM_DATA
#!/bin/bash
yum install -y git curl wget jq
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_VERSION=${var.k3s-version} \
  K3S_TOKEN=${local.share_token} \
  sh -s - server
sleep 5
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
curl -sSL https://raw.githubusercontent.com/helm/helm/master/scripts/get-helm-3 | bash
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo add jetstack https://charts.jetstack.io
helm repo update
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
kubectl create namespace cattle-system
kubectl create namespace cert-manager
helm install \
  cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --version ${var.cert-manager-version} \
  --set installCRDs=true
helm install rancher rancher-stable/rancher \
  --version ${var.rancher-version} \
  --namespace cattle-system \
  --set hostname=rancher.$(dig @resolver4.opendns.com myip.opendns.com +short).sslip.io \
  --set bootstrapPassword=${var.rancher-bootstrap-pass} \
  --set replicas=1
CUSTOM_DATA
}

locals {
  rke2-data-server = <<CUSTOM_DATA
#!/bin/bash
yum install -y git curl wget jq
curl -sfL https://get.rke2.io | \
  INSTALL_RKE2_VERSION=${var.rke2-version} \
  INSTALL_RKE2_TYPE="server" INSTALL_RKE2_METHOD=tar sh -
sleep 5
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<EOF
token: ${local.share_token}
node-taint:
  - "CriticalAddonsOnly=true:NoExecute"
EOF
systemctl enable rke2-server.service
systemctl start rke2-server.service
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" \
  -O --output-dir /usr/local/bin
chmod 755 /usr/local/bin/kubectl
kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl > /dev/null
echo "export KUBECONFIG=/etc/rancher/rke2/rke2.yaml" > /etc/profile.d/kubeconfig.sh
CUSTOM_DATA
}


locals {
  rke2-data-agent = <<CUSTOM_DATA
#!/bin/bash
yum install -y curl iscsi-initiator-utils.x86_64 libiscsi.x86_64 libiscsi-utils.x86_64 nfs-utils.x86_64
curl -sfL https://get.rke2.io | \
INSTALL_RKE2_VERSION=${var.rke2-version} \
INSTALL_RKE2_TYPE="agent" INSTALL_RKE2_METHOD=tar sh -
sleep 5
mkdir -p /etc/rancher/rke2
cat > /etc/rancher/rke2/config.yaml <<EOF
server: https://${aws_instance.rancher-cluster-rke2-server.private_ip}:9345
token: ${local.share_token}
EOF
systemctl enable rke2-agent.service
systemctl start rke2-agent.service
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

resource "aws_eip" "rancher-ip-k3s-server" {
  tags = {
    Name = "${var.prefix}-rancher-ip-k3s-server-eip"
    Env  = var.prefix
  }
}

resource "aws_instance" "rancher-cluster-k3s-server" {
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.k3s-server-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.k3s-data-server)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-k3s-server"
    Env  = var.prefix
  }
}

resource "aws_instance" "rancher-cluster-rke2-server" {
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.rke2-server-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.rke2-data-server)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-rke2-server"
    Env  = var.prefix
  }
}

resource "aws_instance" "rancher-cluster-rke2-agent" {
  count                       = var.rke2-agent-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.rke2-agent-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.rke2-data-agent)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-rke2-agent-${count.index}"
    Env  = var.prefix
  }
}

resource "aws_vpc" "rancher-cluster-vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_hostnames = true

  tags = {
    Name = "${var.prefix}-vpc"
    Env  = var.prefix
  }
}

resource "aws_subnet" "rancher-cluster-subnet-a" {
  vpc_id                  = aws_vpc.rancher-cluster-vpc.id
  availability_zone       = "${var.region}a"
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-a"
    Env  = var.prefix
  }
}

resource "aws_subnet" "rancher-cluster-subnet-b" {
  vpc_id                  = aws_vpc.rancher-cluster-vpc.id
  availability_zone       = "${var.region}b"
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.prefix}-subnet-b"
    Env  = var.prefix
  }
}

resource "aws_security_group" "rancher-cluster-sg" {
  vpc_id = aws_vpc.rancher-cluster-vpc.id

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

resource "aws_internet_gateway" "rancher-cluster-gw" {
  vpc_id = aws_vpc.rancher-cluster-vpc.id

  tags = {
    Name = "${var.prefix}-gw"
    Env  = var.prefix
  }
}

resource "aws_route_table" "rancher-cluster-rt" {
  vpc_id = aws_vpc.rancher-cluster-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.rancher-cluster-gw.id
  }

  tags = {
    Name = "${var.prefix}-rt"
    Env  = var.prefix
  }
}

resource "aws_route_table_association" "rancher-cluster-subnet-a" {
  subnet_id      = aws_subnet.rancher-cluster-subnet-a.id
  route_table_id = aws_route_table.rancher-cluster-rt.id
}

resource "aws_route_table_association" "rancher-cluster-subnet-b" {
  subnet_id      = aws_subnet.rancher-cluster-subnet-b.id
  route_table_id = aws_route_table.rancher-cluster-rt.id
}

resource "aws_eip" "lb-ip-rancher-cluster-subnet-a" {
  tags = {
    Name = "${var.prefix}-lb-rke2-agent-eip"
    Env  = var.prefix
  }
}

resource "aws_lb" "lb-rancher-cluster" {
  name               = "${var.prefix}-rke2-agent-lb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.rancher-cluster-subnet-a.id
    allocation_id = aws_eip.lb-ip-rancher-cluster-subnet-a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.rancher-cluster-subnet-b.id
  }

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-rke2-agent-lb"
    Env  = var.prefix
  }
}

resource "aws_lb_listener" "lb-rancher-cluster" {
  load_balancer_arn = aws_lb.lb-rancher-cluster.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster.arn
  }
}

resource "aws_lb_target_group" "lb-tg-rancher-cluster" {
  name     = "${var.prefix}-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.rancher-cluster-vpc.id

  tags = {
    Name = "${var.prefix}-tg"
    Env  = var.prefix
  }
}

resource "aws_lb_target_group_attachment" "lb-tga-rancher-cluster" {
  count            = length(aws_instance.rancher-cluster-rke2-agent)
  target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster.arn
  target_id        = aws_instance.rancher-cluster-rke2-agent[count.index].id
  port             = 80
}

data "aws_eip" "lb-ip-rancher-cluster-subnet-a" {
  id = aws_eip.lb-ip-rancher-cluster-subnet-a.id
}

/*====
Output
======*/

output "lb-ip-rancher-cluster-subnet-a" {
  description = "Public IP of RKE2 Agent LB region_a Ingress"
  value       = data.aws_eip.lb-ip-rancher-cluster-subnet-a.public_ip
}

output "rancher-cluster-k3s-server_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster k3s server"
  value       = aws_instance.rancher-cluster-k3s-server.public_ip
}

output "rancher-cluster-rke2-server_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster rke2 server"
  value       = aws_instance.rancher-cluster-rke2-server.public_ip
}

output "rancher-cluster-rke2-agent_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster rke2 agents"
  value       = aws_instance.rancher-cluster-rke2-agent.*.public_ip
}

output "rancher_console_url" {
  value = "https://rancher.${aws_instance.rancher-cluster-k3s-server.public_ip}.sslip.io"
}

output "ingress_rke2_host_domain" {
  value = "No atributo 'host' do ingress use: <minha app>.${data.aws_eip.lb-ip-rancher-cluster-subnet-a.public_ip}.sslip.io"
}
