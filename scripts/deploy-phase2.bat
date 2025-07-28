@echo off
REM Nestle PoC Phase 2: EKS Add-ons Deployment Script for Windows
REM This script automates the deployment of EKS add-ons and platform services

setlocal enabledelayedexpansion

REM Default values
set AWS_REGION_PRIMARY=us-east-1
set AWS_REGION_SECONDARY=eu-west-1
set ENVIRONMENT=dev
set PROJECT_NAME=nestle-poc
set AUTO_APPROVE=false
set BACKEND_BUCKET=

REM Parse command line arguments
:parse_args
if "%~1"=="" goto :start_deployment
if "%~1"=="-p" (
    set AWS_REGION_PRIMARY=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="--primary-region" (
    set AWS_REGION_PRIMARY=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="-s" (
    set AWS_REGION_SECONDARY=%~2
    shift
    shift
    goto :parse_args
)
if "%~1"=="--secondary-region" (
    set AWS_REGION_SECONDARY=%~2
    shift
    shift
    goto :parse_args
)
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
if "%~1"=="-h" goto :show_help
if "%~1"=="--help" goto :show_help
echo [ERROR] Unknown option: %~1
goto :show_help

:show_help
echo Usage: %0 [OPTIONS]
echo.
echo Options:
echo   -p, --primary-region REGION    Primary AWS region (default: us-east-1)
echo   -s, --secondary-region REGION  Secondary AWS region (default: eu-west-1)
echo   -e, --environment ENV          Environment name (default: dev)
echo   --auto-approve                 Auto-approve Terraform plans
echo   -h, --help                     Show this help message
echo.
echo Examples:
echo   %0                             # Deploy with default settings
echo   %0 -p us-west-2 -s eu-central-1  # Deploy to different regions
echo   %0 --auto-approve              # Auto-approve deployment
exit /b 0

:start_deployment
echo ==================================================
echo 🚀 Nestle PoC Phase 2: EKS Add-ons Deployment
echo ==================================================
echo.
echo [INFO] Configuration:
echo   Primary Region: !AWS_REGION_PRIMARY!
echo   Secondary Region: !AWS_REGION_SECONDARY!
echo   Environment: !ENVIRONMENT!
echo   Project Name: !PROJECT_NAME!
echo   Auto Approve: !AUTO_APPROVE!
echo.

REM Check prerequisites
echo [INFO] Checking prerequisites for Phase 2 deployment...

REM Check if Terraform is installed
terraform version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Terraform is not installed or not in PATH
    echo Please install Terraform and try again
    exit /b 1
)

REM Check if AWS CLI is installed
aws --version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] AWS CLI is not installed or not in PATH
    echo Please install AWS CLI and try again
    exit /b 1
)

REM Check if kubectl is installed
kubectl version --client >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] kubectl is not installed or not in PATH
    echo Please install kubectl and try again
    exit /b 1
)

REM Check if Helm is installed
helm version >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Helm is not installed or not in PATH
    echo Please install Helm and try again
    exit /b 1
)

REM Check AWS credentials
aws sts get-caller-identity >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] AWS credentials not configured or invalid
    echo Please configure AWS credentials using 'aws configure'
    exit /b 1
)

REM Check if Phase 1 infrastructure exists
echo [INFO] Verifying Phase 1 infrastructure exists...
set primary_cluster=!PROJECT_NAME!-!ENVIRONMENT!-primary
aws eks describe-cluster --name !primary_cluster! --region !AWS_REGION_PRIMARY! >nul 2>&1
if !errorlevel! neq 0 (
    echo [ERROR] Phase 1 infrastructure not found. EKS cluster '!primary_cluster!' does not exist.
    echo Please deploy Phase 1 infrastructure first using the main deployment script.
    exit /b 1
)

echo [SUCCESS] Prerequisites satisfied and Phase 1 infrastructure verified

REM Get backend configuration from Phase 1
echo [INFO] Retrieving backend configuration from Phase 1...

if not exist "terraform\environments\dev" (
    echo [ERROR] Phase 1 directory not found: terraform\environments\dev
    echo Please ensure you're running this script from the project root
    exit /b 1
)

cd terraform\environments\dev

REM Try to get the backend bucket from terraform output
for /f "delims=" %%i in ('terraform output -raw s3_bucket_name 2^>nul') do set BACKEND_BUCKET=%%i

if "!BACKEND_BUCKET!"=="" (
    echo [ERROR] Could not retrieve backend bucket name from Phase 1 outputs
    echo Please ensure Phase 1 infrastructure is deployed and Terraform state is accessible
    exit /b 1
)

echo [SUCCESS] Backend bucket found: !BACKEND_BUCKET!

cd ..\..\..

REM Setup terraform variables
echo [INFO] Setting up Terraform variables for Phase 2...

if not exist "terraform\environments\addons\terraform.tfvars" (
    echo [INFO] Creating terraform.tfvars from example...
    copy "terraform\environments\addons\terraform.tfvars.example" "terraform\environments\addons\terraform.tfvars" >nul
    
    REM Update the backend bucket in terraform.tfvars
    powershell -Command "(Get-Content 'terraform\environments\addons\terraform.tfvars') -replace 'your-terraform-state-bucket-name-from-phase1', '!BACKEND_BUCKET!' | Set-Content 'terraform\environments\addons\terraform.tfvars'"
    
    echo [SUCCESS] Created terraform.tfvars with backend bucket: !BACKEND_BUCKET!
    echo [WARNING] Please review and customize terraform.tfvars as needed before proceeding
    
    if "!AUTO_APPROVE!"=="false" (
        pause
    )
) else (
    echo [INFO] Using existing terraform.tfvars
    
    REM Update backend bucket if it's still the placeholder
    findstr /C:"your-terraform-state-bucket-name-from-phase1" "terraform\environments\addons\terraform.tfvars" >nul
    if !errorlevel! equ 0 (
        powershell -Command "(Get-Content 'terraform\environments\addons\terraform.tfvars') -replace 'your-terraform-state-bucket-name-from-phase1', '!BACKEND_BUCKET!' | Set-Content 'terraform\environments\addons\terraform.tfvars'"
        echo [INFO] Updated backend bucket in terraform.tfvars
    )
)

