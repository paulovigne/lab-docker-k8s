resource "aws_eip" "lb-ip-rancher-cluster-k3s-server-subnet-a" {
  tags = {
    Name = "${var.prefix}-lb-k3s-server-eip"
    Env  = var.prefix
  }
}

resource "aws_lb" "lb-rancher-cluster-k3s-server" {
  name               = "${var.prefix}-k3s-server-lb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.rancher-cluster-subnet-a.id
    allocation_id = aws_eip.lb-ip-rancher-cluster-k3s-server-subnet-a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.rancher-cluster-subnet-b.id
  }

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-k3s-server-lb"
    Env  = var.prefix
  }
}

resource "aws_lb_listener" "lb-rancher-cluster-k3s-server" {
  load_balancer_arn = aws_lb.lb-rancher-cluster-k3s-server.arn
  port              = "443"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster-k3s-server.arn
  }
}

resource "aws_lb_target_group" "lb-tg-rancher-cluster-k3s-server" {
  name     = "${var.prefix}-k3s-server-tg"
  port     = 443
  protocol = "TCP"
  vpc_id   = aws_vpc.rancher-cluster-vpc.id

  tags = {
    Name = "${var.prefix}-k3s-server-tg"
    Env  = var.prefix
  }
}

resource "aws_lb_target_group_attachment" "lb-tga-rancher-cluster-k3s-server" {
  count            = length(aws_instance.rancher-cluster-k3s-server)
  target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster-k3s-server.arn
  target_id        = aws_instance.rancher-cluster-k3s-server[count.index].id
  port             = 443
}

resource "aws_eip" "lb-ip-rancher-cluster-rke-ingress-subnet-a" {
  tags = {
    Name = "${var.prefix}-lb-rke-ingress-eip"
    Env  = var.prefix
  }
}

resource "aws_lb" "lb-rancher-cluster-rke-ingress" {
  name               = "${var.prefix}-rke-ingress-lb"
  internal           = false
  load_balancer_type = "network"

  subnet_mapping {
    subnet_id     = aws_subnet.rancher-cluster-subnet-a.id
    allocation_id = aws_eip.lb-ip-rancher-cluster-rke-ingress-subnet-a.id
  }

  subnet_mapping {
    subnet_id = aws_subnet.rancher-cluster-subnet-b.id
  }

  enable_deletion_protection = false

  tags = {
    Name = "${var.prefix}-rke-ingress-lb"
    Env  = var.prefix
  }
}

resource "aws_lb_listener" "lb-rancher-cluster-rke-ingress" {
  load_balancer_arn = aws_lb.lb-rancher-cluster-rke-ingress.arn
  port              = "80"
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster-rke-ingress.arn
  }
}

resource "aws_lb_target_group" "lb-tg-rancher-cluster-rke-ingress" {
  name     = "${var.prefix}-rke-ingress-tg"
  port     = 80
  protocol = "TCP"
  vpc_id   = aws_vpc.rancher-cluster-vpc.id

  tags = {
    Name = "${var.prefix}-rke-ingress-tg"
    Env  = var.prefix
  }
}

resource "aws_lb_target_group_attachment" "lb-tga-rancher-cluster-rke-ingress" {
  count            = length(aws_instance.rancher-cluster-rke-worker)
  target_group_arn = aws_lb_target_group.lb-tg-rancher-cluster-rke-ingress.arn
  target_id        = aws_instance.rancher-cluster-rke-worker[count.index].id
  port             = 80
}
