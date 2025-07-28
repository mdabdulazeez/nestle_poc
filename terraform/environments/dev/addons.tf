# Kubernetes Add-ons for EKS Cluster
# This file manages the deployment of essential EKS add-ons and platform services

# EBS CSI Driver Add-on (AWS managed)
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name             = module.eks_primary.cluster_name
  addon_name               = "aws-ebs-csi-driver"
  addon_version            = "v1.24.1-eksbuild.1"  # Latest as of 2024
  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn
  resolve_conflicts        = "OVERWRITE"

  tags = merge(local.common_tags, {
    Name = "ebs-csi-driver"
  })

  depends_on = [
    module.eks_primary,
    aws_iam_role_policy_attachment.ebs_csi_driver_policy
  ]
}

# IAM Role for EBS CSI Driver
resource "aws_iam_role" "ebs_csi_driver" {
  name = "${local.cluster_name_primary}-ebs-csi-driver-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks_primary.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:kube-system:ebs-csi-controller-sa"
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
  role       = aws_iam_role.ebs_csi_driver.name
}

# NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  version    = "4.8.3"  # Latest stable version
  namespace  = "ingress-nginx"
  create_namespace = true

  values = [
    yamlencode({
      controller = {
        replicaCount = 2
        
        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
            "service.beta.kubernetes.io/aws-load-balancer-backend-protocol" = "tcp"
          }
        }

        resources = {
          limits = {
            cpu    = "500m"
            memory = "512Mi"
          }
          requests = {
            cpu    = "250m"
            memory = "256Mi"
          }
        }

        nodeSelector = {
          "node.kubernetes.io/instance-type" = "t3.medium"
        }

        tolerations = []

        affinity = {
          podAntiAffinity = {
            preferredDuringSchedulingIgnoredDuringExecution = [
              {
                weight = 100
                podAffinityTerm = {
                  labelSelector = {
                    matchExpressions = [
                      {
                        key      = "app.kubernetes.io/name"
                        operator = "In"
                        values   = ["ingress-nginx"]
                      }
                    ]
                  }
                  topologyKey = "kubernetes.io/hostname"
                }
              }
            ]
          }
        }

        metrics = {
          enabled = true
          serviceMonitor = {
            enabled = false  # Will enable when Prometheus is deployed
          }
        }
      }

      defaultBackend = {
        enabled = true
        replicaCount = 2
        resources = {
          limits = {
            cpu    = "100m"
            memory = "128Mi"
          }
          requests = {
            cpu    = "50m"
            memory = "64Mi"
          }
        }
      }
    })
  ]

  depends_on = [module.eks_primary]
}

