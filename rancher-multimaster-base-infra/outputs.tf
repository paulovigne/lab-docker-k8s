output "rancher-cluster-k3s-server_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster k3s server"
  value       = aws_instance.rancher-cluster-k3s-server.*.public_ip
}

output "rancher-cluster-k3s-server_private_dns" {
  description = "Private name of the EC2 instance rancher-cluster k3s server"
  value       = aws_instance.rancher-cluster-k3s-server.*.private_dns
}

output "rancher-cluster-rke-master_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster rke master"
  value       = aws_instance.rancher-cluster-rke-master.*.public_ip
}

output "rancher-cluster-rke-worker_public_ip" {
  description = "Public IP address of the EC2 instance rancher-cluster rke worker"
  value       = aws_instance.rancher-cluster-rke-worker.*.public_ip
}

output "rancher-cluster-rke-master_private_dns" {
  description = "Private name of the EC2 instance rancher-cluster rke master"
  value       = aws_instance.rancher-cluster-rke-master.*.private_dns
}

output "rancher-cluster-rke-worker_private_dns" {
  description = "Private name of the EC2 instance rancher-cluster rke worker"
  value       = aws_instance.rancher-cluster-rke-worker.*.private_dns
}

output "rancher_console_url" {
  value = "https://rancher.${data.aws_eip.lb-ip-rancher-cluster-k3s-server-subnet-a.public_ip}.sslip.io"
}

output "ingress_rke2_host_domain" {
  value = "No atributo 'host' do ingress use: <minha app>.${data.aws_eip.lb-ip-rancher-cluster-rke-ingress-subnet-a.public_ip}.sslip.io"
}

output "scripts_bastion" {
  value = "Scripts de instalacao em ${aws_instance.rancher-cluster-k3s-server[0].private_dns}: ec2-user@${aws_instance.rancher-cluster-k3s-server[0].public_ip}"
}