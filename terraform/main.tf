# Reference Shared Infra State
data "terraform_remote_state" "shared" {
  backend = "s3"
  config = {
    bucket         = "rv-terraform-state-bucket"        # Replace with your S3 bucket name
    key            = "shared-infra/terraform.tfstate"    # Path to the shared infra state file
    region         = "eu-central-1"                      
    dynamodb_table = "terraform-locks"                   # DynamoDB table for state locking
    encrypt        = true
    profile = "rv-terraform"
  }
}

# Service Discovery Service for Edge
resource "aws_service_discovery_service" "edge" {
  name = "edge"

  dns_config {
    namespace_id = data.terraform_remote_state.shared.outputs.service_discovery_namespace_id

    dns_records {
      type = "A"
      ttl  = 60
    }
  }

  health_check_custom_config {
    failure_threshold = 1
  }
}

# Security Group for Edge Service
resource "aws_security_group" "edge_sg" {
  name        = "edge-sg"
  description = "Allow Edge traffic"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id

  ingress {
    from_port       = var.host_port
    to_port         = var.host_port
    protocol        = "tcp"
    security_groups = [data.terraform_remote_state.shared.outputs.lb_sg_id]
    description     = "Allow HTTP traffic from NLB"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "edge-sg"
  }
}

# ALB Target Group for Edge Service
resource "aws_lb_target_group" "edge_tg_blue" {
  name        = "edge-tg-blue"
  port        = var.host_port
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "edge-tg-blue"
  }
}

resource "aws_lb_target_group" "edge_tg_green" {
  name        = "edge-tg-green"
  port        = var.host_port
  protocol    = "TCP"
  vpc_id      = data.terraform_remote_state.shared.outputs.vpc_id
  target_type = "ip"

  health_check {
    protocol            = "TCP"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }

  tags = {
    Name = "edge-tg-green"
  }
}

# ALB Listener for Edge Service
resource "aws_lb_listener" "edge_listener" {
  load_balancer_arn = data.terraform_remote_state.shared.outputs.lb_arn
  port              = var.host_port
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.edge_tg_blue.arn
  }

  tags = {
    Name = "edge-listener"
  }

  lifecycle {
    ignore_changes = [ default_action[0].target_group_arn ]
  }
}

resource "aws_lb_listener" "edge_listener_green" {
  load_balancer_arn = data.terraform_remote_state.shared.outputs.lb_arn
  port              = 1994
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.edge_tg_green.arn
  }

  tags = {
    Name = "edge-listener"
  }

  lifecycle {
    ignore_changes = [ default_action[0].target_group_arn ]
  }
}

# ECR Repository for Edge Service
resource "aws_ecr_repository" "edge" {
  name                 = var.edge_ecr_repository_name
  image_tag_mutability = var.image_tag_mutability

  encryption_configuration {
    encryption_type = var.encryption_configuration.encryption_type
    kms_key         = var.encryption_configuration.kms_key != "" ? var.encryption_configuration.kms_key : null
  }

  tags = {
    Name        = "edge-ecr-repository"
  }
}

# IAM Policy for ECR Push/Pull Access
resource "aws_iam_policy" "edge_ecr_policy" {
  name        = "edge-ecr-policy"
  description = "IAM policy for Edge service to access ECR repository"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:BatchCheckLayerAvailability"
        ]
        Resource = aws_ecr_repository.edge.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = aws_ecr_repository.edge.arn
      },
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach the ECR policy to the ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "edge_ecr_attachment" {
  policy_arn = aws_iam_policy.edge_ecr_policy.arn
  role       = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_name
}

resource "aws_cloudwatch_log_group" "edge_log_group" {
  name              = "/ecs/edge"
  retention_in_days = 3
}

