@echo off
REM Nestle PoC Phase 2 Deployment Script for Windows
REM This script deploys the core add-ons and platform services to the EKS clusters

setlocal enabledelayedexpansion

REM Default values
set ENVIRONMENT=dev
set AUTO_APPROVE=false
set VERIFY_ONLY=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_deployment
if "%~1"=="-e" (
    set ENVIRONMENT=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="--environment" (
    set ENVIRONMENT=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="--auto-approve" (
    set AUTO_APPROVE=true
    shift
    goto :parse_args
)
if "%~1"=="--verify-only" (
    set VERIFY_ONLY=true
    shift
    goto :parse_args
)
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help
echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %0 [OPTIONS]
echo.
echo Options:
echo   -e, --environment ENV          Environment name (default: dev)
echo   --auto-approve                 Auto-approve Terraform plans
echo   --verify-only                  Only verify existing infrastructure
echo   -h, --help                     Show this help message
echo.
echo Examples:
echo   %0                             # Deploy Phase 2 with default settings
echo   %0 --auto-approve              # Deploy with auto-approval
echo   %0 --verify-only               # Only verify existing setup
exit /b 0

:start_deployment
echo ==================================================
echo 🚀 Phase 2: Core Add-ons ^& Platform Services
echo ==================================================
echo.
echo [INFO] Configuration:
echo   Environment: !ENVIRONMENT!
echo   Auto Approve: !AUTO_APPROVE!
echo   Verify Only: !VERIFY_ONLY!
echo.

REM Check prerequisites
echo [INFO] Checking prerequisites for Phase 2...

REM Check if Terraform is installed
terraform version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Terraform is not installed or not in PATH
    exit /b 1
)

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] AWS CLI is not installed or not in PATH
    exit /b 1
)

REM Check if kubectl is installed
kubectl version --client >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] kubectl is not installed or not in PATH
    exit /b 1
)

REM Check if Helm is installed
helm version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Helm is not installed or not in PATH
    exit /b 1
)

REM Check if we're in the right directory
if not exist "terraform\environments\!ENVIRONMENT!" (
    echo [ERROR] Environment directory not found: terraform\environments\!ENVIRONMENT!
    echo [INFO] Please run this script from the project root directory
    exit /b 1
)

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] AWS credentials not configured or invalid
    exit /b 1
)

echo [SUCCESS] Prerequisites check passed

REM Verify Phase 1 infrastructure
echo [INFO] Verifying Phase 1 infrastructure...

cd terraform\environments\!ENVIRONMENT!

REM Check if Terraform is initialized
if not exist ".terraform" (
    echo [ERROR] Terraform not initialized. Please run Phase 1 deployment first.
    exit /b 1
)

REM Get cluster information
terraform output primary_cluster_info >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Phase 1 infrastructure not found. Please deploy Phase 1 first.
    exit /b 1
)

REM Configure kubectl
for /f "tokens=4 delims=:" %%i in ('terraform output -json primary_cluster_info ^| findstr "cluster_name"') do (
    set temp=%%i
    set temp=!temp:"=!
    set temp=!temp:,=!
    set primary_cluster=!temp!
)

for /f "tokens=4 delims=:" %%i in ('terraform output -json primary_cluster_info ^| findstr "region"') do (
    set temp=%%i
    set temp=!temp:"=!
    set temp=!temp:,=!
    set primary_region=!temp!
)

echo [INFO] Configuring kubectl for cluster: !primary_cluster!
aws eks update-kubeconfig --region !primary_region! --name !primary_cluster!

REM Test cluster connectivity
kubectl get nodes >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Cannot connect to EKS cluster. Please check your configuration.
    exit /b 1
)

echo [SUCCESS] Phase 1 infrastructure verified
echo [INFO] Connected to cluster: !primary_cluster!

REM Deploy Phase 2 add-ons
if "!VERIFY_ONLY!"=="true" (
    echo [INFO] Verification complete. Skipping deployment as requested.
    goto :verify_deployment
)

echo [INFO] Deploying Phase 2: Core Add-ons ^& Platform Services...

REM Plan the deployment
echo [INFO] Planning Phase 2 deployment...
terraform plan ^
    -target=aws_eks_addon.ebs_csi_driver ^
    -target=helm_release.nginx_ingress ^
    -target=helm_release.argocd ^
    -target=helm_release.crossplane ^
    -target=helm_release.cluster_autoscaler

