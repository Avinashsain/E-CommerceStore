# ─────────────────────────────────────────
# outputs.tf
# ─────────────────────────────────────────

output "public_ip" {
  description = "Public IP of the EC2 instance"
  value       = aws_instance.app.public_ip
}

output "public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.app.public_dns
}

output "frontend_url" {
  description = "Frontend application URL"
  value       = "http://${aws_instance.app.public_ip}:3000"
}

output "user_service_url" {
  description = "User service URL"
  value       = "http://${aws_instance.app.public_ip}:3001"
}

output "product_service_url" {
  description = "Product service URL"
  value       = "http://${aws_instance.app.public_ip}:3002"
}

output "cart_service_url" {
  description = "Cart service URL"
  value       = "http://${aws_instance.app.public_ip}:3003"
}

output "order_service_url" {
  description = "Order service URL"
  value       = "http://${aws_instance.app.public_ip}:3004"
}

output "ssh_command" {
  description = "SSH command to connect to EC2"
  value       = "ssh -i ~/.ssh/id_rsa ubuntu@${aws_instance.app.public_ip}"
}

output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.app.id
}

output "ec2_instance_id" {
  description = "EC2 Instance ID"
  value       = aws_instance.app.id
}
