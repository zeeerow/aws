
output "lb_dns_name" {
  description = "DNS name of the load balancer"
  value       = aws_lb.external_alb.dns_name
}

output "vpc_id" {
  description = "ID of the created VPC"
  value       = aws_vpc.riz.id
}

output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.rds.address
}
