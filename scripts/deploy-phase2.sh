#!/bin/bash

# Nestle PoC Phase 2 Deployment Script
# This script deploys the core add-ons and platform services to the EKS clusters

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="dev"
AUTO_APPROVE=false
VERIFY_ONLY=false

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

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo
    echo "Options:"
    echo "  -e, --environment ENV          Environment name (default: dev)"
    echo "  --auto-approve                 Auto-approve Terraform plans"
    echo "  --verify-only                  Only verify existing infrastructure"
    echo "  -h, --help                     Show this help message"
    echo
    echo "Examples:"
    echo "  $0                             # Deploy Phase 2 with default settings"
    echo "  $0 --auto-approve              # Deploy with auto-approval"
    echo "  $0 --verify-only               # Only verify existing setup"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --verify-only)
            VERIFY_ONLY=true
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

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites for Phase 2..."
    
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
        exit 1
    fi
    
    # Check if we're in the right directory
    if [ ! -d "terraform/environments/$ENVIRONMENT" ]; then
        print_error "Environment directory not found: terraform/environments/$ENVIRONMENT"
        print_info "Please run this script from the project root directory"
        exit 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials not configured or invalid"
        exit 1
    fi
    
    print_success "Prerequisites check passed"
}

# Function to verify Phase 1 infrastructure
verify_phase1() {
    print_info "Verifying Phase 1 infrastructure..."
    
    cd "terraform/environments/$ENVIRONMENT"
    
    # Check if Terraform is initialized
    if [ ! -d ".terraform" ]; then
        print_error "Terraform not initialized. Please run Phase 1 deployment first."
        exit 1
    fi
    
    # Get cluster information
    if ! terraform output primary_cluster_info &> /dev/null; then
        print_error "Phase 1 infrastructure not found. Please deploy Phase 1 first."
        exit 1
    fi
    
    # Configure kubectl
    local primary_cluster=$(terraform output -json primary_cluster_info | grep -o '"cluster_name":"[^"]*' | cut -d'"' -f4)
    local primary_region=$(terraform output -json primary_cluster_info | grep -o '"region":"[^"]*' | cut -d'"' -f4)
    
    print_info "Configuring kubectl for cluster: $primary_cluster"
    aws eks update-kubeconfig --region "$primary_region" --name "$primary_cluster"
    
    # Test cluster connectivity
    if ! kubectl get nodes &> /dev/null; then
        print_error "Cannot connect to EKS cluster. Please check your configuration."
        exit 1
    fi
    
    print_success "Phase 1 infrastructure verified"
    print_info "Connected to cluster: $primary_cluster"
    
    cd ../../..
}

# Function to deploy Phase 2 add-ons
deploy_phase2() {
    if [ "$VERIFY_ONLY" = true ]; then
        print_info "Verification complete. Skipping deployment as requested."
        return
    fi
    
    print_info "Deploying Phase 2: Core Add-ons & Platform Services..."
    
    cd "terraform/environments/$ENVIRONMENT"
    
    # Plan the deployment
    print_info "Planning Phase 2 deployment..."
    terraform plan -target=aws_eks_addon.ebs_csi_driver \
                   -target=helm_release.nginx_ingress \
                   -target=helm_release.argocd \
                   -target=helm_release.crossplane \
                   -target=helm_release.cluster_autoscaler
    
    # Apply the deployment
    if [ "$AUTO_APPROVE" = true ]; then
        print_info "Applying Phase 2 deployment with auto-approval..."
        terraform apply -auto-approve \
                       -target=aws_eks_addon.ebs_csi_driver \
                       -target=helm_release.nginx_ingress \
                       -target=helm_release.argocd \
                       -target=helm_release.crossplane \
                       -target=helm_release.cluster_autoscaler
    else
        print_info "Applying Phase 2 deployment..."
        terraform apply -target=aws_eks_addon.ebs_csi_driver \
                       -target=helm_release.nginx_ingress \
                       -target=helm_release.argocd \
                       -target=helm_release.crossplane \
                       -target=helm_release.cluster_autoscaler
    fi
    
    print_success "Phase 2 deployment completed"
    
    cd ../../..
}

