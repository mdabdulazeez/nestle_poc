@echo off
REM Nestle PoC Infrastructure Deployment Script for Windows
REM This script automates the deployment of the multi-regional EKS infrastructure

setlocal enabledelayedexpansion

REM Default values
set AWS_REGION_PRIMARY=us-east-1
set AWS_REGION_SECONDARY=eu-west-1
set ENVIRONMENT=dev
set PROJECT_NAME=nestle-poc
set SKIP_BACKEND=false
set AUTO_APPROVE=false

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
if "%~1"=="--skip-backend" (
    set SKIP_BACKEND=true
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
echo   --skip-backend                 Skip Terraform backend setup
echo   --auto-approve                 Auto-approve Terraform plans
echo   -h, --help                     Show this help message
echo.
echo Examples:
echo   %0                             # Deploy with default settings
echo   %0 -p us-west-2 -s eu-central-1  # Deploy to different regions
echo   %0 --skip-backend --auto-approve  # Skip backend and auto-approve
exit /b 0

:start_deployment
echo ==================================================
echo 🚀 Nestle PoC Infrastructure Deployment
echo ==================================================
echo.
echo [INFO] Configuration:
echo   Primary Region: !AWS_REGION_PRIMARY!
echo   Secondary Region: !AWS_REGION_SECONDARY!
echo   Environment: !ENVIRONMENT!
echo   Project Name: !PROJECT_NAME!
echo   Skip Backend: !SKIP_BACKEND!
echo   Auto Approve: !AUTO_APPROVE!
echo.

REM Check prerequisites
echo [INFO] Checking prerequisites...

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

echo [SUCCESS] All prerequisites satisfied

REM Setup Terraform backend
if "!SKIP_BACKEND!"=="false" (
    echo [INFO] Setting up Terraform backend...
    
    if not exist "terraform\backend" (
        echo [ERROR] Backend directory not found: terraform\backend
        exit /b 1
    )
    
    cd terraform\backend
    
    terraform init
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to initialize Terraform backend
        exit /b 1
    )
    
    terraform plan -var="aws_region=!AWS_REGION_PRIMARY!"
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to plan Terraform backend
        exit /b 1
    )
    
    if "!AUTO_APPROVE!"=="true" (
        terraform apply -auto-approve -var="aws_region=!AWS_REGION_PRIMARY!"
    ) else (
        terraform apply -var="aws_region=!AWS_REGION_PRIMARY!"
    )
    
    if !errorlevel! neq 0 (
        echo [ERROR] Failed to apply Terraform backend
        exit /b 1
    )
    
    REM Get backend configuration
    for /f "delims=" %%i in ('terraform output -raw s3_bucket_name') do set TF_BACKEND_BUCKET=%%i
    for /f "delims=" %%i in ('terraform output -raw dynamodb_table_name') do set TF_BACKEND_DYNAMODB_TABLE=%%i
    
    echo [SUCCESS] Backend setup completed
    echo [INFO] S3 Bucket: !TF_BACKEND_BUCKET!
    echo [INFO] DynamoDB Table: !TF_BACKEND_DYNAMODB_TABLE!
    
    cd ..\..
) else (
    echo [INFO] Skipping backend setup as requested
)

REM Deploy infrastructure
echo [INFO] Deploying infrastructure...

if not exist "terraform\environments\!ENVIRONMENT!" (
    echo [ERROR] Environment directory not found: terraform\environments\!ENVIRONMENT!
    exit /b 1
)

cd terraform\environments\!ENVIRONMENT!

REM Initialize with backend configuration if available
if defined TF_BACKEND_BUCKET (
    echo [INFO] Initializing with remote backend...
    terraform init ^
        -backend-config="bucket=!TF_BACKEND_BUCKET!" ^
        -backend-config="key=!ENVIRONMENT!/terraform.tfstate" ^
        -backend-config="region=!AWS_REGION_PRIMARY!" ^
        -backend-config="dynamodb_table=!TF_BACKEND_DYNAMODB_TABLE!" ^
        -backend-config="encrypt=true"
) else (
    echo [INFO] Initializing with local backend...
    terraform init
)

if !errorlevel! neq 0 (
    echo [ERROR] Failed to initialize Terraform
    exit /b 1
)

REM Plan deployment
terraform plan ^
    -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
    -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
    -var="environment=!ENVIRONMENT!" ^
    -var="project_name=!PROJECT_NAME!"

if !errorlevel! neq 0 (
    echo [ERROR] Failed to plan infrastructure deployment
    exit /b 1
)

REM Apply deployment
if "!AUTO_APPROVE!"=="true" (
    terraform apply -auto-approve ^
        -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
        -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
        -var="environment=!ENVIRONMENT!" ^
        -var="project_name=!PROJECT_NAME!"
) else (
    terraform apply ^
        -var="aws_region_primary=!AWS_REGION_PRIMARY!" ^
        -var="aws_region_secondary=!AWS_REGION_SECONDARY!" ^
        -var="environment=!ENVIRONMENT!" ^
        -var="project_name=!PROJECT_NAME!"
)

if !errorlevel! neq 0 (
    echo [ERROR] Failed to apply infrastructure deployment
    exit /b 1
)

echo [SUCCESS] Infrastructure deployment completed

REM Configure kubectl
echo [INFO] Configuring kubectl for both clusters...

REM Get cluster names from Terraform output
for /f "tokens=4 delims=:" %%i in ('terraform output -json primary_cluster_info ^| findstr "cluster_name"') do (
    set temp=%%i
    set temp=!temp:"=!
    set temp=!temp:,=!
    set primary_cluster=!temp!
)

for /f "tokens=4 delims=:" %%i in ('terraform output -json secondary_cluster_info ^| findstr "cluster_name"') do (
    set temp=%%i
    set temp=!temp:"=!
    set temp=!temp:,=!
    set secondary_cluster=!temp!
)

REM Configure kubectl for both clusters
aws eks update-kubeconfig --region !AWS_REGION_PRIMARY! --name !primary_cluster!
aws eks update-kubeconfig --region !AWS_REGION_SECONDARY! --name !secondary_cluster!

REM Test connectivity
echo [INFO] Testing cluster connectivity...
kubectl get nodes >nul 2>&1
if !errorlevel! equ 0 (
    echo [SUCCESS] kubectl configured successfully
    kubectl get nodes
) else (
    echo [WARNING] kubectl configuration may have issues
)

cd ..\..\..

REM Display next steps
echo.
echo [SUCCESS] Deployment completed successfully!
echo.
echo [INFO] Next steps:
echo 1. Review the Terraform outputs for cluster information
echo 2. Proceed with Phase 2: Deploy EKS add-ons
echo 3. Setup ArgoCD and GitOps workflow
echo 4. Deploy applications (Jenkins, SonarQube, Kyverno)
echo.
echo [INFO] Useful commands:
echo - View Terraform outputs: cd terraform\environments\!ENVIRONMENT! ^&^& terraform output
echo - List contexts: kubectl config get-contexts
echo - Switch context: kubectl config use-context ^<context-name^>
echo - View nodes: kubectl get nodes
echo - View all pods: kubectl get pods -A

echo.
echo [SUCCESS] All phases completed successfully! 🎉

endlocal 