# Edge Task Definition
resource "aws_ecs_task_definition" "edge" {
  family                   = "edge"
  network_mode             = "awsvpc"
  requires_compatibilities = ["EC2"]
  cpu                      = var.edge_cpu
  memory                   = var.edge_memory

  container_definitions = jsonencode([{
    name  = "edge"
    image = var.edge_image
    portMappings = [{
      containerPort = var.container_port
      hostPort      = var.host_port
      protocol      = "tcp"
    }]
    healthCheck = {
      command     = ["CMD-SHELL", "pgrep -f 'python main.py' || exit 1"]
      interval    = 30
      timeout     = 10
      retries     = 5
      startPeriod = 20
    }
    logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.edge_log_group.name
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
    }
    environment = [
      {
        name  = "MQTT_BROKER_HOST"
        value = "mqtt.road-vision-cluster.local"
      },
      {
        name  = "MQTT_BROKER_PORT"
        value = "1883"
      },
      {
        name  = "MQTT_TOPIC"
        value = "agent_data_topic/car"
      },
      {
        name  = "HUB_HOST"
        value = "hub.road-vision-cluster.local"
      },
      {
        name  = "HUB_PORT"
        value = "8000"
      },
      {
        name  = "HUB_MQTT_BROKER_HOST"
        value = "hub.road-vision-cluster.local"
      },
      {
        name  = "HUB_MQTT_BROKER_PORT"
        value = "1883"
      },
      {
        name  = "HUB_MQTT_TOPIC"
        value = "processed_data_topic"
      }
    ]
  }])

  execution_role_arn = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_arn
  task_role_arn      = data.terraform_remote_state.shared.outputs.ecs_task_execution_role_arn
}

resource "aws_codedeploy_app" "edge" {
  name        = "edge-codedeploy-app"
  compute_platform = "ECS"
}

resource "aws_codedeploy_deployment_group" "edge" {
  app_name              = aws_codedeploy_app.edge.name
  deployment_group_name = "edge-deployment-group"
  service_role_arn      = data.terraform_remote_state.shared.outputs.codedeploy_role_arn

  deployment_config_name = "CodeDeployDefault.ECSAllAtOnce"

  ecs_service {
    cluster_name = data.terraform_remote_state.shared.outputs.ecs_cluster_name
    service_name = aws_ecs_service.edge.name
  }

  auto_rollback_configuration {
    enabled = true
    events  = ["DEPLOYMENT_FAILURE"]
  }

  blue_green_deployment_config {
    terminate_blue_instances_on_deployment_success {
      action                              = "TERMINATE"
      termination_wait_time_in_minutes    = 5
    }

    deployment_ready_option {
      action_on_timeout = "CONTINUE_DEPLOYMENT"
      wait_time_in_minutes = 0
    }
  }

  deployment_style {
    deployment_option = "WITH_TRAFFIC_CONTROL"
    deployment_type   = "BLUE_GREEN"
  }

  load_balancer_info {
    target_group_pair_info {
      target_group {
        name = aws_lb_target_group.edge_tg_blue.name
      }

      target_group {
        name = aws_lb_target_group.edge_tg_green.name
      }

      prod_traffic_route {
        listener_arns = [aws_lb_listener.edge_listener.arn]
      }
    }
  }
}

# Edge ECS Service
resource "aws_ecs_service" "edge" {
  name            = "edge-service"
  cluster         = data.terraform_remote_state.shared.outputs.ecs_cluster_id
  task_definition = aws_ecs_task_definition.edge.arn
  desired_count   = 1
  
  capacity_provider_strategy {
    capacity_provider = data.terraform_remote_state.shared.outputs.asg_capacity_provider
    weight            = 1
    base              = 100
  }

  network_configuration {
    subnets         = data.terraform_remote_state.shared.outputs.public_subnet_ids
    security_groups = [aws_security_group.edge_sg.id, data.terraform_remote_state.shared.outputs.ecs_instances_sg_id]
  }

  service_registries {
    registry_arn = aws_service_discovery_service.edge.arn
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.edge_tg_blue.arn
    container_name   = "edge"
    container_port   = var.container_port
  }

  deployment_controller {
    type = "CODE_DEPLOY"
  }

  lifecycle {
    ignore_changes = [task_definition, load_balancer]
  }
}
