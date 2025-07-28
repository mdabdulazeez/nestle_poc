# EKS Add-ons Module
# This module deploys various add-ons and platform services on EKS clusters

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
}

# Data sources
data "aws_caller_identity" "current" {}

# Local values
locals {
  cluster_name_clean = replace(var.cluster_name, "-", "")
}

# EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  
  name = "${var.cluster_name}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0
  
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver[0].name
}

resource "helm_release" "ebs_csi_driver" {
  count = var.enable_ebs_csi_driver ? 1 : 0

  name       = "aws-ebs-csi-driver"
  repository = "https://kubernetes-sigs.github.io/aws-ebs-csi-driver"
  chart      = "aws-ebs-csi-driver"
  namespace  = "kube-system"
  version    = var.ebs_csi_driver_version

  set {
    name  = "controller.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.ebs_csi_driver[0].arn
  }

  set {
    name  = "controller.serviceAccount.name"
    value = "ebs-csi-controller-sa"
  }

  set {
    name  = "storageClasses[0].name"
    value = "gp3"
  }

  set {
    name  = "storageClasses[0].parameters.type"
    value = "gp3"
  }

  set {
    name  = "storageClasses[0].parameters.encrypted"
    value = "true"
  }

  set {
    name  = "storageClasses[0].allowVolumeExpansion"
    value = "true"
  }

  set {
    name  = "storageClasses[0].reclaimPolicy"
    value = "Delete"
  }

  set {
    name  = "storageClasses[0].annotations.storageclass\\.kubernetes\\.io/is-default-class"
    value = "true"
  }

  depends_on = [aws_iam_role_policy_attachment.ebs_csi_driver]
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  count = var.enable_nginx_ingress ? 1 : 0

  name       = "ingress-nginx"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  version    = var.nginx_ingress_version

  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
    value = var.nginx_ingress_load_balancer_type
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-backend-protocol"
    value = "tcp"
  }

  set {
    name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-cross-zone-load-balancing-enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "controller.podSecurityContext.runAsUser"
    value = "101"
  }

  set {
    name  = "controller.containerSecurityContext.allowPrivilegeEscalation"
    value = "false"
  }

  set {
    name  = "controller.containerSecurityContext.readOnlyRootFilesystem"
    value = "true"
  }

  set {
    name  = "controller.containerSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "controller.containerSecurityContext.runAsUser"
    value = "101"
  }
}

# Data source to get NGINX Ingress Service Load Balancer info
data "kubernetes_service" "nginx_ingress_controller" {
  count = var.enable_nginx_ingress ? 1 : 0
  
  metadata {
    name      = "ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  
  depends_on = [helm_release.nginx_ingress]
}

# ArgoCD
resource "kubernetes_namespace" "argocd" {
  count = var.enable_argocd ? 1 : 0

  metadata {
    name = "argocd"
    labels = {
      name = "argocd"
    }
  }
}

resource "helm_release" "argocd" {
  count = var.enable_argocd ? 1 : 0

  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  namespace  = "argocd"
  version    = var.argocd_version

  create_namespace = false

  values = [
    yamlencode({
      global = {
        securityContext = {
          runAsNonRoot = true
          runAsUser    = 999
          seccompProfile = {
            type = "RuntimeDefault"
          }
        }
      }
      
      server = {
        containerSecurityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          runAsNonRoot            = true
          runAsUser               = 999
          capabilities = {
            drop = ["ALL"]
          }
        }
        
        service = {
          type = "ClusterIP"
        }
        
        ingress = {
          enabled = var.argocd_server_ingress_enabled
          ingressClassName = var.enable_nginx_ingress ? "nginx" : ""
          hostname = var.argocd_server_ingress_hostname
          tls = true
        }
        
        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.insecure" = "true"
          "oidc.config" = ""
        }
      }
      
      controller = {
        containerSecurityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          runAsNonRoot            = true
          runAsUser               = 999
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
      
      dex = {
        containerSecurityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          runAsNonRoot            = true
          runAsUser               = 999
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
      
      repoServer = {
        containerSecurityContext = {
          allowPrivilegeEscalation = false
          readOnlyRootFilesystem   = true
          runAsNonRoot            = true
          runAsUser               = 999
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
      
      redis = {
        containerSecurityContext = {
          allowPrivilegeEscalation = false
          runAsNonRoot            = true
          runAsUser               = 999
          capabilities = {
            drop = ["ALL"]
          }
        }
      }
    })
  ]

  depends_on = [
    kubernetes_namespace.argocd,
    helm_release.nginx_ingress
  ]
}

# Crossplane
resource "aws_iam_role" "crossplane" {
  count = var.enable_crossplane ? 1 : 0
  
  name = "${var.cluster_name}-crossplane-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:crossplane-system:crossplane"
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "crossplane" {
  count = var.enable_crossplane ? 1 : 0
  
  name        = "${var.cluster_name}-crossplane-policy"
  description = "IAM policy for Crossplane to manage AWS resources"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ec2:*",
          "rds:*",
          "s3:*",
          "iam:*",
          "eks:*"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "crossplane" {
  count = var.enable_crossplane ? 1 : 0
  
  policy_arn = aws_iam_policy.crossplane[0].arn
  role       = aws_iam_role.crossplane[0].name
}

resource "helm_release" "crossplane" {
  count = var.enable_crossplane ? 1 : 0

  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  namespace  = "crossplane-system"
  version    = var.crossplane_version

  create_namespace = true

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.crossplane[0].arn
  }

  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "podSecurityContext.runAsUser"
    value = "65532"
  }

  set {
    name  = "securityContext.allowPrivilegeEscalation"
    value = "false"
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.runAsUser"
    value = "65532"
  }

  depends_on = [aws_iam_role_policy_attachment.crossplane]
}

# Crossplane AWS Provider
resource "kubectl_manifest" "crossplane_aws_provider" {
  count = var.enable_crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-aws"
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-aws:${var.crossplane_aws_provider_version}"
    }
  })

  depends_on = [helm_release.crossplane]
}

