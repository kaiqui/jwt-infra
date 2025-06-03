output "alb_dns_name" {
  description = "DNS Name público do Application Load Balancer"
  value       = aws_lb.this.dns_name
}

output "ecs_cluster_name" {
  description = "Nome do ECS Cluster"
  value       = aws_ecs_cluster.this.name
}

output "task_definition_arn" {
  description = "ARN do Task Definition utilizado pelos Services"
  value       = aws_ecs_task_definition.app_with_datadog.arn
}
