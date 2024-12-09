output "edge_service_name" {
  description = "Name of the Edge ECS service"
  value       = aws_ecs_service.edge.name
}

output "edge_service_discovery_arn" {
  description = "ARN of the Edge Service Discovery service"
  value       = aws_service_discovery_service.edge.arn
}

output "edge_service_discovery_name" {
  value = aws_service_discovery_service.edge.name
}

output "edge_task_definition_arn" {
  description = "ARN of the Edge task definition"
  value       = aws_ecs_task_definition.edge.arn
}

output "edge_security_group_id" {
  description = "Security Group ID for Edge service"
  value       = aws_security_group.edge_sg.id
}

output "edge_target_group_arn" {
  description = "ARN of the Edge ALB Target Group"
  value       = aws_lb_target_group.edge_tg_blue.arn
}

output "edge_listener_arn" {
  description = "ARN of the Edge ALB Listener"
  value       = aws_lb_listener.edge_listener.arn
}

output "edge_ecr_repository_url" {
  description = "URL of the Edge ECR repository"
  value       = aws_ecr_repository.edge.repository_url
}

output "edge_ecr_repository_arn" {
  description = "ARN of the Edge ECR repository"
  value       = aws_ecr_repository.edge.arn
}

output "edge_ecr_policy_arn" {
  description = "ARN of the Edge ECR IAM policy"
  value       = aws_iam_policy.edge_ecr_policy.arn
}

output "codedeploy_edge_app_name" {
  value = aws_codedeploy_app.edge.name
}

output "codedeploy_edge_deployment_group_name" {
  value = aws_codedeploy_deployment_group.edge.deployment_group_name
}