variable "vpc_id" {
  description = "ID da VPC já existente onde será criado o cluster e ALB"
  type        = string
}

variable "subnet_ids" {
  description = "Lista de subnets (mínimo 3) nas quais o ALB e ECS Tasks rodarão"
  type        = list(string)
}

variable "ecs_cluster_name" {
  description = "Nome a ser usado no ECS Cluster Fargate"
  type        = string
  default     = "ecs-cluster"
}

variable "alb_name" {
  description = "Nome do Application Load Balancer"
  type        = string
  default     = "ecs-alb"
}

variable "app_name" {
  description = "Nome da aplicação, usado como family do Task Definition e nome do container"
  type        = string
  default     = "myapp"
}

variable "app_container_port" {
  description = "Porta em que o container da aplicação escuta (ex.: 8080)"
  type        = number
  default     = 8080
}

variable "dd_api_key" {
  description = "Datadog API Key (usada dentro do container do datadog-agent)"
  type        = string
}

variable "dd_app_key" {
  description = "Datadog APP Key (necessária para criar monitores ou integrações via Terraform)"
  type        = string
}

variable "tags" {
  description = "Tags aplicadas a todos os recursos"
  type        = map(string)
  default     = {
    Environment = "dev"
    Project     = "ecs-canary"
  }
}

variable "aws_region" {
  description = "Região AWS onde os recursos serão criados"
  type        = string
  default     = "sa-east-1"
  
}

variable "app_image" {
  description = "Imagem Docker da aplicação a ser executada no ECS"
  type        = string
  default     = "docker.io/kailima/jwt-validator:latest"
  
}