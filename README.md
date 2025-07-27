# Nestle DevOps PoC - Multi-Regional EKS with GitOps

## Project Overview

This project demonstrates a comprehensive DevOps proof of concept featuring:
- Multi-regional Amazon EKS clusters (US-East-1, EU-West-1)
- Infrastructure as Code using Terraform
- GitOps deployment with ArgoCD
- Security policies as code with Kyverno
- Automated storage provisioning with Crossplane
- Container registry with cross-region replication

## Architecture

The solution deploys a resilient, secure, and automated Kubernetes platform across multiple AWS regions with the following components:

### Core Infrastructure
- **EKS Clusters**: Latest Kubernetes version with managed node groups
- **VPC**: Private/public subnet architecture with NAT gateways
- **ECR**: Container registry with cross-region replication
- **RDS**: PostgreSQL database for SonarQube

### Platform Services
- **ArgoCD**: GitOps continuous deployment
- **Jenkins LTS**: CI/CD automation platform
- **SonarQube**: Code quality and security analysis
- **Kyverno**: Policy as code enforcement
- **Crossplane**: Infrastructure provisioning automation

### Security Features
- RBAC with least privilege principles
- Pod security policies enforcement
- Read-only root filesystem requirements
- Resource limits enforcement
- Network policies and security groups

## Prerequisites

### Required Tools
```bash
# Install required tools
terraform >= 1.5.0
aws-cli >= 2.0
kubectl >= 1.28
helm >= 3.12
git
```

### AWS Requirements
- AWS Account with administrative access
- AWS CLI configured with appropriate credentials
- Sufficient service limits for EKS, VPC, and related resources

## Quick Start

### 1. Clone and Setup
```bash
git clone <repository-url>
cd nestle_poc
cp terraform/environments/dev/terraform.tfvars.example terraform/environments/dev/terraform.tfvars
```

### 2. Configure Variables
Edit `terraform/environments/dev/terraform.tfvars` with your specific values:
```hcl
aws_region_primary   = "us-east-1"
aws_region_secondary = "eu-west-1"
cluster_name        = "nestle-poc"
environment         = "dev"
```

### 3. Deploy Infrastructure
```bash
# Initialize and deploy
cd terraform/environments/dev
terraform init
terraform plan
terraform apply
```

### 4. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name nestle-poc-dev
```

### 5. Access ArgoCD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Project Structure

```
nestle_poc/
├── .memory/                    # Project documentation and planning
│   └── task/                   # Task breakdown and requirements
├── terraform/                  # Infrastructure as Code
│   ├── modules/               # Reusable Terraform modules
│   ├── environments/          # Environment-specific configurations
│   └── backend/               # Remote state backend setup
├── k8s-manifests/             # Kubernetes manifests for GitOps
│   ├── applications/          # Application deployments
│   ├── infrastructure/        # Platform services
│   └── policies/             # Security policies
├── helm-charts/               # Custom Helm charts
└── scripts/                   # Automation scripts
```

## Development Workflow

1. **Infrastructure Changes**: Modify Terraform configurations and apply
2. **Application Changes**: Update K8s manifests, commit to Git
3. **Policy Changes**: Update Kyverno policies in k8s-manifests/policies
4. **ArgoCD Sync**: Automatic or manual sync from Git repository

## Monitoring and Operations

### Accessing Services
- **ArgoCD**: Port-forward to 8080 or use LoadBalancer
- **Jenkins**: Access via Ingress or port-forward
- **SonarQube**: Access via configured Ingress

### Troubleshooting
- Check ArgoCD application status
- Review Kyverno policy violations
- Monitor EKS cluster health
- Verify Crossplane resource status

## Security Considerations

- All EBS volumes encrypted at rest
- RDS encryption enabled
- IRSA for secure AWS service access
- Network policies for traffic isolation
- Security policies enforced via Kyverno

## Cost Optimization

- Spot instances for non-critical workloads
- Automated resource cleanup
- EBS snapshot lifecycle management
- ECR image lifecycle policies

## Contributing

1. Follow the established project structure
2. Update documentation for any changes
3. Test changes in development environment
4. Follow GitOps workflow for deployments

## Support

For issues and questions:
1. Check the troubleshooting section
2. Review ArgoCD and application logs
3. Validate Terraform state and resources
4. Contact the DevOps team

---

**Note**: This is a proof of concept. Additional hardening and production readiness measures should be implemented for production use. 