# Crossplane AWS Provider Config
resource "kubectl_manifest" "crossplane_aws_provider_config" {
  count = var.enable_crossplane ? 1 : 0

  yaml_body = yamlencode({
    apiVersion = "aws.crossplane.io/v1beta1"
    kind       = "ProviderConfig"
    metadata = {
      name = "default"
    }
    spec = {
      credentials = {
        source = "InjectedIdentity"
      }
    }
  })

  depends_on = [kubectl_manifest.crossplane_aws_provider]
}

# Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  
  name = "${var.cluster_name}-cluster-autoscaler-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Federated = var.oidc_provider_arn
        }
        Action = "sts:AssumeRoleWithWebIdentity"
        Condition = {
          StringEquals = {
            "${replace(var.oidc_issuer_url, "https://", "")}:sub" = "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(var.oidc_issuer_url, "https://", "")}:aud" = "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_policy" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  
  name        = "${var.cluster_name}-cluster-autoscaler-policy"
  description = "IAM policy for Cluster Autoscaler"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "autoscaling:DescribeAutoScalingGroups",
          "autoscaling:DescribeAutoScalingInstances",
          "autoscaling:DescribeLaunchConfigurations",
          "autoscaling:DescribeTags",
          "autoscaling:SetDesiredCapacity",
          "autoscaling:TerminateInstanceInAutoScalingGroup",
          "ec2:DescribeLaunchTemplateVersions"
        ]
        Resource = "*"
      }
    ]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0
  
  policy_arn = aws_iam_policy.cluster_autoscaler[0].arn
  role       = aws_iam_role.cluster_autoscaler[0].name
}

resource "helm_release" "cluster_autoscaler" {
  count = var.enable_cluster_autoscaler ? 1 : 0

  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  namespace  = "kube-system"
  version    = var.cluster_autoscaler_version

  set {
    name  = "autoDiscovery.clusterName"
    value = var.cluster_name
  }

  set {
    name  = "awsRegion"
    value = var.aws_region
  }

  set {
    name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
    value = aws_iam_role.cluster_autoscaler[0].arn
  }

  set {
    name  = "serviceAccount.name"
    value = "cluster-autoscaler"
  }

  set {
    name  = "image.tag"
    value = var.cluster_autoscaler_image_tag
  }

  set {
    name  = "podSecurityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "podSecurityContext.runAsUser"
    value = "65534"
  }

  set {
    name  = "securityContext.allowPrivilegeEscalation"
    value = "false"
  }

  set {
    name  = "securityContext.readOnlyRootFilesystem"
    value = "true"
  }

  set {
    name  = "securityContext.runAsNonRoot"
    value = "true"
  }

  set {
    name  = "securityContext.runAsUser"
    value = "65534"
  }

  depends_on = [aws_iam_role_policy_attachment.cluster_autoscaler]
} 