REM Deploy Phase 2 add-ons
echo [INFO] Deploying Phase 2: EKS Add-ons and Platform Services...

if not exist "terraform\environments\addons" (
    echo [ERROR] Add-ons directory not found: terraform\environments\addons
    exit /b 1
)

cd terraform\environments\addons

REM Initialize with backend configuration
echo [INFO] Initializing Terraform with remote backend...

REM Calculate DynamoDB table name from bucket name
set DYNAMODB_TABLE=!BACKEND_BUCKET:terraform-state=terraform-locks!

terraform init ^
    -backend-config="bucket=!BACKEND_BUCKET!" ^
    -backend-config="key=addons/terraform.tfstate" ^
    -backend-config="region=!AWS_REGION_PRIMARY!" ^
    -backend-config="dynamodb_table=!DYNAMODB_TABLE!" ^
    -backend-config="encrypt=true"

if !errorlevel! neq 0 (
    echo [ERROR] Failed to initialize Terraform
    exit /b 1
)

REM Plan deployment
echo [INFO] Planning add-ons deployment...
terraform plan ^
    -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
    -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
    -var="environment=!ENVIRONMENT!" ^
    -var="project_name=!PROJECT_NAME!" ^
    -var="backend_bucket=!BACKEND_BUCKET!"

if !errorlevel! neq 0 (
    echo [ERROR] Failed to plan add-ons deployment
    exit /b 1
)

REM Apply deployment
echo [INFO] Applying add-ons deployment...
if "!AUTO_APPROVE!"=="true" (
    terraform apply -auto-approve ^
        -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
        -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
        -var="environment=!ENVIRONMENT!" ^
        -var="project_name=!PROJECT_NAME!" ^
        -var="backend_bucket=!BACKEND_BUCKET!"
) else (
    terraform apply ^
        -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
        -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
        -var="environment=!ENVIRONMENT!" ^
        -var="project_name=!PROJECT_NAME!" ^
        -var="backend_bucket=!BACKEND_BUCKET!"
)

if !errorlevel! neq 0 (
    echo [ERROR] Failed to apply add-ons deployment
    exit /b 1
)

echo [SUCCESS] Phase 2 add-ons deployment completed

cd ..\..\..

REM Verify deployment
echo [INFO] Verifying Phase 2 deployment...

REM Configure kubectl for primary cluster
set primary_cluster=!PROJECT_NAME!-!ENVIRONMENT!-primary
aws eks update-kubeconfig --region !AWS_REGION_PRIMARY! --name !primary_cluster! --alias primary

REM Check if add-ons are running
echo [INFO] Checking add-on status...

REM Check EBS CSI Driver
kubectl get pods -n kube-system -l app=ebs-csi-controller >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] ✅ EBS CSI Driver is running
) else (
    echo [WARNING] ⚠️  EBS CSI Driver pods not found
)

REM Check NGINX Ingress
kubectl get pods -n ingress-nginx >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] ✅ NGINX Ingress Controller is running
) else (
    echo [WARNING] ⚠️  NGINX Ingress Controller pods not found
)

REM Check ArgoCD
kubectl get pods -n argocd >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] ✅ ArgoCD is running
) else (
    echo [WARNING] ⚠️  ArgoCD pods not found
)

REM Check Crossplane
kubectl get pods -n crossplane-system >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] ✅ Crossplane is running
) else (
    echo [WARNING] ⚠️  Crossplane pods not found
)

REM Check Cluster Autoscaler
kubectl get pods -n kube-system -l app=cluster-autoscaler >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] ✅ Cluster Autoscaler is running
) else (
    echo [WARNING] ⚠️  Cluster Autoscaler pods not found
)

REM Display access information
echo.
echo [SUCCESS] Phase 2 deployment completed successfully!
echo.
echo [INFO] 🔗 Access Information:
echo.
echo 📋 ArgoCD Access:
echo    Port-forward: kubectl port-forward svc/argocd-server -n argocd 8080:443
echo    URL: https://localhost:8080
echo    Username: admin
echo    Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" ^| base64 -d
echo.
echo 🌐 NGINX Ingress Load Balancer:
echo    Status: kubectl get svc ingress-nginx-controller -n ingress-nginx
echo.
echo 📦 Crossplane Providers:
echo    Status: kubectl get providers -n crossplane-system
echo.
echo 💾 Storage Classes:
echo    List: kubectl get storageclass
echo.
echo [INFO] 🚀 Next Steps (Phase 3):
echo 1. Deploy Kyverno security policies
echo 2. Create Crossplane compositions for EBS and RDS
echo 3. Configure ArgoCD applications and repositories
echo 4. Deploy Jenkins and SonarQube via GitOps
echo.
echo [INFO] 📊 Health Check Commands:
echo    All pods: kubectl get pods -A
echo    Nodes: kubectl get nodes
echo    Add-on status: kubectl get pods -n kube-system,ingress-nginx,argocd,crossplane-system

echo.
echo [SUCCESS] 🎉 Phase 2 deployment completed successfully!

endlocal 