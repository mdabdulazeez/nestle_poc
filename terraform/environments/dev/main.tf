# Development Environment Configuration
# This file orchestrates the deployment of VPC, EKS, and related resources

terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.11"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    # Backend configuration will be provided during terraform init
    # terraform init -backend-config="bucket=..." -backend-config="key=..." etc.
  }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region_primary

  default_tags {
    tags = local.common_tags
  }
}

# AWS Provider for Secondary Region
provider "aws" {
  alias  = "secondary"
  region = var.aws_region_secondary

  default_tags {
    tags = local.common_tags
  }
}

# Local Values
locals {
  cluster_name_primary   = "${var.cluster_name}-${var.environment}-primary"
  cluster_name_secondary = "${var.cluster_name}-${var.environment}-secondary"
  
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "devops-team"
    CostCenter  = "infrastructure"
  }

  # Node group configurations
  node_groups_primary = {
    system = {
      instance_types             = ["t3.medium"]
      capacity_type              = "ON_DEMAND"
      disk_size                  = 30
      desired_size               = 2
      max_size                   = 4
      min_size                   = 1
      max_unavailable_percentage = 25
      tags = {
        NodeGroupType = "system"
        Purpose       = "system-workloads"
      }
    }
    
    applications = {
      instance_types             = ["t3.large", "t3.xlarge"]
      capacity_type              = "SPOT"
      disk_size                  = 50
      desired_size               = 2
      max_size                   = 6
      min_size                   = 1
      max_unavailable_percentage = 50
      tags = {
        NodeGroupType = "applications"
        Purpose       = "application-workloads"
      }
    }
  }

  node_groups_secondary = {
    system = {
      instance_types             = ["t3.medium"]
      capacity_type              = "ON_DEMAND"
      disk_size                  = 30
      desired_size               = 1
      max_size                   = 3
      min_size                   = 1
      max_unavailable_percentage = 25
      tags = {
        NodeGroupType = "system"
        Purpose       = "system-workloads"
      }
    }
  }
}

# Primary Region Resources

## VPC for Primary Region
module "vpc_primary" {
  source = "../../modules/vpc"

  name_prefix            = "${var.cluster_name}-${var.environment}-primary"
  vpc_cidr              = var.vpc_cidr_primary
  public_subnet_cidrs   = var.public_subnet_cidrs_primary
  private_subnet_cidrs  = var.private_subnet_cidrs_primary
  cluster_name          = local.cluster_name_primary
  tags                  = local.common_tags
}

## EKS Cluster for Primary Region
module "eks_primary" {
  source = "../../modules/eks"

  cluster_name                   = local.cluster_name_primary
  kubernetes_version            = var.kubernetes_version
  vpc_id                        = module.vpc_primary.vpc_id
  vpc_cidr_block                = module.vpc_primary.vpc_cidr_block
  public_subnet_ids             = module.vpc_primary.public_subnet_ids
  private_subnet_ids            = module.vpc_primary.private_subnet_ids
  endpoint_private_access       = var.endpoint_private_access
  endpoint_public_access        = var.endpoint_public_access
  public_access_cidrs           = var.public_access_cidrs
  cluster_log_retention_in_days = var.cluster_log_retention_in_days
  node_groups                   = local.node_groups_primary
  node_group_ssh_key           = var.node_group_ssh_key
  tags                         = local.common_tags

  depends_on = [module.vpc_primary]
}

# Secondary Region Resources

## VPC for Secondary Region
module "vpc_secondary" {
  source = "../../modules/vpc"
  
  providers = {
    aws = aws.secondary
  }

  name_prefix            = "${var.cluster_name}-${var.environment}-secondary"
  vpc_cidr              = var.vpc_cidr_secondary
  public_subnet_cidrs   = var.public_subnet_cidrs_secondary
  private_subnet_cidrs  = var.private_subnet_cidrs_secondary
  cluster_name          = local.cluster_name_secondary
  tags                  = local.common_tags
}

## EKS Cluster for Secondary Region
module "eks_secondary" {
  source = "../../modules/eks"
  
  providers = {
    aws = aws.secondary
  }

  cluster_name                   = local.cluster_name_secondary
  kubernetes_version            = var.kubernetes_version
  vpc_id                        = module.vpc_secondary.vpc_id
  vpc_cidr_block                = module.vpc_secondary.vpc_cidr_block
  public_subnet_ids             = module.vpc_secondary.public_subnet_ids
  private_subnet_ids            = module.vpc_secondary.private_subnet_ids
  endpoint_private_access       = var.endpoint_private_access
  endpoint_public_access        = var.endpoint_public_access
  public_access_cidrs           = var.public_access_cidrs
  cluster_log_retention_in_days = var.cluster_log_retention_in_days
  node_groups                   = local.node_groups_secondary
  node_group_ssh_key           = var.node_group_ssh_key
  tags                         = local.common_tags

  depends_on = [module.vpc_secondary]
}

# Kubernetes Provider Configuration for Primary Cluster
provider "kubernetes" {
  host                   = module.eks_primary.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_primary.cluster_ca_certificate)
  token                  = module.eks_primary.cluster_token
}

# Helm Provider Configuration for Primary Cluster
provider "helm" {
  kubernetes {
    host                   = module.eks_primary.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks_primary.cluster_ca_certificate)
    token                  = module.eks_primary.cluster_token
  }
}

# ECR Repositories
resource "aws_ecr_repository" "repositories" {
  for_each = toset(var.ecr_repositories)

  name                 = each.value
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  lifecycle_policy {
    policy = jsonencode({
      rules = [
        {
          rulePriority = 1
          description  = "Keep last 30 production images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["prod"]
            countType     = "imageCountMoreThan"
            countNumber   = 30
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 2
          description  = "Keep last 10 development images"
          selection = {
            tagStatus     = "tagged"
            tagPrefixList = ["dev", "staging"]
            countType     = "imageCountMoreThan"
            countNumber   = 10
          }
          action = {
            type = "expire"
          }
        },
        {
          rulePriority = 3
          description  = "Delete untagged images older than 1 day"
          selection = {
            tagStatus   = "untagged"
            countType   = "sinceImagePushed"
            countUnit   = "days"
            countNumber = 1
          }
          action = {
            type = "expire"
          }
        }
      ]
    })
  }

  tags = merge(local.common_tags, {
    Name = each.value
  })
}

# ECR Cross-Region Replication
resource "aws_ecr_replication_configuration" "main" {
  replication_configuration {
    rule {
      destination {
        region      = var.aws_region_secondary
        registry_id = data.aws_caller_identity.current.account_id
      }
      
      repository_filter {
        filter      = "*"
        filter_type = "PREFIX_MATCH"
      }
    }
  }
}

# Data source for current AWS account
data "aws_caller_identity" "current" {} 