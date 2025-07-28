# Outputs for EKS Add-ons Environment (Phase 2)

# Primary Cluster Add-ons Information
output "primary_addons_info" {
  description = "Information about add-ons deployed on primary cluster"
  value = {
    cluster_name      = local.primary_cluster_name
    cluster_endpoint  = local.primary_cluster_endpoint
    region           = var.aws_region_primary
    ebs_csi_enabled  = var.enable_ebs_csi_driver
    nginx_enabled    = var.enable_nginx_ingress
    crossplane_enabled = var.enable_crossplane
    argocd_enabled   = var.enable_argocd
    autoscaler_enabled = var.enable_cluster_autoscaler
  }
}

# Secondary Cluster Add-ons Information
output "secondary_addons_info" {
  description = "Information about add-ons deployed on secondary cluster"
  value = {
    cluster_name      = local.secondary_cluster_name
    cluster_endpoint  = local.secondary_cluster_endpoint
    region           = var.aws_region_secondary
    ebs_csi_enabled  = true
    nginx_enabled    = true
    crossplane_enabled = false
    argocd_enabled   = true
    autoscaler_enabled = var.enable_cluster_autoscaler
  }
}

# ArgoCD Access Information
output "argocd_access" {
  description = "ArgoCD access information"
  value = var.enable_argocd ? {
    primary_server_url = module.primary_addons.argocd_server_url
    secondary_server_url = module.secondary_addons.argocd_server_url
    admin_username = "admin"
    ingress_enabled = var.argocd_server_ingress_enabled
    ingress_hostname = var.argocd_server_ingress_hostname
    initial_password_command = "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
  } : null
}

# NGINX Ingress Information
output "nginx_ingress_info" {
  description = "NGINX Ingress Controller information"
  value = var.enable_nginx_ingress ? {
    primary_load_balancer_hostname = module.primary_addons.nginx_load_balancer_hostname
    secondary_load_balancer_hostname = module.secondary_addons.nginx_load_balancer_hostname
    load_balancer_type = var.nginx_ingress_load_balancer_type
    ingress_class = "nginx"
  } : null
}

# Crossplane Information
output "crossplane_info" {
  description = "Crossplane configuration information"
  value = var.enable_crossplane ? {
    namespace = "crossplane-system"
    aws_provider_version = var.crossplane_aws_provider_version
    installed_on = "primary-cluster-only"
    compositions_ready = module.primary_addons.crossplane_compositions_ready
  } : null
}

# EBS CSI Driver Information
output "ebs_csi_info" {
  description = "EBS CSI Driver information"
  value = var.enable_ebs_csi_driver ? {
    version = var.ebs_csi_driver_version
    storage_classes = ["gp2", "gp3", "io1", "io2"]
    default_storage_class = "gp3"
  } : null
}

# Cluster Autoscaler Information
output "cluster_autoscaler_info" {
  description = "Cluster Autoscaler information"
  value = var.enable_cluster_autoscaler ? {
    version = var.cluster_autoscaler_version
    image_tag = var.cluster_autoscaler_image_tag
    deployed_regions = [var.aws_region_primary, var.aws_region_secondary]
  } : null
}

# Access Commands
output "access_commands" {
  description = "Commands to access deployed services"
  value = {
    kubectl_primary = "aws eks update-kubeconfig --region ${var.aws_region_primary} --name ${local.primary_cluster_name}"
    kubectl_secondary = "aws eks update-kubeconfig --region ${var.aws_region_secondary} --name ${local.secondary_cluster_name}"
    
    argocd_port_forward = var.enable_argocd ? "kubectl port-forward svc/argocd-server -n argocd 8080:443" : "ArgoCD not enabled"
    argocd_get_password = var.enable_argocd ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : "ArgoCD not enabled"
    
    view_ingress_services = var.enable_nginx_ingress ? "kubectl get svc -n ingress-nginx" : "NGINX Ingress not enabled"
    view_crossplane_providers = var.enable_crossplane ? "kubectl get providers -n crossplane-system" : "Crossplane not enabled"
  }
}

# Health Check Commands
output "health_check_commands" {
  description = "Commands to check the health of deployed add-ons"
  value = {
    check_all_pods = "kubectl get pods -A"
    check_node_status = "kubectl get nodes"
    
    ebs_csi_status = var.enable_ebs_csi_driver ? "kubectl get pods -n kube-system -l app=ebs-csi-controller" : "EBS CSI not enabled"
    nginx_status = var.enable_nginx_ingress ? "kubectl get pods -n ingress-nginx" : "NGINX Ingress not enabled"
    argocd_status = var.enable_argocd ? "kubectl get pods -n argocd" : "ArgoCD not enabled"
    crossplane_status = var.enable_crossplane ? "kubectl get pods -n crossplane-system" : "Crossplane not enabled"
    autoscaler_status = var.enable_cluster_autoscaler ? "kubectl get pods -n kube-system -l app=cluster-autoscaler" : "Cluster Autoscaler not enabled"
  }
}

# Next Steps Information
output "next_steps" {
  description = "Next steps after add-ons deployment"
  value = <<-EOT
    
    🎉 Phase 2: EKS Add-ons deployment completed!
    
    Add-ons deployed:
    ${var.enable_ebs_csi_driver ? "✅ EBS CSI Driver" : "❌ EBS CSI Driver"}
    ${var.enable_nginx_ingress ? "✅ NGINX Ingress Controller" : "❌ NGINX Ingress Controller"}
    ${var.enable_crossplane ? "✅ Crossplane (Primary cluster)" : "❌ Crossplane"}
    ${var.enable_argocd ? "✅ ArgoCD (Both clusters)" : "❌ ArgoCD"}
    ${var.enable_cluster_autoscaler ? "✅ Cluster Autoscaler" : "❌ Cluster Autoscaler"}
    
    Access Information:
    ${var.enable_argocd ? "- ArgoCD UI: kubectl port-forward svc/argocd-server -n argocd 8080:443" : ""}
    ${var.enable_argocd ? "- ArgoCD Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : ""}
    ${var.enable_nginx_ingress ? "- NGINX Ingress: kubectl get svc -n ingress-nginx" : ""}
    
    Next Steps (Phase 3):
    1. Deploy Kyverno security policies
    2. Setup Crossplane compositions for EBS and RDS
    3. Configure ArgoCD applications and repositories
    4. Deploy Jenkins and SonarQube via GitOps
    
    Health Check:
    kubectl get pods -A
    kubectl get nodes
    
  EOT
}

# IRSA Roles Created
output "irsa_roles" {
  description = "IAM Roles for Service Accounts created for add-ons"
  value = {
    primary_cluster = module.primary_addons.irsa_roles
    secondary_cluster = module.secondary_addons.irsa_roles
  }
}

# Storage Classes Information
output "storage_classes" {
  description = "Storage classes available after EBS CSI driver installation"
  value = var.enable_ebs_csi_driver ? {
    default_class = "gp3"
    available_classes = [
      {
        name = "gp2"
        provisioner = "ebs.csi.aws.com"
        type = "gp2"
      },
      {
        name = "gp3"
        provisioner = "ebs.csi.aws.com"
        type = "gp3"
      },
      {
        name = "io1"
        provisioner = "ebs.csi.aws.com"
        type = "io1"
      },
      {
        name = "io2"
        provisioner = "ebs.csi.aws.com"
        type = "io2"
      }
    ]
  } : null
} 