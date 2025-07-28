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

# Add-ons and Services Outputs
output "platform_services" {
  description = "Platform services deployment information"
  value = {
    ebs_csi_driver = {
      addon_name    = aws_eks_addon.ebs_csi_driver.addon_name
      addon_version = aws_eks_addon.ebs_csi_driver.addon_version
      status        = aws_eks_addon.ebs_csi_driver.status
      iam_role_arn  = aws_iam_role.ebs_csi_driver.arn
    }
    
    nginx_ingress = {
      namespace        = helm_release.nginx_ingress.namespace
      chart_version    = helm_release.nginx_ingress.version
      load_balancer_info = "Run: kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller"
    }
    
    argocd = {
      namespace      = helm_release.argocd.namespace
      chart_version  = helm_release.argocd.version
      admin_password_cmd = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
      ui_access_cmd     = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
      load_balancer_info = "Run: kubectl get svc -n argocd argocd-server"
    }
    
    crossplane = {
      namespace     = helm_release.crossplane.namespace
      chart_version = helm_release.crossplane.version
      provider_status_cmd = "kubectl get providers -n crossplane-system"
      iam_role_arn = aws_iam_role.crossplane_aws_provider.arn
    }
    
    cluster_autoscaler = {
      namespace     = helm_release.cluster_autoscaler.namespace
      chart_version = helm_release.cluster_autoscaler.version
      status_cmd    = "kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler"
      iam_role_arn  = aws_iam_role.cluster_autoscaler.arn
    }
  }
}

# Access Commands
output "service_access_commands" {
  description = "Commands to access deployed services"
  value = {
    nginx_ingress_lb = "kubectl get svc -n ingress-nginx nginx-ingress-ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    argocd_ui        = {
      port_forward    = "kubectl port-forward svc/argocd-server -n argocd 8080:443"
      admin_password  = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
      external_access = "kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'"
    }
    crossplane_status = {
      providers = "kubectl get providers -n crossplane-system"
      compositions = "kubectl get compositions"
      claims = "kubectl get claims -A"
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

# SSH Key Pair Information
output "ssh_key_pairs" {
  description = "Information about SSH key pairs created for EKS nodes"
  value = var.ssh_public_key != null ? {
    primary_key_name   = aws_key_pair.node_group_key_primary[0].key_name
    secondary_key_name = aws_key_pair.node_group_key_secondary[0].key_name
    primary_region     = var.aws_region_primary
    secondary_region   = var.aws_region_secondary
  } : null
}

# Phase 2 Completion Information
output "phase2_completion_info" {
  description = "Phase 2 completion status and next steps"
  value = <<-EOT
    
    🎉 Phase 2: Core Add-ons & Platform Services - COMPLETED!
    
    ✅ Deployed Services:
    - EBS CSI Driver: Ready for persistent storage
    - NGINX Ingress Controller: External access configured
    - ArgoCD: GitOps platform ready
    - Crossplane: Infrastructure provisioning ready
    - Cluster Autoscaler: Auto-scaling enabled
    
    🔍 Service Status Commands:
    - Check all pods: kubectl get pods -A
    - Check ingress: kubectl get svc -n ingress-nginx
    - Check ArgoCD: kubectl get pods -n argocd
    - Check Crossplane: kubectl get providers -n crossplane-system
    
    🌐 Access ArgoCD UI:
    1. Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
    2. Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443
    3. Browse to: http://localhost:8080 (username: admin)
    
    📋 Ready for Phase 3: Security & Policy Implementation
    - Deploy Kyverno for policy enforcement
    - Implement security policies as code
    - Setup RBAC and access controls
    
    📋 Ready for Phase 4: Storage Provisioning
    - Create Crossplane compositions for EBS and RDS
    - Test automated storage provisioning
    
    📋 Ready for Phase 5: Application Deployment  
    - Deploy Jenkins LTS with persistent storage
    - Deploy SonarQube with RDS backend
    - Implement CI/CD pipelines
    
  EOT
} 