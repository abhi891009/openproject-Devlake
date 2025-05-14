output "alb_dns_name" {
  value = aws_lb.app_lb.dns_name
}

output "openproject_instance_ip" {
  value = aws_instance.openproject.public_ip
}

output "devlake_instance_ip" {
  value = aws_instance.devlake.public_ip
}