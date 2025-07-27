#!/bin/bash

# Nestle PoC Infrastructure Deployment Script
# This script automates the deployment of the multi-regional EKS infrastructure

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
SKIP_BACKEND=false
AUTO_APPROVE=false

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
    print_info "Checking prerequisites..."
    
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
    
    # Check Terraform version
    local tf_version=$(terraform version -json | grep '"terraform_version"' | cut -d'"' -f4)
    print_info "Terraform version: $tf_version"
    
    print_success "All prerequisites satisfied"
}

# Function to validate AWS permissions
validate_aws_permissions() {
    print_info "Validating AWS permissions..."
    
    local required_services=("eks" "ec2" "iam" "s3" "dynamodb" "ecr")
    local permission_check_passed=true
    
    # Basic permission check - try to list resources
    for service in "${required_services[@]}"; do
        case $service in
            "eks")
                if ! aws eks list-clusters --region "$AWS_REGION_PRIMARY" &> /dev/null; then
                    print_warning "EKS permissions may be insufficient in $AWS_REGION_PRIMARY"
                fi
                ;;
            "ec2")
                if ! aws ec2 describe-vpcs --region "$AWS_REGION_PRIMARY" &> /dev/null; then
                    print_warning "EC2 permissions may be insufficient in $AWS_REGION_PRIMARY"
                fi
                ;;
            "iam")
                if ! aws iam list-roles &> /dev/null; then
                    print_warning "IAM permissions may be insufficient"
                fi
                ;;
        esac
    done
    
    print_success "AWS permissions validation completed"
}

# Function to setup Terraform backend
setup_backend() {
    if [ "$SKIP_BACKEND" = true ]; then
        print_info "Skipping backend setup as requested"
        return
    fi
    
    print_info "Setting up Terraform backend..."
    
    local backend_dir="terraform/backend"
    
    if [ ! -d "$backend_dir" ]; then
        print_error "Backend directory not found: $backend_dir"
        exit 1
    fi
    
    cd "$backend_dir"
    
    # Initialize and apply backend
    terraform init
    terraform plan -var="aws_region=$AWS_REGION_PRIMARY"
    
    if [ "$AUTO_APPROVE" = true ]; then
        terraform apply -auto-approve -var="aws_region=$AWS_REGION_PRIMARY"
    else
        terraform apply -var="aws_region=$AWS_REGION_PRIMARY"
    fi
    
    # Get backend configuration
    local bucket_name=$(terraform output -raw s3_bucket_name)
    local dynamodb_table=$(terraform output -raw dynamodb_table_name)
    
    print_success "Backend setup completed"
    print_info "S3 Bucket: $bucket_name"
    print_info "DynamoDB Table: $dynamodb_table"
    
    # Return to project root
    cd ../../..
    
    # Export backend info for later use
    export TF_BACKEND_BUCKET="$bucket_name"
    export TF_BACKEND_DYNAMODB_TABLE="$dynamodb_table"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    print_info "Deploying infrastructure..."
    
    local env_dir="terraform/environments/$ENVIRONMENT"
    
    if [ ! -d "$env_dir" ]; then
        print_error "Environment directory not found: $env_dir"
        exit 1
    fi
    
    cd "$env_dir"
    
    # Initialize with backend configuration if available
    if [ -n "$TF_BACKEND_BUCKET" ]; then
        print_info "Initializing with remote backend..."
        terraform init \
            -backend-config="bucket=$TF_BACKEND_BUCKET" \
            -backend-config="key=$ENVIRONMENT/terraform.tfstate" \
            -backend-config="region=$AWS_REGION_PRIMARY" \
            -backend-config="dynamodb_table=$TF_BACKEND_DYNAMODB_TABLE" \
            -backend-config="encrypt=true"
    else
        print_info "Initializing with local backend..."
        terraform init
    fi
    
    # Plan deployment
    terraform plan \
        -var="aws_region_primary=$AWS_REGION_PRIMARY" \
        -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
        -var="environment=$ENVIRONMENT" \
        -var="project_name=$PROJECT_NAME"
    
    # Apply deployment
    if [ "$AUTO_APPROVE" = true ]; then
        terraform apply -auto-approve \
            -var="aws_region_primary=$AWS_REGION_PRIMARY" \
            -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
            -var="environment=$ENVIRONMENT" \
            -var="project_name=$PROJECT_NAME"
    else
        terraform apply \
            -var="aws_region_primary=$AWS_REGION_PRIMARY" \
            -var="aws_region_secondary=$AWS_REGION_SECONDARY" \
            -var="environment=$ENVIRONMENT" \
            -var="project_name=$PROJECT_NAME"
    fi
    
    print_success "Infrastructure deployment completed"
    
    # Return to project root
    cd ../../..
}