# ArgoCD Installation
resource "helm_release" "argocd" {
  name       = "argocd"
  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = "5.51.6"  # Latest stable version
  namespace  = "argocd"
  create_namespace = true

  values = [
    yamlencode({
      global = {
        domain = "argocd.local"  # Will be updated with actual domain later
      }

      server = {
        replicas = 2
        
        resources = {
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }

        service = {
          type = "LoadBalancer"
          annotations = {
            "service.beta.kubernetes.io/aws-load-balancer-type" = "nlb"
            "service.beta.kubernetes.io/aws-load-balancer-cross-zone-load-balancing-enabled" = "true"
          }
        }

        config = {
          "application.instanceLabelKey" = "argocd.argoproj.io/instance"
          "server.insecure" = true  # For initial setup, will secure later
          "users.anonymous.enabled" = false
          
          # RBAC configuration
          "policy.default" = "role:readonly"
          "policy.csv" = <<-EOT
            p, role:admin, applications, *, */*, allow
            p, role:admin, clusters, *, *, allow
            p, role:admin, repositories, *, *, allow
            p, role:admin, certificates, *, *, allow
            p, role:admin, projects, *, *, allow
            p, role:admin, accounts, *, *, allow
            g, argocd-admins, role:admin
          EOT
        }

        nodeSelector = {
          "node.kubernetes.io/instance-type" = "t3.medium"
        }

        tolerations = []
      }

      controller = {
        replicas = 2
        
        resources = {
          limits = {
            cpu    = "1000m"
            memory = "2Gi"
          }
          requests = {
            cpu    = "500m"
            memory = "1Gi"
          }
        }

        nodeSelector = {
          "node.kubernetes.io/instance-type" = "t3.medium"
        }

        tolerations = []
      }

      repoServer = {
        replicas = 2
        
        resources = {
          limits = {
            cpu    = "500m"
            memory = "1Gi"
          }
          requests = {
            cpu    = "250m"
            memory = "512Mi"
          }
        }

        nodeSelector = {
          "node.kubernetes.io/instance-type" = "t3.medium"
        }

        tolerations = []
      }

      applicationSet = {
        enabled = true
        replicas = 2
      }

      notifications = {
        enabled = false  # Will enable later with proper configuration
      }

      dex = {
        enabled = false  # Will configure SSO later
      }

      redis = {
        enabled = true
        resources = {
          limits = {
            cpu    = "200m"
            memory = "256Mi"
          }
          requests = {
            cpu    = "100m"
            memory = "128Mi"
          }
        }
      }
    })
  ]

  depends_on = [module.eks_primary]
}

# Crossplane Installation
resource "helm_release" "crossplane" {
  name       = "crossplane"
  repository = "https://charts.crossplane.io/stable"
  chart      = "crossplane"
  version    = "1.14.5"  # Latest stable version
  namespace  = "crossplane-system"
  create_namespace = true

  values = [
    yamlencode({
      replicas = 2

      image = {
        repository = "crossplane/crossplane"
        pullPolicy = "IfNotPresent"
      }

      resourcesCrossplane = {
        limits = {
          cpu    = "500m"
          memory = "1Gi"
        }
        requests = {
          cpu    = "250m"
          memory = "512Mi"
        }
      }

      resourcesRBACManager = {
        limits = {
          cpu    = "200m"
          memory = "256Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "128Mi"
        }
      }

      nodeSelector = {
        "node.kubernetes.io/instance-type" = "t3.medium"
      }

      tolerations = []

      args = [
        "--debug",
        "--enable-composition-revisions"
      ]

      metrics = {
        enabled = true
      }

      registryCaBundleConfig = {
        name = ""
        key = ""
      }
    })
  ]

  depends_on = [module.eks_primary]
}

# Crossplane AWS Provider Configuration
resource "kubernetes_manifest" "crossplane_aws_provider" {
  manifest = {
    apiVersion = "pkg.crossplane.io/v1"
    kind       = "Provider"
    metadata = {
      name = "provider-aws"
      namespace = "crossplane-system"
    }
    spec = {
      package = "xpkg.upbound.io/crossplane-contrib/provider-aws:v0.44.0"
      packagePullPolicy = "IfNotPresent"
    }
  }

  depends_on = [helm_release.crossplane]
}

# IAM Role for Crossplane AWS Provider
resource "aws_iam_role" "crossplane_aws_provider" {
  name = "${local.cluster_name_primary}-crossplane-aws-provider"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks_primary.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:crossplane-system:provider-aws-*"
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

# IAM Policy for Crossplane AWS Provider
resource "aws_iam_role_policy" "crossplane_aws_provider" {
  name = "${local.cluster_name_primary}-crossplane-aws-provider-policy"
  role = aws_iam_role.crossplane_aws_provider.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          # EBS permissions
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:DescribeVolumeAttribute",
          "ec2:ModifyVolumeAttribute",
          "ec2:CreateSnapshot",
          "ec2:DeleteSnapshot",
          "ec2:DescribeSnapshots",
          "ec2:CreateTags",
          "ec2:DeleteTags",
          "ec2:DescribeTags",
          # RDS permissions
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:CreateDBParameterGroup",
          "rds:DeleteDBParameterGroup",
          "rds:DescribeDBParameterGroups",
          "rds:AddTagsToResource",
          "rds:RemoveTagsFromResource",
          "rds:ListTagsForResource",
          # VPC and networking permissions for RDS
          "ec2:DescribeSubnets",
          "ec2:DescribeVpcs",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:DescribeNetworkInterfaces"
        ]
        Resource = "*"
      }
    ]
  })
}

# Kubernetes Service Account for Crossplane AWS Provider
resource "kubernetes_service_account" "crossplane_aws_provider" {
  metadata {
    name      = "crossplane-aws-provider"
    namespace = "crossplane-system"
    annotations = {
      "eks.amazonaws.com/role-arn" = aws_iam_role.crossplane_aws_provider.arn
    }
  }

  depends_on = [helm_release.crossplane]
}

# Cluster Autoscaler
resource "helm_release" "cluster_autoscaler" {
  name       = "cluster-autoscaler"
  repository = "https://kubernetes.github.io/autoscaler"
  chart      = "cluster-autoscaler"
  version    = "9.29.4"  # Latest stable version
  namespace  = "kube-system"

  values = [
    yamlencode({
      autoDiscovery = {
        clusterName = module.eks_primary.cluster_name
        enabled     = true
      }

      awsRegion = var.aws_region_primary

      rbac = {
        serviceAccount = {
          annotations = {
            "eks.amazonaws.com/role-arn" = aws_iam_role.cluster_autoscaler.arn
          }
        }
      }

      resources = {
        limits = {
          cpu    = "300m"
          memory = "512Mi"
        }
        requests = {
          cpu    = "100m"
          memory = "256Mi"
        }
      }

      nodeSelector = {
        "node.kubernetes.io/instance-type" = "t3.medium"
      }

      tolerations = []

      extraArgs = {
        logtostderr         = true
        stderrthreshold     = "info"
        v                   = 4
        skip-nodes-with-local-storage = false
        expander            = "least-waste"
        node-group-auto-discovery = "asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/${module.eks_primary.cluster_name}"
        balance-similar-node-groups = true
        scale-down-enabled = true
        scale-down-delay-after-add = "10m"
        scale-down-unneeded-time = "10m"
        scale-down-utilization-threshold = 0.5
      }
    })
  ]

  depends_on = [
    module.eks_primary,
    aws_iam_role_policy_attachment.cluster_autoscaler
  ]
}

# IAM Role for Cluster Autoscaler
resource "aws_iam_role" "cluster_autoscaler" {
  name = "${local.cluster_name_primary}-cluster-autoscaler"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRoleWithWebIdentity"
        Effect = "Allow"
        Principal = {
          Federated = module.eks_primary.oidc_provider_arn
        }
        Condition = {
          StringEquals = {
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:sub": "system:serviceaccount:kube-system:cluster-autoscaler"
            "${replace(module.eks_primary.cluster_oidc_issuer_url, "https://", "")}:aud": "sts.amazonaws.com"
          }
        }
      }
    ]
  })

  tags = local.common_tags
}

resource "aws_iam_role_policy" "cluster_autoscaler" {
  name = "${local.cluster_name_primary}-cluster-autoscaler-policy"
  role = aws_iam_role.cluster_autoscaler.id

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
}

resource "aws_iam_role_policy_attachment" "cluster_autoscaler" {
  policy_arn = aws_iam_policy.cluster_autoscaler.arn
  role       = aws_iam_role.cluster_autoscaler.name
}

resource "aws_iam_policy" "cluster_autoscaler" {
  name        = "${local.cluster_name_primary}-cluster-autoscaler"
  description = "IAM policy for cluster autoscaler"

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

  tags = local.common_tags
} 