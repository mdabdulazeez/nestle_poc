# DevOps PoC Architecture & Design

## Overall Architecture

### High-Level Design
```
┌─────────────────┐    ┌─────────────────┐
│   US-East-1     │    │   EU-West-1     │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │ EKS Cluster │ │    │ │ EKS Cluster │ │
│ │             │ │    │ │             │ │
│ │ - ArgoCD    │ │    │ │ - ArgoCD    │ │
│ │ - Jenkins   │ │    │ │ - Apps      │ │
│ │ - SonarQube │ │    │ │             │ │
│ │ - Kyverno   │ │    │ │             │ │
│ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │
│ ┌─────────────┐ │    │ ┌─────────────┐ │
│ │    ECR      │◄┼────┼►│    ECR      │ │
│ │ (Primary)   │ │    │ │ (Replica)   │ │
│ └─────────────┘ │    │ └─────────────┘ │
│                 │    │                 │
│ ┌─────────────┐ │    │                 │
│ │    RDS      │ │    │                 │
│ │ (SonarQube) │ │    │                 │
│ └─────────────┘ │    │                 │
└─────────────────┘    └─────────────────┘
```

## Infrastructure Design

### 1. Network Architecture
- **VPC Design**: 
  - Separate VPCs per region
  - Public/Private subnet architecture
  - NAT Gateways for private subnet internet access
  - VPC Peering for cross-region communication (if needed)
- **Security Groups**: 
  - Principle of least privilege
  - Application-specific rules
  - Database access restrictions

### 2. EKS Cluster Design
- **Control Plane**: 
  - Multi-AZ deployment
  - Private endpoint access
  - Audit logging enabled
- **Worker Nodes**: 
  - Managed node groups
  - Auto Scaling enabled
  - Mixed instance types for cost optimization
- **Node Groups**: 
  - System nodes (CoreDNS, kube-proxy)
  - Application nodes (Jenkins, SonarQube)
  - Spot instances for non-critical workloads

### 3. Storage Architecture
- **EBS Volumes**: 
  - gp3 type for performance/cost balance
  - Encryption at rest
  - Automated backup via snapshots
- **RDS**: 
  - PostgreSQL for SonarQube
  - Multi-AZ for high availability
  - Encrypted storage
  - Automated backups with 7-day retention

## Application Architecture

### 1. GitOps Workflow
```
Developer → Git Repository → ArgoCD → Kubernetes Cluster
```
- **Git Repository Structure**:
  ```
  gitops-repo/
  ├── applications/
  │   ├── jenkins/
  │   ├── sonarqube/
  │   └── kyverno/
  ├── infrastructure/
  │   ├── crossplane/
  │   └── policies/
  └── argocd/
      └── applications/
  ```

### 2. Security Policy Implementation
- **Kyverno Policies**:
  - Cluster-wide policy enforcement
  - Validation and mutation rules
  - Policy exceptions for system components
- **Pod Security Standards**:
  - Restricted profile for applications
  - Baseline profile for system components

### 3. Crossplane Resource Management
- **Compositions**: 
  - EBS Volume Composition
  - RDS Instance Composition
- **Claims**: 
  - Application-specific resource requests
  - Automatic provisioning workflow

## Technology Stack

### Infrastructure as Code
- **Terraform**: 
  - AWS Provider
  - Kubernetes Provider
  - Helm Provider
  - Remote state in S3 with DynamoDB locking
- **Modules**: 
  - terraform-aws-eks
  - terraform-aws-vpc
  - terraform-aws-ecr

### Kubernetes Ecosystem
- **Container Runtime**: containerd
- **CNI**: Amazon VPC CNI
- **Ingress**: NGINX Ingress Controller
- **Storage**: EBS CSI Driver
- **DNS**: CoreDNS

### GitOps and CI/CD
- **ArgoCD**: Application deployment and sync
- **Kyverno**: Policy as Code enforcement
- **Helm**: Package management

## Security Design

### 1. Cluster Security
- **RBAC**: 
  - Service account per application
  - Namespace-based isolation
  - Minimal required permissions
- **Network Policies**: 
  - Default deny-all
  - Application-specific allow rules
- **Pod Security**: 
  - Read-only root filesystem
  - No privilege escalation
  - Resource limits enforcement

### 2. Data Security
- **Encryption**: 
  - EBS volumes encrypted
  - RDS encryption at rest
  - Secrets encryption in etcd
- **Access Control**: 
  - IAM roles for service accounts
  - Database user isolation
  - ECR repository policies

## Deployment Strategy

### Phase 1: Foundation Infrastructure
1. Terraform state backend setup
2. VPC and networking
3. EKS cluster deployment
4. Core add-ons installation

### Phase 2: Platform Services
1. ECR registry setup
2. ArgoCD installation
3. Crossplane deployment
4. Security policy implementation

### Phase 3: Application Deployment
1. Jenkins deployment with persistent storage
2. SonarQube with RDS backend
3. Kyverno policy enforcement
4. Application testing and validation

### Phase 4: Multi-Region Setup
1. Secondary region infrastructure
2. ECR cross-region replication
3. ArgoCD multi-cluster setup
4. Disaster recovery testing

## Monitoring and Observability

### Basic Monitoring Stack
- **Kubernetes Metrics**: kube-state-metrics
- **Node Metrics**: node-exporter
- **Application Metrics**: Prometheus annotations
- **Logging**: AWS CloudWatch Container Insights

## Cost Optimization

### Resource Optimization
- **Spot Instances**: For non-critical workloads
- **Right-sizing**: Appropriate instance types
- **Auto-scaling**: Horizontal Pod Autoscaler
- **Storage**: Lifecycle policies for EBS snapshots

### Tagging Strategy
- Environment: dev/staging/prod
- Project: nestle-poc
- Owner: devops-team
- Cost-center: specific allocation 