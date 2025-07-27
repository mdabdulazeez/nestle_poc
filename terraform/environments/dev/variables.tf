# Variables for Development Environment

variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "nestle-poc"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "cluster_name" {
  description = "Base name for the EKS clusters"
  type        = string
  default     = "nestle-poc"
}

# Regional Configuration
variable "aws_region_primary" {
  description = "Primary AWS region"
  type        = string
  default     = "us-east-1"
}

variable "aws_region_secondary" {
  description = "Secondary AWS region"
  type        = string
  default     = "eu-west-1"
}

# Kubernetes Configuration
variable "kubernetes_version" {
  description = "Kubernetes version for EKS clusters"
  type        = string
  default     = "1.28"
}

# VPC Configuration - Primary Region
variable "vpc_cidr_primary" {
  description = "CIDR block for primary VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidrs_primary" {
  description = "List of public subnet CIDR blocks for primary region"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "private_subnet_cidrs_primary" {
  description = "List of private subnet CIDR blocks for primary region"
  type        = list(string)
  default     = ["10.0.10.0/24", "10.0.20.0/24", "10.0.30.0/24"]
}

# VPC Configuration - Secondary Region
variable "vpc_cidr_secondary" {
  description = "CIDR block for secondary VPC"
  type        = string
  default     = "10.1.0.0/16"
}

variable "public_subnet_cidrs_secondary" {
  description = "List of public subnet CIDR blocks for secondary region"
  type        = list(string)
  default     = ["10.1.1.0/24", "10.1.2.0/24", "10.1.3.0/24"]
}

variable "private_subnet_cidrs_secondary" {
  description = "List of private subnet CIDR blocks for secondary region"
  type        = list(string)
  default     = ["10.1.10.0/24", "10.1.20.0/24", "10.1.30.0/24"]
}

# EKS Configuration
variable "endpoint_private_access" {
  description = "Enable private API server endpoint"
  type        = bool
  default     = true
}

variable "endpoint_public_access" {
  description = "Enable public API server endpoint"
  type        = bool
  default     = true
}

variable "public_access_cidrs" {
  description = "List of CIDR blocks that can access the public API server endpoint"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "cluster_log_retention_in_days" {
  description = "Number of days to retain cluster logs"
  type        = number
  default     = 7
}

variable "node_group_ssh_key" {
  description = "EC2 Key Pair name for SSH access to worker nodes"
  type        = string
  default     = null
}

# ECR Configuration
variable "ecr_repositories" {
  description = "List of ECR repository names to create"
  type        = list(string)
  default     = [
    "jenkins",
    "sonarqube",
    "kyverno",
    "argocd",
    "sample-app"
  ]
} 