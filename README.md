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
```

### 2. Setup Terraform Backend (Required First)
Before deploying the main infrastructure, you need to create the S3 bucket and DynamoDB table for Terraform state management:

```bash
# Navigate to backend directory
cd terraform/backend

# Initialize and deploy backend resources
terraform init
terraform plan
terraform apply

# Get the backend configuration values
terraform output backend_config
```

**Note**: Save the output values from `terraform output backend_config` as you'll need them in the next step.

### 3. Configure Main Environment Backend
```bash
# Navigate to dev environment
cd ../environments/dev

# Initialize with backend configuration (replace with your actual values from step 2)
terraform init \
  -backend-config="bucket=your-s3-bucket-name" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=your-dynamodb-table-name" \
  -backend-config="encrypt=true"
```

**Alternative**: Create a backend config file for easier management:
```bash
cat > backend.hcl << EOF
bucket         = "your-actual-bucket-name"
key            = "dev/terraform.tfstate"
region         = "us-east-1"
dynamodb_table = "your-actual-dynamodb-table-name"
encrypt        = true
EOF

# Then initialize with the config file
terraform init -backend-config=backend.hcl
```

### 4. Configure Variables (Optional)
If you need to customize default values, create and edit a terraform.tfvars file:
```bash
# Create variables file (optional - defaults are provided)
cat > terraform.tfvars << EOF
aws_region_primary   = "us-east-1"
aws_region_secondary = "eu-west-1"
cluster_name        = "nestle-poc"
environment         = "dev"
EOF
```

### 5. Deploy Infrastructure
```bash
# Plan and apply the infrastructure
terraform plan
terraform apply
```

### 6. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name nestle-poc-dev-primary
```

### 7. Access ArgoCD
```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Initial password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Common Issues and Troubleshooting

### Backend Configuration Issues

If you encounter errors like:
- "Missing region value" during `terraform init`
- Prompts for bucket name and key during initialization
- "Error: Missing region value on main.tf line 26, in terraform: backend "s3""

**Solution**: You need to set up the backend infrastructure first. Follow these steps:

1. **Deploy Backend First**: Navigate to `terraform/backend/` and run `terraform init`, `terraform plan`, and `terraform apply`
2. **Get Backend Values**: Run `terraform output backend_config` to get the S3 bucket and DynamoDB table names
3. **Initialize Main Environment**: Use the backend configuration values when initializing the main environment

**Example**:
```bash
# After backend deployment, you'll get output like:
# bucket = "nestle-poc-terraform-state-abc12345"
# dynamodb_table = "nestle-poc-terraform-locks-abc12345"

# Use these values to initialize the main environment:
cd ../environments/dev
terraform init \
  -backend-config="bucket=nestle-poc-terraform-state-abc12345" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=nestle-poc-terraform-locks-abc12345" \
  -backend-config="encrypt=true"
```

### AWS Credentials and Permissions

Ensure your AWS CLI is configured with sufficient permissions:
```bash
aws sts get-caller-identity  # Verify your AWS identity
aws iam list-attached-user-policies --user-name your-username  # Check permissions
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