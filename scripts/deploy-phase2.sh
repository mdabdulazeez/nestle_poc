#!/bin/bash

# Nestle PoC Phase 2: EKS Add-ons Deployment Script
# This script automates the deployment of EKS add-ons and platform services

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
AWS_REGION_PRIMARY="us-east-1"
AWS_REGION_SECONDARY="eu-west-1"
ENVIRONMENT="dev"
PROJECT_NAME="nestle-poc"
AUTO_APPROVE=false
BACKEND_BUCKET=""

# Function to print colored output
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites for Phase 2 deployment..."
    
    # Check if required tools are installed
    local tools=("terraform" "aws" "kubectl" "helm")
    local missing_tools=()
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        print_info "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        print_info "Please configure AWS credentials using 'aws configure' or environment variables"
        exit 1
    fi
    
    # Check if Phase 1 infrastructure exists
    print_info "Verifying Phase 1 infrastructure exists..."
    local primary_cluster="${PROJECT_NAME}-${ENVIRONMENT}-primary"
    if ! aws eks describe-cluster --name "$primary_cluster" --region "$AWS_REGION_PRIMARY" &> /dev/null; then
        print_error "Phase 1 infrastructure not found. EKS cluster '$primary_cluster' does not exist."
        print_info "Please deploy Phase 1 infrastructure first using the main deployment script."
        exit 1
    fi
    
    print_success "Prerequisites satisfied and Phase 1 infrastructure verified"
}

# Function to get backend bucket from Phase 1
get_backend_configuration() {
    print_info "Retrieving backend configuration from Phase 1..."
    
    local dev_dir="terraform/environments/dev"
    
    if [ ! -d "$dev_dir" ]; then
        print_error "Phase 1 directory not found: $dev_dir"
        print_info "Please ensure you're running this script from the project root"
        exit 1
    fi
    
    cd "$dev_dir"
    
    # Try to get the backend bucket from terraform output
    if terraform output -raw s3_bucket_name &> /dev/null; then
        BACKEND_BUCKET=$(terraform output -raw s3_bucket_name)
        print_success "Backend bucket found: $BACKEND_BUCKET"
    else
        print_error "Could not retrieve backend bucket name from Phase 1 outputs"
        print_info "Please ensure Phase 1 infrastructure is deployed and Terraform state is accessible"
        exit 1
    fi
    
    cd ../../..
}

# Function to setup terraform variables
setup_terraform_variables() {
    print_info "Setting up Terraform variables for Phase 2..."
    
    local addons_dir="terraform/environments/phase2-addons"
    
    if [ ! -f "$addons_dir/terraform.tfvars" ]; then
        print_info "Creating terraform.tfvars from example..."
        cp "$addons_dir/terraform.tfvars.example" "$addons_dir/terraform.tfvars"
        
        # Update the backend bucket in terraform.tfvars
        sed -i.bak "s/your-terraform-state-bucket-name-from-phase1/$BACKEND_BUCKET/" "$addons_dir/terraform.tfvars"
        rm -f "$addons_dir/terraform.tfvars.bak"
        
        print_success "Created terraform.tfvars with backend bucket: $BACKEND_BUCKET"
        print_warning "Please review and customize terraform.tfvars as needed before proceeding"
        
        if [ "$AUTO_APPROVE" != true ]; then
            read -p "Press Enter to continue after reviewing terraform.tfvars, or Ctrl+C to exit..."
        fi
    else
        print_info "Using existing terraform.tfvars"
        
        # Update backend bucket if it's still the placeholder
        if grep -q "your-terraform-state-bucket-name-from-phase1" "$addons_dir/terraform.tfvars"; then
            sed -i.bak "s/your-terraform-state-bucket-name-from-phase1/$BACKEND_BUCKET/" "$addons_dir/terraform.tfvars"
            rm -f "$addons_dir/terraform.tfvars.bak"
            print_info "Updated backend bucket in terraform.tfvars"
        fi
    fi
}

# Function to deploy Phase 2 add-ons
deploy_addons() {
    print_info "Deploying Phase 2: EKS Add-ons and Platform Services..."
    
    local addons_dir="terraform/environments/phase2-addons"
    
    if [ ! -d "$addons_dir" ]; then
        print_error "Add-ons directory not found: $addons_dir"
        exit 1
    fi
    
    cd "$addons_dir"
    
    # Initialize with backend configuration
    print_info "Initializing Terraform with remote backend..."
    terraform init \
        -backend-config="bucket=$BACKEND_BUCKET" \
        -backend-config="key=addons/terraform.tfstate" \
        -backend-config="region=$AWS_REGION_PRIMARY" \
        -backend-config="dynamodb_table=$(echo $BACKEND_BUCKET | sed 's/terraform-state/terraform-locks/')" \
        -backend-config="encrypt=true"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to initialize Terraform"
        exit 1
    fi
    
    # Plan deployment
    print_info "Planning add-ons deployment..."
    terraform plan \
        -var="aws_region_primary=$AWS_REGION_PRIMARY" \
        -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME" \
        -var="backend_bucket=$BACKEND_BUCKET"
    
    if [ $? -ne 0 ]; then
        print_error "Failed to plan add-ons deployment"
        exit 1
    fi
    
    # Apply deployment
    print_info "Applying add-ons deployment..."
    if [ "$AUTO_APPROVE" = true ]; then
        terraform apply -auto-approve \
            -var="aws_region_primary=$AWS_REGION_PRIMARY" \
            -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
            -var="environment=$ENVIRONMENT" \
            -var="project_name=$PROJECT_NAME" \
            -var="backend_bucket=$BACKEND_BUCKET"
    else
        terraform apply \
            -var="aws_region_primary=$AWS_REGION_PRIMARY" \
            -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
            -var="environment=$ENVIRONMENT" \
            -var="project_name=$PROJECT_NAME" \
            -var="backend_bucket=$BACKEND_BUCKET"
    fi
    
    if [ $? -ne 0 ]; then
        print_error "Failed to apply add-ons deployment"
        exit 1
    fi
    
    print_success "Phase 2 add-ons deployment completed"
    
    cd ../../..
}

