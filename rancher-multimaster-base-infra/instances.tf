resource "aws_instance" "rancher-cluster-k3s-server" {
  count                       = var.k3s-server-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.k3s-server-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.k3s-data-nodes)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-k3s-server-${count.index}"
    Env  = var.prefix
  }
}

resource "aws_instance" "rancher-cluster-rke-master" {
  count                       = var.rke-master-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.rke-master-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.rke-data-nodes)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-rke-master-${count.index}"
    Env  = var.prefix
  }
}

resource "aws_instance" "rancher-cluster-rke-worker" {
  count                       = var.rke-worker-vm-quantity
  ami                         = data.aws_ami.amazon-linux-2.id
  subnet_id                   = aws_subnet.rancher-cluster-subnet-a.id
  vpc_security_group_ids      = [aws_security_group.rancher-cluster-sg.id]
  associate_public_ip_address = true
  instance_type               = var.rke-worker-vm-type
  key_name                    = aws_key_pair.vm.id
  user_data_base64            = base64encode(local.rke-data-nodes)
  root_block_device {
    volume_size           = "30"
    volume_type           = "gp2"
    delete_on_termination = true
  }
  tags = {
    Name = "${var.prefix}-rke-worker-${count.index}"
    Env  = var.prefix
  }
}