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