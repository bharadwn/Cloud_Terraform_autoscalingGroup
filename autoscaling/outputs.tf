output "vpc_id" {
  description = "ID of project VPC"
  value       = aws_vpc.proj-VPC.id
}

output "lb_url" {
  description = "URL of load balancer"
  value       = aws_lb.alb.dns_name
}


