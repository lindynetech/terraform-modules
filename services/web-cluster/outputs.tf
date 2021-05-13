output "alb_dns_name" {
  value       = aws_alb.tf-alb.dns_name
  description = "DNS of ALB"
}

output "asg_name" {
  value       = aws_autoscaling_group.tf-asg.name
  description = "The name of the Auto Scaling Group"
}

output "alb_security_group_id" {
  value       = aws_security_group.tf-alb-sg.id
  description = "The ID of the Security Group attached to the load balancer"
}
