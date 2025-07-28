# Variables for EKS Add-ons Environment (Phase 2)

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

# Backend Configuration
variable "backend_bucket" {
  description = "S3 bucket name for Terraform backend (from Phase 1 output)"
  type        = string
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

# Add-on Enable/Disable Flags
variable "enable_ebs_csi_driver" {
  description = "Enable EBS CSI Driver add-on"
  type        = bool
  default     = true
}

variable "enable_nginx_ingress" {
  description = "Enable NGINX Ingress Controller"
  type        = bool
  default     = true
}

variable "enable_crossplane" {
  description = "Enable Crossplane for infrastructure provisioning"
  type        = bool
  default     = true
}

variable "enable_argocd" {
  description = "Enable ArgoCD for GitOps"
  type        = bool
  default     = true
}

variable "enable_cluster_autoscaler" {
  description = "Enable Cluster Autoscaler"
  type        = bool
  default     = true
}

# ArgoCD Configuration
variable "argocd_admin_password" {
  description = "Admin password for ArgoCD (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
}

variable "argocd_repositories" {
  description = "List of Git repositories for ArgoCD to monitor"
  type = list(object({
    url  = string
    name = string
    type = string
  }))
  default = [
    {
      url  = "https://github.com/your-org/k8s-manifests.git"
      name = "k8s-manifests"
      type = "git"
    }
  ]
}

# EBS CSI Driver Configuration
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver to install"
  type        = string
  default     = "v1.24.0"
}

# NGINX Ingress Configuration
variable "nginx_ingress_version" {
  description = "Version of NGINX Ingress Controller to install"
  type        = string
  default     = "4.8.3"
}

variable "nginx_ingress_load_balancer_type" {
  description = "Type of load balancer for NGINX Ingress (nlb or elb)"
  type        = string
  default     = "nlb"
  validation {
    condition     = contains(["nlb", "elb"], var.nginx_ingress_load_balancer_type)
    error_message = "Load balancer type must be either 'nlb' or 'elb'."
  }
}

# Crossplane Configuration
variable "crossplane_version" {
  description = "Version of Crossplane to install"
  type        = string
  default     = "1.14.3"
}

variable "crossplane_aws_provider_version" {
  description = "Version of Crossplane AWS Provider to install"
  type        = string
  default     = "v0.44.0"
}

# ArgoCD Configuration
variable "argocd_version" {
  description = "Version of ArgoCD to install"
  type        = string
  default     = "5.46.8"
}

variable "argocd_server_ingress_enabled" {
  description = "Enable ingress for ArgoCD server"
  type        = bool
  default     = true
}

variable "argocd_server_ingress_hostname" {
  description = "Hostname for ArgoCD server ingress"
  type        = string
  default     = "argocd.local"
}

# Cluster Autoscaler Configuration
variable "cluster_autoscaler_version" {
  description = "Version of Cluster Autoscaler to install"
  type        = string
  default     = "9.29.0"
}

variable "cluster_autoscaler_image_tag" {
  description = "Image tag for Cluster Autoscaler (should match Kubernetes version)"
  type        = string
  default     = "v1.28.2"
}

# DNS Configuration
variable "dns_zone_name" {
  description = "Route53 hosted zone name for ingress DNS records"
  type        = string
  default     = ""
}

# SSL/TLS Configuration
variable "enable_cert_manager" {
  description = "Enable cert-manager for automatic SSL certificate management"
  type        = bool
  default     = false
}

variable "cert_manager_version" {
  description = "Version of cert-manager to install"
  type        = string
  default     = "v1.13.2"
}

variable "cert_manager_acme_email" {
  description = "Email address for ACME certificate requests"
  type        = string
  default     = ""
} 