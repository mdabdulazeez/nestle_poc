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
- SSH key-based node access (optional, managed by Terraform)
- Encrypted EBS volumes and RDS databases

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

### 4. Generate SSH Key Pair (Required for Node Access)
Generate an SSH key pair for accessing EKS worker nodes:

```bash
# Generate new SSH key pair for EKS nodes
ssh-keygen -t ed25519 -f ~/.ssh/nestle-poc-key -N ""

# Display the public key (you'll need this for next step)
cat ~/.ssh/nestle-poc-key.pub
```

**Note**: Keep your private key (`~/.ssh/nestle-poc-key`) secure and never commit it to version control.

### 5. Configure Variables (Required)
Create a terraform.tfvars file with your SSH public key and any custom values:

```bash
# Create variables file with SSH public key
cat > terraform.tfvars << EOF
# SSH Configuration (Required)
ssh_public_key = "$(cat ~/.ssh/nestle-poc-key.pub)"

# Optional Customizations (defaults provided)
aws_region_primary   = "us-east-1"
aws_region_secondary = "eu-west-1"
cluster_name         = "nestle-poc"
environment          = "dev"
EOF
```

**Alternative**: Manual configuration
```bash
# If you prefer to edit manually
cp terraform.tfvars.example terraform.tfvars
# Then edit terraform.tfvars and add your SSH public key
```

### 6. Deploy Infrastructure
```bash
# Plan and apply the infrastructure
terraform plan
terraform apply

# View SSH key information
terraform output ssh_key_pairs
```

### 7. Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name nestle-poc-dev-primary
```

### 8. Verify Infrastructure
```bash
# Check cluster status
kubectl get nodes

# Check system pods
kubectl get pods -A

# View deployment outputs
terraform output
```

### 9. SSH Access to EKS Nodes (Optional)
With the SSH key configured, you can access EKS worker nodes:

```bash
# Get node instance information
aws ec2 describe-instances --region us-east-1 \
  --filters "Name=tag:Name,Values=*nestle-poc-dev-primary*" \
  --query 'Reservations[*].Instances[*].{Instance:InstanceId,PublicIP:PublicIpAddress,PrivateIP:PrivateIpAddress,State:State.Name}' \
  --output table

# SSH to a node (replace IP with actual node IP)
ssh -i ~/.ssh/nestle-poc-key ec2-user@NODE_IP
```

### 10. Access ArgoCD (Phase 2)
**Note**: ArgoCD is deployed in Phase 2. For Phase 1, you have the foundational infrastructure.

```bash
# After Phase 2 deployment
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

### SSH Key Configuration Issues

If you encounter SSH-related errors:

**Problem**: `ec2SshKey in remote-access can't be empty`
**Solution**: Ensure you've provided a valid SSH public key:
```bash
# Generate SSH key if you don't have one
ssh-keygen -t ed25519 -f ~/.ssh/nestle-poc-key -N ""

# Add to terraform.tfvars
echo 'ssh_public_key = "'$(cat ~/.ssh/nestle-poc-key.pub)'"' >> terraform.tfvars
```

**Problem**: SSH connection refused to EKS nodes
**Solutions**:
```bash
# 1. Verify key pair was created
terraform output ssh_key_pairs

# 2. Check node security groups allow SSH
aws ec2 describe-security-groups --region us-east-1 --filters "Name=group-name,Values=*nestle-poc*node*"

# 3. Verify you're using correct private key
ssh -i ~/.ssh/nestle-poc-key ec2-user@NODE_IP

# 4. Check if nodes have public IPs (may need bastion/VPN for private nodes)
```

**Problem**: SSH key not recognized
**Solution**: Verify key format and permissions:
```bash
# Check key format
file ~/.ssh/nestle-poc-key
cat ~/.ssh/nestle-poc-key.pub

# Fix permissions
chmod 400 ~/.ssh/nestle-poc-key
chmod 644 ~/.ssh/nestle-poc-key.pub
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
2. **SSH Key Management**: Update SSH public key in terraform.tfvars if needed
3. **Application Changes**: Update K8s manifests, commit to Git
4. **Policy Changes**: Update Kyverno policies in k8s-manifests/policies
5. **ArgoCD Sync**: Automatic or manual sync from Git repository

**Note**: SSH keys are managed by Terraform and automatically deployed to both regions.

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
- Check SSH key pair deployment: `terraform output ssh_key_pairs`
- Verify node SSH access with security groups and network connectivity

## Security Considerations

- All EBS volumes encrypted at rest
- RDS encryption enabled
- IRSA for secure AWS service access
- Network policies for traffic isolation
- Security policies enforced via Kyverno
- SSH key pairs managed by Terraform with proper tagging
- Optional SSH access to EKS nodes (can be disabled by not providing ssh_public_key)

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