# Function to verify deployment
verify_deployment() {
    print_info "Verifying Phase 2 deployment..."
    
    # Configure kubectl for primary cluster
    local primary_cluster="${PROJECT_NAME}-${ENVIRONMENT}-primary"
    aws eks update-kubeconfig --region "$AWS_REGION_PRIMARY" --name "$primary_cluster" --alias "primary"
    
    # Check if add-ons are running
    print_info "Checking add-on status..."
    
    # Check EBS CSI Driver
    if kubectl get pods -n kube-system -l app=ebs-csi-controller &> /dev/null; then
        print_success "✅ EBS CSI Driver is running"
    else
        print_warning "⚠️  EBS CSI Driver pods not found"
    fi
    
    # Check NGINX Ingress
    if kubectl get pods -n ingress-nginx &> /dev/null; then
        print_success "✅ NGINX Ingress Controller is running"
    else
        print_warning "⚠️  NGINX Ingress Controller pods not found"
    fi
    
    # Check ArgoCD
    if kubectl get pods -n argocd &> /dev/null; then
        print_success "✅ ArgoCD is running"
    else
        print_warning "⚠️  ArgoCD pods not found"
    fi
    
    # Check Crossplane
    if kubectl get pods -n crossplane-system &> /dev/null; then
        print_success "✅ Crossplane is running"
    else
        print_warning "⚠️  Crossplane pods not found"
    fi
    
    # Check Cluster Autoscaler
    if kubectl get pods -n kube-system -l app=cluster-autoscaler &> /dev/null; then
        print_success "✅ Cluster Autoscaler is running"
    else
        print_warning "⚠️  Cluster Autoscaler pods not found"
    fi
}

# Function to display access information
display_access_info() {
    print_success "Phase 2 deployment completed successfully!"
    echo
    print_info "🔗 Access Information:"
    echo
    echo "📋 ArgoCD Access:"
    echo "   Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "   URL: https://localhost:8080"
    echo "   Username: admin"
    echo "   Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo
    echo "🌐 NGINX Ingress Load Balancer:"
    echo "   Status: kubectl get svc ingress-nginx-controller -n ingress-nginx"
    echo
    echo "📦 Crossplane Providers:"
    echo "   Status: kubectl get providers -n crossplane-system"
    echo
    echo "💾 Storage Classes:"
    echo "   List: kubectl get storageclass"
    echo
    print_info "🚀 Next Steps (Phase 3):"
    echo "1. Deploy Kyverno security policies"
    echo "2. Create Crossplane compositions for EBS and RDS"
    echo "3. Configure ArgoCD applications and repositories"
    echo "4. Deploy Jenkins and SonarQube via GitOps"
    echo
    print_info "📊 Health Check Commands:"
    echo "   All pods: kubectl get pods -A"
    echo "   Nodes: kubectl get nodes"
    echo "   Add-on status: kubectl get pods -n kube-system,ingress-nginx,argocd,crossplane-system"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -p, --primary-region REGION    Primary AWS region (default: us-east-1)"
    echo "  -s, --secondary-region REGION  Secondary AWS region (default: eu-west-1)"
    echo "  -e, --environment ENV          Environment name (default: dev)"
    echo "  -n, --project-name NAME        Project name (default: nestle-poc)"
    echo "  --auto-approve                 Auto-approve Terraform plans"
    echo "  -h, --help                     Show this help message"
    echo
    echo "Examples:"
    echo "  $0                             # Deploy with default settings"
    echo "  $0 -p us-west-2 -s eu-central-1  # Deploy to different regions"
    echo "  $0 --auto-approve              # Auto-approve deployment"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -p|--primary-region)
            AWS_REGION_PRIMARY="$2"
            shift 2
            ;;
        -s|--secondary-region)
            AWS_REGION_SECONDARY="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -n|--project-name)
            PROJECT_NAME="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "=================================================="
    echo "🚀 Nestle PoC Phase 2: EKS Add-ons Deployment"
    echo "=================================================="
    echo
    print_info "Configuration:"
    echo "  Primary Region: $AWS_REGION_PRIMARY"
    echo "  Secondary Region: $AWS_REGION_SECONDARY"
    echo "  Environment: $ENVIRONMENT"
    echo "  Project Name: $PROJECT_NAME"
    echo "  Auto Approve: $AUTO_APPROVE"
    echo
    
    # Execute deployment phases
    check_prerequisites
    get_backend_configuration
    setup_terraform_variables
    deploy_addons
    verify_deployment
    display_access_info
    
    print_success "🎉 Phase 2 deployment completed successfully!"
}

# Run main function
main 