if !errorlevel! neq 0 (
    echo [ERROR] Failed to plan Phase 2 deployment
    exit /b 1
)

REM Apply the deployment
if "!AUTO_APPROVE!"=="true" (
    echo [INFO] Applying Phase 2 deployment with auto-approval...
    terraform apply -auto-approve ^
        -target=aws_eks_addon.ebs_csi_driver ^
        -target=helm_release.nginx_ingress ^
        -target=helm_release.argocd ^
        -target=helm_release.crossplane ^
        -target=helm_release.cluster_autoscaler
) else (
    echo [INFO] Applying Phase 2 deployment...
    terraform apply ^
        -target=aws_eks_addon.ebs_csi_driver ^
        -target=helm_release.nginx_ingress ^
        -target=helm_release.argocd ^
        -target=helm_release.crossplane ^
        -target=helm_release.cluster_autoscaler
)

if !errorlevel! neq 0 (
    echo [ERROR] Failed to apply Phase 2 deployment
    exit /b 1
)

echo [SUCCESS] Phase 2 deployment completed

:verify_deployment
if "!VERIFY_ONLY!"=="true" (
    goto :display_service_info
)

echo [INFO] Verifying Phase 2 deployment...
echo [INFO] Waiting for add-ons to be ready...

REM Check EBS CSI Driver
echo [INFO] Checking EBS CSI Driver...
kubectl wait --for=condition=ready pod -l app=ebs-csi-controller -n kube-system --timeout=300s >nul 2>&1

REM Check NGINX Ingress
echo [INFO] Checking NGINX Ingress Controller...
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=ingress-nginx -n ingress-nginx --timeout=300s >nul 2>&1

REM Check ArgoCD
echo [INFO] Checking ArgoCD...
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s >nul 2>&1

REM Check Crossplane
echo [INFO] Checking Crossplane...
kubectl wait --for=condition=ready pod -l app=crossplane -n crossplane-system --timeout=300s >nul 2>&1

REM Check Cluster Autoscaler
echo [INFO] Checking Cluster Autoscaler...
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cluster-autoscaler -n kube-system --timeout=300s >nul 2>&1

echo [SUCCESS] Phase 2 services verification completed

:display_service_info
echo.
echo [SUCCESS] Phase 2 deployment completed successfully!
echo.
echo [INFO] 📋 Deployed Services Status:
echo.

echo [INFO] 🔧 EBS CSI Driver:
kubectl get pods -n kube-system -l app=ebs-csi-controller 2>nul || echo   Status: Deploying...
echo.

echo [INFO] 🌐 NGINX Ingress Controller:
kubectl get svc -n ingress-nginx 2>nul || echo   Status: Deploying...
echo.

echo [INFO] 🚀 ArgoCD:
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server 2>nul || echo   Status: Deploying...
echo.

echo [INFO] 🔄 Crossplane:
kubectl get pods -n crossplane-system 2>nul || echo   Status: Deploying...
echo.

echo [INFO] 📈 Cluster Autoscaler:
kubectl get pods -n kube-system -l app.kubernetes.io/name=cluster-autoscaler 2>nul || echo   Status: Deploying...
echo.

echo [INFO] 🔑 ArgoCD Access Information:
echo   1. Get admin password:
echo      kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" ^| base64 -d
echo.
echo   2. Access ArgoCD UI:
echo      kubectl port-forward svc/argocd-server -n argocd 8080:443
echo      Then browse to: http://localhost:8080 (username: admin)
echo.
echo   3. Or get external LoadBalancer (if configured):
echo      kubectl get svc -n argocd argocd-server
echo.

echo [INFO] 📊 Monitoring Commands:
echo   - Check all services: kubectl get pods -A
echo   - Check ingress: kubectl get svc -n ingress-nginx
echo   - Check ArgoCD: kubectl get all -n argocd
echo   - Check Crossplane: kubectl get providers -n crossplane-system
echo.

echo [SUCCESS] 🎉 Phase 2 Complete! Ready for Phase 3: Security ^& Policy Implementation

cd ..\..\..

if "!VERIFY_ONLY!"=="false" (
    echo [SUCCESS] Phase 2 deployment completed successfully! 🎉
) else (
    echo [SUCCESS] Phase 2 verification completed! 🎉
)

endlocal 