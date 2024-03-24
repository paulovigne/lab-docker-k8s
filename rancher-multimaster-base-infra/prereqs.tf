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

resource "local_file" "rke-cluster-file" {
  content = templatefile("rke_cluster.tmpl",
    {
      k8s-master-nodes = aws_instance.rancher-cluster-rke-master.*.private_dns
      k8s-worker-nodes = aws_instance.rancher-cluster-rke-worker.*.private_dns
      k8s-version      = var.rke-k8s-version
    }
  )
  filename = "cluster.yml"
}

resource "local_file" "bastion-scripts" {
  content = templatefile("bastion_scripts.tmpl",
    {
      k3s-version            = var.k3s-version
      share_token            = local.share_token
      k3s-server-bootstrap   = aws_instance.rancher-cluster-k3s-server[0].private_ip
      cert-manager-version   = var.cert-manager-version
      rancher-version        = var.rancher-version
      k3s-server-lb          = data.aws_eip.lb-ip-rancher-cluster-k3s-server-subnet-a.public_ip
      rancher-bootstrap-pass = var.rancher-bootstrap-pass
      rke-version            = var.rke-version
    }
  )
  filename = "scripts.sh"
}

resource "terraform_data" "bastion-scripts" {
  depends_on = [aws_instance.rancher-cluster-k3s-server, aws_eip.lb-ip-rancher-cluster-k3s-server-subnet-a]

  connection {
    type        = "ssh"
    host        = aws_instance.rancher-cluster-k3s-server[0].public_ip
    agent       = false
    user        = "ec2-user"
    private_key = file(local_file.private-key.filename)
  }

  provisioner "file" {
    source      = local_file.private-key.filename
    destination = "/home/ec2-user/.ssh/id_rsa"
  }

  provisioner "file" {
    source      = local_file.rke-cluster-file.filename
    destination = "/home/ec2-user/cluster.yml"
  }

  provisioner "file" {
    source      = local_file.bastion-scripts.filename
    destination = "/home/ec2-user/scripts.sh"
  }
}