# Variables for EKS Add-ons Module

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
}

variable "cluster_endpoint" {
  description = "EKS cluster endpoint"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL for the EKS cluster"
  type        = string
}

variable "oidc_provider_arn" {
  description = "ARN of the OIDC provider for IRSA"
  type        = string
}

variable "aws_region" {
  description = "AWS region where the cluster is deployed"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the cluster is deployed"
  type        = string
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
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

# EBS CSI Driver Configuration
variable "ebs_csi_driver_version" {
  description = "Version of the EBS CSI driver to install"
  type        = string
  default     = "2.35.0"
}

# NGINX Ingress Configuration
variable "nginx_ingress_version" {
  description = "Version of NGINX Ingress Controller to install"
  type        = string
  default     = "4.7.1"
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
  default     = "1.14.5"
}

variable "crossplane_aws_provider_version" {
  description = "Version of Crossplane AWS Provider to install"
  type        = string
  default     = "v0.47.0"
}

# ArgoCD Configuration
variable "argocd_version" {
  description = "Version of ArgoCD to install"
  type        = string
  default     = "5.46.8"
}

variable "argocd_admin_password" {
  description = "Admin password for ArgoCD (leave empty for auto-generated)"
  type        = string
  default     = ""
  sensitive   = true
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

variable "argocd_repositories" {
  description = "List of Git repositories for ArgoCD to monitor"
  type = list(object({
    url  = string
    name = string
    type = string
  }))
  default = []
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