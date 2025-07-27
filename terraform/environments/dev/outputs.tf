# Outputs for Development Environment

# Primary Region Outputs
output "primary_cluster_info" {
  description = "Primary EKS cluster information"
  value = {
    cluster_id       = module.eks_primary.cluster_id
    cluster_name     = module.eks_primary.cluster_name
    cluster_endpoint = module.eks_primary.cluster_endpoint
    cluster_version  = module.eks_primary.cluster_version
    oidc_issuer_url  = module.eks_primary.cluster_oidc_issuer_url
    region          = var.aws_region_primary
  }
}

output "primary_vpc_info" {
  description = "Primary VPC information"
  value = {
    vpc_id              = module.vpc_primary.vpc_id
    vpc_cidr           = module.vpc_primary.vpc_cidr_block
    public_subnet_ids  = module.vpc_primary.public_subnet_ids
    private_subnet_ids = module.vpc_primary.private_subnet_ids
    region            = var.aws_region_primary
  }
}

# Secondary Region Outputs
output "secondary_cluster_info" {
  description = "Secondary EKS cluster information"
  value = {
    cluster_id       = module.eks_secondary.cluster_id
    cluster_name     = module.eks_secondary.cluster_name
    cluster_endpoint = module.eks_secondary.cluster_endpoint
    cluster_version  = module.eks_secondary.cluster_version
    oidc_issuer_url  = module.eks_secondary.cluster_oidc_issuer_url
    region          = var.aws_region_secondary
  }
}

output "secondary_vpc_info" {
  description = "Secondary VPC information"
  value = {
    vpc_id              = module.vpc_secondary.vpc_id
    vpc_cidr           = module.vpc_secondary.vpc_cidr_block
    public_subnet_ids  = module.vpc_secondary.public_subnet_ids
    private_subnet_ids = module.vpc_secondary.private_subnet_ids
    region            = var.aws_region_secondary
  }
}

# ECR Outputs
output "ecr_repositories" {
  description = "ECR repository information"
  value = {
    for repo_name, repo in aws_ecr_repository.repositories : repo_name => {
      repository_url = repo.repository_url
      registry_id    = repo.registry_id
      arn           = repo.arn
    }
  }
}

# kubectl Configuration Commands
output "kubectl_config_commands" {
  description = "Commands to configure kubectl for both clusters"
  value = {
    primary = "aws eks update-kubeconfig --region ${var.aws_region_primary} --name ${module.eks_primary.cluster_name}"
    secondary = "aws eks update-kubeconfig --region ${var.aws_region_secondary} --name ${module.eks_secondary.cluster_name}"
  }
}

# Security Information
output "cluster_security_groups" {
  description = "Security group information for clusters"
  value = {
    primary = {
      cluster_sg = module.eks_primary.cluster_security_group_id
      node_sg    = module.eks_primary.node_security_group_id
    }
    secondary = {
      cluster_sg = module.eks_secondary.cluster_security_group_id
      node_sg    = module.eks_secondary.node_security_group_id
    }
  }
}

# IRSA Information
output "oidc_provider_arns" {
  description = "OIDC provider ARNs for IRSA configuration"
  value = {
    primary   = module.eks_primary.oidc_provider_arn
    secondary = module.eks_secondary.oidc_provider_arn
  }
}

# Node Group Information
output "node_groups_info" {
  description = "Node group information"
  value = {
    primary   = module.eks_primary.node_groups
    secondary = module.eks_secondary.node_groups
  }
}

# Quick Start Information
output "next_steps" {
  description = "Next steps after infrastructure deployment"
  value = <<-EOT
    
    🎉 Infrastructure deployed successfully!
    
    Next steps:
    
    1. Configure kubectl for primary cluster:
       ${module.eks_primary.cluster_name}
       Command: aws eks update-kubeconfig --region ${var.aws_region_primary} --name ${module.eks_primary.cluster_name}
    
    2. Configure kubectl for secondary cluster:
       ${module.eks_secondary.cluster_name}  
       Command: aws eks update-kubeconfig --region ${var.aws_region_secondary} --name ${module.eks_secondary.cluster_name}
    
    3. Verify cluster connectivity:
       kubectl get nodes
       kubectl get pods -A
    
    4. Proceed with Phase 2: Deploy EKS add-ons (EBS CSI, NGINX Ingress, Crossplane)
    
    5. Setup ArgoCD and GitOps workflow
    
    6. Deploy applications (Jenkins, SonarQube, Kyverno)
    
    ECR Repositories created: ${join(", ", var.ecr_repositories)}
    
    Primary Cluster: ${module.eks_primary.cluster_endpoint}
    Secondary Cluster: ${module.eks_secondary.cluster_endpoint}
    
  EOT
} 