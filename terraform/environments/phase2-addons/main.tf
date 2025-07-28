# Phase 2: EKS Add-ons and Platform Services
# This configuration deploys add-ons on top of the existing EKS infrastructure

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
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "~> 1.14"
    }
  }

  backend "s3" {
    # Backend configuration will be provided during terraform init
    # terraform init -backend-config="bucket=..." -backend-config="key=addons/terraform.tfstate" etc.
  }
}

# Get remote state from infrastructure deployment
data "terraform_remote_state" "infrastructure" {
  backend = "s3"
  config = {
    bucket = var.backend_bucket
    key    = "${var.environment}/terraform.tfstate"
    region = var.aws_region_primary
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
  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Owner       = "devops-team"
    Phase       = "addons"
  }

  # Extract infrastructure outputs
  primary_cluster_name     = data.terraform_remote_state.infrastructure.outputs.primary_cluster_info.cluster_name
  primary_cluster_endpoint = data.terraform_remote_state.infrastructure.outputs.primary_cluster_info.cluster_endpoint
  primary_oidc_issuer_url  = data.terraform_remote_state.infrastructure.outputs.primary_cluster_info.oidc_issuer_url
  primary_oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arns.primary
  
  secondary_cluster_name     = data.terraform_remote_state.infrastructure.outputs.secondary_cluster_info.cluster_name
  secondary_cluster_endpoint = data.terraform_remote_state.infrastructure.outputs.secondary_cluster_info.cluster_endpoint
  secondary_oidc_issuer_url  = data.terraform_remote_state.infrastructure.outputs.secondary_cluster_info.oidc_issuer_url
  secondary_oidc_provider_arn = data.terraform_remote_state.infrastructure.outputs.oidc_provider_arns.secondary
}

# Data sources for EKS clusters
data "aws_eks_cluster" "primary" {
  name = local.primary_cluster_name
}

data "aws_eks_cluster_auth" "primary" {
  name = local.primary_cluster_name
}

data "aws_eks_cluster" "secondary" {
  provider = aws.secondary
  name     = local.secondary_cluster_name
}

data "aws_eks_cluster_auth" "secondary" {
  provider = aws.secondary
  name     = local.secondary_cluster_name
}

# Kubernetes Provider for Primary Cluster
provider "kubernetes" {
  alias                  = "primary"
  host                   = data.aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.primary.token
}

# Helm Provider for Primary Cluster
provider "helm" {
  alias = "primary"
  kubernetes {
    host                   = data.aws_eks_cluster.primary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.primary.token
  }
}

# kubectl Provider for Primary Cluster
provider "kubectl" {
  alias                  = "primary"
  host                   = data.aws_eks_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.primary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.primary.token
  load_config_file       = false
}

# Kubernetes Provider for Secondary Cluster
provider "kubernetes" {
  alias                  = "secondary"
  host                   = data.aws_eks_cluster.secondary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.secondary.token
}

# Helm Provider for Secondary Cluster
provider "helm" {
  alias = "secondary"
  kubernetes {
    host                   = data.aws_eks_cluster.secondary.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
    token                  = data.aws_eks_cluster_auth.secondary.token
  }
}

# kubectl Provider for Secondary Cluster
provider "kubectl" {
  alias                  = "secondary"
  host                   = data.aws_eks_cluster.secondary.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.secondary.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.secondary.token
  load_config_file       = false
}

# Primary Cluster Add-ons
module "primary_addons" {
  source = "../../modules/eks-addons"

  providers = {
    aws        = aws
    kubernetes = kubernetes.primary
    helm       = helm.primary
    kubectl    = kubectl.primary
  }

  cluster_name          = local.primary_cluster_name
  cluster_endpoint      = local.primary_cluster_endpoint
  oidc_issuer_url       = local.primary_oidc_issuer_url
  oidc_provider_arn     = local.primary_oidc_provider_arn
  aws_region            = var.aws_region_primary
  vpc_id                = data.terraform_remote_state.infrastructure.outputs.primary_vpc_info.vpc_id
  private_subnet_ids    = data.terraform_remote_state.infrastructure.outputs.primary_vpc_info.private_subnet_ids
  
  # Add-on configurations
  enable_ebs_csi_driver     = var.enable_ebs_csi_driver
  enable_nginx_ingress      = var.enable_nginx_ingress
  enable_crossplane         = var.enable_crossplane
  enable_argocd            = var.enable_argocd
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  
  # ArgoCD specific configuration
  argocd_admin_password = var.argocd_admin_password
  argocd_repositories   = var.argocd_repositories
  
  tags = local.common_tags
}

# Secondary Cluster Add-ons (minimal set)
module "secondary_addons" {
  source = "../../modules/eks-addons"

  providers = {
    aws        = aws.secondary
    kubernetes = kubernetes.secondary
    helm       = helm.secondary
    kubectl    = kubectl.secondary
  }

  cluster_name          = local.secondary_cluster_name
  cluster_endpoint      = local.secondary_cluster_endpoint
  oidc_issuer_url       = local.secondary_oidc_issuer_url
  oidc_provider_arn     = local.secondary_oidc_provider_arn
  aws_region            = var.aws_region_secondary
  vpc_id                = data.terraform_remote_state.infrastructure.outputs.secondary_vpc_info.vpc_id
  private_subnet_ids    = data.terraform_remote_state.infrastructure.outputs.secondary_vpc_info.private_subnet_ids
  
  # Minimal add-ons for secondary cluster
  enable_ebs_csi_driver     = true
  enable_nginx_ingress      = true
  enable_crossplane         = false  # Only in primary for this PoC
  enable_argocd            = true    # For multi-cluster management
  enable_cluster_autoscaler = var.enable_cluster_autoscaler
  
  # ArgoCD specific configuration
  argocd_admin_password = var.argocd_admin_password
  argocd_repositories   = var.argocd_repositories
  
  tags = local.common_tags
} 