# Function to configure kubectl
configure_kubectl() {
    print_info "Configuring kubectl for both clusters..."
    
    local env_dir="terraform/environments/$ENVIRONMENT"
    cd "$env_dir"
    
    # Get cluster names from Terraform output
    local primary_cluster=$(terraform output -json primary_cluster_info | grep -o '"cluster_name":"[^"]*' | cut -d'"' -f4)
    local secondary_cluster=$(terraform output -json secondary_cluster_info | grep -o '"cluster_name":"[^"]*' | cut -d'"' -f4)
    
    # Configure kubectl for both clusters
    aws eks update-kubeconfig --region "$AWS_REGION_PRIMARY" --name "$primary_cluster"
    aws eks update-kubeconfig --region "$AWS_REGION_SECONDARY" --name "$secondary_cluster"
    
    # Test connectivity
    print_info "Testing cluster connectivity..."
    if kubectl get nodes &> /dev/null; then
        print_success "kubectl configured successfully"
        kubectl get nodes
    else
        print_warning "kubectl configuration may have issues"
    fi
    
    cd ../../..
}

# Function to display next steps
display_next_steps() {
    print_success "Deployment completed successfully!"
    echo
    print_info "Next steps:"
    echo "1. Review the Terraform outputs for cluster information"
    echo "2. Proceed with Phase 2: Deploy EKS add-ons"
    echo "3. Setup ArgoCD and GitOps workflow"
    echo "4. Deploy applications (Jenkins, SonarQube, Kyverno)"
    echo
    print_info "Useful commands:"
    echo "- View Terraform outputs: cd terraform/environments/$ENVIRONMENT && terraform output"
    echo "- List contexts: kubectl config get-contexts"
    echo "- Switch context: kubectl config use-context <context-name>"
    echo "- View nodes: kubectl get nodes"
    echo "- View all pods: kubectl get pods -A"
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
    echo "  --skip-backend                 Skip Terraform backend setup"
    echo "  --auto-approve                 Auto-approve Terraform plans"
    echo "  -h, --help                     Show this help message"
    echo
    echo "Examples:"
    echo "  $0                             # Deploy with default settings"
    echo "  $0 -p us-west-2 -s eu-central-1  # Deploy to different regions"
    echo "  $0 --skip-backend --auto-approve  # Skip backend and auto-approve"
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
        --skip-backend)
            SKIP_BACKEND=true
            shift
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
    echo "🚀 Nestle PoC Infrastructure Deployment"
    echo "=================================================="
    echo
    print_info "Configuration:"
    echo "  Primary Region: $AWS_REGION_PRIMARY"
    echo "  Secondary Region: $AWS_REGION_SECONDARY"
    echo "  Environment: $ENVIRONMENT"
    echo "  Project Name: $PROJECT_NAME"
    echo "  Skip Backend: $SKIP_BACKEND"
    echo "  Auto Approve: $AUTO_APPROVE"
    echo
    
    # Execute deployment phases
    check_prerequisites
    validate_aws_permissions
    setup_backend
    deploy_infrastructure
    configure_kubectl
    display_next_steps
    
    print_success "All phases completed successfully! 🎉"
}

# Run main function
main 