variable "aws_region" {
  description = "The AWS region to deploy resources"
  type        = string
  default     = "eu-central-1"
}

variable "edge_image" {
  description = "Docker image for the Edge service"
  type        = string
  default     = "edge:latest"
}

variable "edge_cpu" {
  description = "CPU units for the Edge task"
  type        = string
  default     = "512"
}

variable "edge_memory" {
  description = "Memory (in MiB) for the Edge task"
  type        = string
  default     = "512"
}

variable "desired_count" {
  description = "Desired number of Edge service tasks"
  type        = number
  default     = 1
}

variable "service_name" {
  description = "Name of the Edge service"
  type        = string
  default     = "edge-service"
}

variable "container_port" {
  description = "Port on which the Edge container listens"
  type        = number
  default     = 1993
}

variable "host_port" {
  description = "Port on which the Edge host listens"
  type        = number
  default     = 1993
}

variable "edge_ecr_repository_name" {
  description = "Name of the ECR repository for the Edge service"
  type        = string
  default     = "edge-repo"
}

variable "image_tag_mutability" {
  description = "Image tag mutability setting"
  type        = string
  default     = "MUTABLE"
}

variable "encryption_configuration" {
  description = "Encryption settings for the ECR repository"
  type = object({
    encryption_type = string
    kms_key         = string
  })
  default = {
    encryption_type = "AES256"
    kms_key         = ""
  }
}