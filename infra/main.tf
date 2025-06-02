################################
# 1) ECS Cluster Fargate
################################

resource "aws_ecs_cluster" "this" {
  name = var.ecs_cluster_name
  tags = var.tags
}

################################
# 2) IAM Roles para ECS Tasks
################################

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "${var.ecs_cluster_name}-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "datadog_agent_task_role" {
  name = "${var.ecs_cluster_name}-datadog-agent-task-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "datadog_agent_execution_policy" {
  role       = aws_iam_role.datadog_agent_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "datadog_agent_cloudwatch_policy" {
  role       = aws_iam_role.datadog_agent_task_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchFullAccess"
}

resource "aws_iam_role_policy" "datadog_agent_policy" {
  name = "datadog-agent-policy"
  role = aws_iam_role.datadog_agent_task_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecs:DescribeContainerInstances",
          "ecs:DescribeTasks",
          "ecs:ListTasks",
          "ecs:ListClusters",
          "ecs:DescribeClusters"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "cloudwatch:GetMetricData",
          "cloudwatch:ListMetrics",
          "cloudwatch:GetMetricStatistics",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams",
          "logs:GetLogEvents",
          "logs:FilterLogEvents"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "tag:GetResources",
          "tag:TagResources"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:DescribeInstances",
          "ec2:DescribeTags",
          "ec2:DescribeVolumes",
          "ec2:DescribeVpcs",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

################################
# 3) Security Groups
################################

resource "aws_security_group" "alb_sg" {
  name        = "${var.alb_name}-sg"
  description = "Security Group para o ALB"
  vpc_id      = var.vpc_id

  ingress {
    description = "Permitir HTTP de qualquer lugar"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Permitir todo o egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

resource "aws_security_group" "ecs_tasks_sg" {
  name        = "${var.ecs_cluster_name}-tasks-sg"
  description = "Security Group para ECS Tasks (app + datadog-agent)"
  vpc_id      = var.vpc_id

  ingress {
    description       = "Trafego HTTP do ALB"
    from_port         = var.app_container_port
    to_port           = var.app_container_port
    protocol          = "tcp"
    security_groups   = [aws_security_group.alb_sg.id]
  }

  egress {
    description = "Permitir todo o egress"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

################################
# 4) Application Load Balancer
################################

resource "aws_lb" "this" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.subnet_ids

  tags = var.tags
}

################################
# 5) Target Groups (Green e Blue)
################################

resource "aws_lb_target_group" "green" {
  name        = "${var.app_name}-tg-green"
  port        = var.app_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = var.tags
}

resource "aws_lb_target_group" "blue" {
  name        = "${var.app_name}-tg-blue"
  port        = var.app_container_port
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/actuator/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
    matcher             = "200"
  }

  tags = var.tags
}

################################
# 6) Listener do ALB com regras de Blue/Green (peso 90/10)
################################

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = "forward"
    forward {
      target_group {
        arn    = aws_lb_target_group.green.arn
        weight = 90
      }
      target_group {
        arn    = aws_lb_target_group.blue.arn
        weight = 10
      }
      stickiness {
        enabled  = false
        duration = 1
      }
    }
  }
}

################################
# CloudWatch Log Group
################################

resource "aws_cloudwatch_log_group" "app" {
  name              = "/ecs/${var.app_name}"
  retention_in_days = 1

  tags = var.tags
}
resource "aws_cloudwatch_log_group" "datadog_agent" {
  name              = "/ecs/datadog-agent"
  retention_in_days = 1

  tags = var.tags
}

################################
# 7) Task Definition da Aplicação
################################

resource "aws_ecs_task_definition" "app_with_datadog" {
  family                   = var.app_name
  cpu                      = "256"
  memory                   = "512"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.datadog_agent_task_role.arn

  container_definitions = jsonencode([
    {
      name      = "datadog-agent"
      image     = "datadog/agent:latest"
      essential = true
      environment = [
        { name = "DD_API_KEY", value = var.dd_api_key },
        { name = "DD_SITE", value = "datadoghq.com" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_APM_ENABLED", value = "true" },
        { name = "DD_LOGS_ENABLED", value = "true" },
        { name = "ECS_FARGATE", value = "true" },
        { name = "DD_APM_RECEIVER_PORT", value = "8126" },
      ]
      portMappings = [
        { containerPort = 8126, hostPort = 8126, protocol = "tcp" },
        { containerPort = 8125, hostPort = 8125, protocol = "udp" }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/datadog-agent"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    },
    {
      name         = var.app_name
      image        = var.app_image
      essential    = true
      portMappings = [
        {
          containerPort = var.app_container_port
          protocol      = "tcp"
        }
      ]
      environment = [
        { name = "DD_AGENT_HOST", value = "localhost" },
        { name = "DD_ENV", value = "prod" },
        { name = "DD_SERVICE", value = var.app_name },
        { name = "DD_VERSION", value = "1.0.0" },
        { name = "DD_TRACE_ENABLED", value = "true" },
        { name = "DD_LOGS_INJECTION", value = "true" },
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.app_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])

  tags = var.tags
}




################################
# 8) ECS Services (Green e Blue)
################################

resource "aws_ecs_service" "app_green" {
  name            = "${var.app_name}-green"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app_with_datadog.arn
  desired_count   = 2
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.green.arn
    container_name   = var.app_name
    container_port   = var.app_container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = var.tags

  depends_on = [
    aws_lb_listener.http
  ]
}

resource "aws_ecs_service" "app_blue" {
  name            = "${var.app_name}-blue"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.app_with_datadog.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    assign_public_ip = true
    security_groups  = [aws_security_group.ecs_tasks_sg.id]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.blue.arn
    container_name   = var.app_name
    container_port   = var.app_container_port
  }

  deployment_minimum_healthy_percent = 50
  deployment_maximum_percent         = 200

  tags = var.tags

  depends_on = [
    aws_lb_listener.http
  ]
}