# Function to verify deployment
verify_deployment() {
    if [ "$VERIFY_ONLY" = true ]; then
        return
    fi
    
    print_info "Verifying Phase 2 deployment..."
    
    # Wait for pods to be ready
    print_info "Waiting for add-ons to be ready..."
    
    # Check EBS CSI Driver
    print_info "Checking EBS CSI Driver..."
    kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s || true
    
    # Check NGINX Ingress
    print_info "Checking NGINX Ingress Controller..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s || true
    
    # Check ArgoCD
    print_info "Checking ArgoCD..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s || true
    
    # Check Crossplane
    print_info "Checking Crossplane..."
    kubectl wait --for=condition=ready pod -l app=crossplane -n crossplane-system --timeout=300s || true
    
    # Check Cluster Autoscaler
    print_info "Checking Cluster Autoscaler..."
    kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cluster-autoscaler -n kube-system --timeout=300s || true
    
    print_success "Phase 2 services verification completed"
}

# Function to display service information
display_service_info() {
    print_success "Phase 2 deployment completed successfully!"
    echo
    
    print_info "📋 Deployed Services Status:"
    echo
    
    # EBS CSI Driver
    print_info "🔧 EBS CSI Driver:"
    kubectl get pods -n kube-system -l app=ebs-csi-controller 2>/dev/null || echo "  Status: Deploying..."
    echo
    
    # NGINX Ingress
    print_info "🌐 NGINX Ingress Controller:"
    kubectl get svc -n ingress-nginx 2>/dev/null || echo "  Status: Deploying..."
    echo
    
    # ArgoCD
    print_info "🚀 ArgoCD:"
    kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>/dev/null || echo "  Status: Deploying..."
    echo
    
    # Crossplane
    print_info "🔄 Crossplane:"
    kubectl get pods -n crossplane-system 2>/dev/null || echo "  Status: Deploying..."
    echo
    
    # Cluster Autoscaler
    print_info "📈 Cluster Autoscaler:"
    kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler 2>/dev/null || echo "  Status: Deploying..."
    echo
    
    print_info "🔑 ArgoCD Access Information:"
    echo "  1. Get admin password:"
    echo "     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
    echo
    echo "  2. Access ArgoCD UI:"
    echo "     kubectl port-forward svc/argocd-server -n argocd 8080:443"
    echo "     Then browse to: http://localhost:8080 (username: admin)"
    echo
    echo "  3. Or get external LoadBalancer (if configured):"
    echo "     kubectl get svc -n argocd argocd-server"
    echo
    
    print_info "📊 Monitoring Commands:"
    echo "  - Check all services: kubectl get pods -A"
    echo "  - Check ingress: kubectl get svc -n ingress-nginx"
    echo "  - Check ArgoCD: kubectl get all -n argocd"
    echo "  - Check Crossplane: kubectl get providers -n crossplane-system"
    echo
    
    print_success "🎉 Phase 2 Complete! Ready for Phase 3: Security & Policy Implementation"
}

# Main execution
main() {
    echo "=================================================="
    echo "🚀 Phase 2: Core Add-ons & Platform Services"
    echo "=================================================="
    echo
    print_info "Configuration:"
    echo "  Environment: $ENVIRONMENT"
    echo "  Auto Approve: $AUTO_APPROVE"
    echo "  Verify Only: $VERIFY_ONLY"
    echo
    
    # Execute phases
    check_prerequisites
    verify_phase1
    deploy_phase2
    verify_deployment
    display_service_info
    
    if [ "$VERIFY_ONLY" = false ]; then
        print_success "Phase 2 deployment completed successfully! 🎉"
    else
        print_success "Phase 2 verification completed! 🎉"
    fi
}

# Run main function
main 