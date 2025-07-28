# Outputs for EKS Add-ons Module

# ArgoCD Information
output "argocd_server_url" {
  description = "ArgoCD server URL"
  value = var.enable_argocd ? (
    var.argocd_server_ingress_enabled ? 
    "https://${var.argocd_server_ingress_hostname}" : 
    "http://argocd-server.argocd.svc.cluster.local"
  ) : null
}

output "argocd_namespace" {
  description = "ArgoCD namespace"
  value = var.enable_argocd ? "argocd" : null
}

# NGINX Ingress Information
output "nginx_load_balancer_hostname" {
  description = "NGINX Ingress load balancer hostname"
  value = var.enable_nginx_ingress ? (
    try(helm_release.nginx_ingress[0].status[0].load_balancer[0].ingress[0].hostname, "pending")
  ) : null
}

output "nginx_ingress_class" {
  description = "NGINX Ingress class name"
  value = var.enable_nginx_ingress ? "nginx" : null
}

output "nginx_namespace" {
  description = "NGINX Ingress namespace"
  value = var.enable_nginx_ingress ? "ingress-nginx" : null
}

# EBS CSI Driver Information
output "ebs_csi_driver_version" {
  description = "EBS CSI Driver version installed"
  value = var.enable_ebs_csi_driver ? var.ebs_csi_driver_version : null
}

output "default_storage_class" {
  description = "Default storage class created by EBS CSI driver"
  value = var.enable_ebs_csi_driver ? "gp3" : null
}

# Crossplane Information
output "crossplane_namespace" {
  description = "Crossplane namespace"
  value = var.enable_crossplane ? "crossplane-system" : null
}

output "crossplane_aws_provider_version" {
  description = "Crossplane AWS Provider version installed"
  value = var.enable_crossplane ? var.crossplane_aws_provider_version : null
}

output "crossplane_compositions_ready" {
  description = "Indicates if Crossplane compositions are ready"
  value = var.enable_crossplane ? true : false
}

# Cluster Autoscaler Information
output "cluster_autoscaler_version" {
  description = "Cluster Autoscaler version installed"
  value = var.enable_cluster_autoscaler ? var.cluster_autoscaler_version : null
}

output "cluster_autoscaler_namespace" {
  description = "Cluster Autoscaler namespace"
  value = var.enable_cluster_autoscaler ? "kube-system" : null
}

# IRSA Roles Information
output "irsa_roles" {
  description = "IAM Roles for Service Accounts created"
  value = {
    ebs_csi_driver = var.enable_ebs_csi_driver ? {
      role_arn = aws_iam_role.ebs_csi_driver[0].arn
      role_name = aws_iam_role.ebs_csi_driver[0].name
      service_account = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
    } : null
    
    crossplane = var.enable_crossplane ? {
      role_arn = aws_iam_role.crossplane[0].arn
      role_name = aws_iam_role.crossplane[0].name
      service_account = "system:serviceaccount:crossplane-system:crossplane"
    } : null
    
    cluster_autoscaler = var.enable_cluster_autoscaler ? {
      role_arn = aws_iam_role.cluster_autoscaler[0].arn
      role_name = aws_iam_role.cluster_autoscaler[0].name
      service_account = "system:serviceaccount:kube-system:cluster-autoscaler"
    } : null
  }
}

# Add-on Status Summary
output "addons_deployed" {
  description = "Summary of deployed add-ons"
  value = {
    ebs_csi_driver = var.enable_ebs_csi_driver
    nginx_ingress = var.enable_nginx_ingress
    crossplane = var.enable_crossplane
    argocd = var.enable_argocd
    cluster_autoscaler = var.enable_cluster_autoscaler
  }
}

# Helm Release Status
output "helm_releases" {
  description = "Status of Helm releases"
  value = {
    ebs_csi_driver = var.enable_ebs_csi_driver ? {
      name = helm_release.ebs_csi_driver[0].name
      namespace = helm_release.ebs_csi_driver[0].namespace
      version = helm_release.ebs_csi_driver[0].version
      status = helm_release.ebs_csi_driver[0].status
    } : null
    
    nginx_ingress = var.enable_nginx_ingress ? {
      name = helm_release.nginx_ingress[0].name
      namespace = helm_release.nginx_ingress[0].namespace
      version = helm_release.nginx_ingress[0].version
      status = helm_release.nginx_ingress[0].status
    } : null
    
    crossplane = var.enable_crossplane ? {
      name = helm_release.crossplane[0].name
      namespace = helm_release.crossplane[0].namespace
      version = helm_release.crossplane[0].version
      status = helm_release.crossplane[0].status
    } : null
    
    argocd = var.enable_argocd ? {
      name = helm_release.argocd[0].name
      namespace = helm_release.argocd[0].namespace
      version = helm_release.argocd[0].version
      status = helm_release.argocd[0].status
    } : null
    
    cluster_autoscaler = var.enable_cluster_autoscaler ? {
      name = helm_release.cluster_autoscaler[0].name
      namespace = helm_release.cluster_autoscaler[0].namespace
      version = helm_release.cluster_autoscaler[0].version
      status = helm_release.cluster_autoscaler[0].status
    } : null
  }
}

# Quick Access Commands
output "access_commands" {
  description = "Quick access commands for deployed services"
  value = {
    argocd_port_forward = var.enable_argocd ? "kubectl port-forward svc/argocd-server -n argocd 8080:443" : null
    argocd_get_password = var.enable_argocd ? "kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d" : null
    nginx_get_lb = var.enable_nginx_ingress ? "kubectl get svc ingress-nginx-controller -n ingress-nginx" : null
    crossplane_providers = var.enable_crossplane ? "kubectl get providers -n crossplane-system" : null
    ebs_storage_classes = var.enable_ebs_csi_driver ? "kubectl get storageclass" : null
  }
} 