# Design Document

## Overview

This design outlines a complete CI/CD pipeline for deploying the CloudAge Education App to AWS EKS using GitHub Actions, Docker, Amazon ECR, and Argo CD. The solution follows GitOps principles, ensuring that the desired state of the application is declaratively defined in Git and automatically synchronized to the Kubernetes cluster.

## Architecture

### High-Level Flow

```
Developer Push → GitHub → GitHub Actions → Docker Build → ECR Push → 
Update Manifests → Argo CD Sync → EKS Deployment → LoadBalancer URL
```

### Components

1. **Source Control**: GitHub repository with application code and Kubernetes manifests
2. **CI/CD Pipeline**: GitHub Actions workflows for automated builds and deployments
3. **Container Registry**: Amazon ECR for storing Docker images
4. **Orchestration**: AWS EKS cluster running Kubernetes workloads
5. **GitOps Tool**: Argo CD for declarative continuous delivery
6. **AWS Services**: DynamoDB, S3, Bedrock (accessed via IAM roles)

## Components and Interfaces

### 1. GitHub Repository Structure

```
eks-python-deployment/
├── .github/
│   └── workflows/
│       ├── build-and-push.yml       # Build Docker image and push to ECR
│       └── deploy.yml                # Update manifests and trigger Argo CD
├── k8s/
│   ├── namespace.yaml                # Kubernetes namespace
│   ├── configmap.yaml                # Application configuration
│   ├── secret.yaml                   # Sensitive data (template)
│   ├── serviceaccount.yaml           # Service account with IAM role
│   ├── deployment.yaml               # Application deployment
│   └── service.yaml                  # LoadBalancer service
├── argocd/
│   └── application.yaml              # Argo CD application definition
├── components/
│   ├── Parameter_store.py
│   └── ui_template.py
├── pages/
│   ├── 1_Create_Assignments.py
│   ├── 2_Show_Assignments.py
│   └── 3_Complete_Assignments.py
├── Home.py
├── requirements.txt
├── Dockerfile
├── .dockerignore
├── .gitignore
└── README.md
```

### 2. Docker Image Strategy

**Base Image**: `public.ecr.aws/docker/library/python:3.9.18-slim`

**Optimization Techniques**:
- Multi-stage builds to reduce image size
- Layer caching for faster builds
- Non-root user for security
- Health check endpoint

**Tagging Strategy**:
- `latest`: Most recent build
- `v{version}`: Semantic versioning (e.g., v1.0.0)
- `{git-sha}`: Commit-specific tags for traceability

### 3. Amazon ECR Configuration

**Repository Details**:
- Name: `cloudage-app`
- Region: `us-east-1`
- Lifecycle Policy: Keep last 10 images, delete untagged after 7 days
- Scan on Push: Enabled for vulnerability detection

**Authentication**:
- GitHub Actions uses AWS credentials stored in GitHub Secrets
- EKS nodes use IAM roles to pull images

### 4. AWS EKS Cluster Setup

**Cluster Configuration**:
- Kubernetes Version: 1.28+
- Node Group: t3.medium instances (2 vCPUs, 4GB RAM)
- Auto-scaling: 2-4 nodes
- VPC: Default VPC with public subnets
- Add-ons: VPC CNI, CoreDNS, kube-proxy

**IAM Roles for Service Accounts (IRSA)**:
- Service Account: `cloudage-sa`
- IAM Role: `cloudage-eks-pod-role`
- Permissions: DynamoDB, S3, Bedrock access

### 5. Kubernetes Manifests Design

#### Namespace
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: cloudage
```

#### ConfigMap
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudage-config
  namespace: cloudage
data:
  ASSIGNMENTS_TABLE: "assignments"
  AWS_REGION: "us-east-1"
  BEDROCK_MODEL_ID: "amazon.nova-canvas-v1:0"
  S3_BUCKET: "mcq-project"
```

#### Deployment
- Replicas: 2 (for high availability)
- Resource Limits: 500m CPU, 1Gi memory
- Resource Requests: 250m CPU, 512Mi memory
- Liveness Probe: HTTP GET on port 80
- Readiness Probe: HTTP GET on port 80
- Rolling Update Strategy: maxSurge 1, maxUnavailable 0

#### Service
- Type: LoadBalancer
- Port: 80
- Target Port: 80
- Health Check: Enabled

### 6. Argo CD Configuration

**Installation**:
- Namespace: `argocd`
- Access: LoadBalancer service or Ingress
- Authentication: Admin password

**Application Definition**:
```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: cloudage-app
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/{username}/eks-python-deployment
    targetRevision: main
    path: k8s
  destination:
    server: https://kubernetes.default.svc
    namespace: cloudage
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

### 7. GitHub Actions Workflows

#### Workflow 1: Build and Push (`build-and-push.yml`)

**Triggers**: Push to main branch, pull request

**Steps**:
1. Checkout code
2. Configure AWS credentials
3. Login to Amazon ECR
4. Extract metadata (tags, labels)
5. Build Docker image
6. Scan image for vulnerabilities
7. Push to ECR
8. Output image tag

#### Workflow 2: Deploy (`deploy.yml`)

**Triggers**: Completion of build-and-push workflow

**Steps**:
1. Checkout code
2. Update deployment.yaml with new image tag
3. Commit and push changes
4. Trigger Argo CD sync (optional)
5. Wait for deployment to be healthy
6. Retrieve LoadBalancer URL
7. Post URL as comment or output

## Data Models

### Environment Variables

**Application Configuration**:
- `ASSIGNMENTS_TABLE`: DynamoDB table name
- `AWS_REGION`: AWS region for services
- `BEDROCK_MODEL_ID`: Bedrock model identifier
- `S3_BUCKET`: S3 bucket for image storage

**GitHub Secrets** (Required):
- `AWS_ACCESS_KEY_ID`: AWS access key for ECR/EKS access
- `AWS_SECRET_ACCESS_KEY`: AWS secret key
- `AWS_ACCOUNT_ID`: AWS account ID
- `EKS_CLUSTER_NAME`: Name of the EKS cluster
- `ECR_REPOSITORY`: ECR repository name

### IAM Policy for EKS Pods

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:Scan",
        "dynamodb:Query"
      ],
      "Resource": [
        "arn:aws:dynamodb:us-east-1:*:table/assignments",
        "arn:aws:dynamodb:us-east-1:*:table/answers"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::mcq-project",
        "arn:aws:s3:::mcq-project/*"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "bedrock:InvokeModel",
        "bedrock:InvokeModelWithResponseStream"
      ],
      "Resource": "arn:aws:bedrock:us-east-1::foundation-model/*"
    }
  ]
}
```

## Error Handling

### Build Failures
- GitHub Actions will fail the workflow and notify via email
- Logs available in GitHub Actions UI
- Retry mechanism for transient ECR push failures

### Deployment Failures
- Argo CD will show sync status and error messages
- Kubernetes events logged for troubleshooting
- Automatic rollback to previous version if health checks fail
- Slack/email notifications for deployment status

### Runtime Errors
- Application logs available via `kubectl logs`
- CloudWatch integration for centralized logging
- Prometheus/Grafana for monitoring (optional)

## Testing Strategy

### Pre-Deployment Testing
1. **Dockerfile Validation**: Ensure Docker builds successfully locally
2. **Manifest Validation**: Use `kubectl apply --dry-run` to validate YAML
3. **Security Scanning**: Scan Docker images with Trivy or AWS ECR scanning
4. **Linting**: Use yamllint for Kubernetes manifests

### Post-Deployment Testing
1. **Health Checks**: Verify liveness and readiness probes pass
2. **Connectivity**: Test LoadBalancer URL accessibility
3. **Functionality**: Run smoke tests on deployed application
4. **Resource Usage**: Monitor CPU and memory consumption

## Implementation Phases

### Phase 1: Repository Setup
- Initialize GitHub repository
- Add .gitignore and .dockerignore
- Create directory structure
- Push initial code

### Phase 2: Kubernetes Manifests
- Create namespace, configmap, secret templates
- Define deployment with resource limits
- Create LoadBalancer service
- Set up service account with IAM role

### Phase 3: GitHub Actions Workflows
- Create build-and-push workflow
- Create deploy workflow
- Configure GitHub Secrets
- Test workflows with manual triggers

### Phase 4: EKS Cluster Setup
- Create EKS cluster via AWS Console or eksctl
- Configure kubectl access
- Set up IAM roles for service accounts
- Create necessary AWS resources (DynamoDB, S3)

### Phase 5: Argo CD Installation
- Install Argo CD on EKS cluster
- Configure Argo CD CLI access
- Create application definition
- Connect to GitHub repository

### Phase 6: End-to-End Testing
- Push code changes to trigger pipeline
- Verify Docker image in ECR
- Confirm Argo CD syncs deployment
- Access application via LoadBalancer URL
- Test all application features

## Security Considerations

1. **Secrets Management**: Use Kubernetes Secrets and AWS Secrets Manager
2. **Network Policies**: Restrict pod-to-pod communication
3. **RBAC**: Implement role-based access control for Kubernetes
4. **Image Scanning**: Enable ECR vulnerability scanning
5. **TLS/SSL**: Configure HTTPS with AWS Certificate Manager
6. **Pod Security**: Run containers as non-root user
7. **IAM Least Privilege**: Grant minimal required permissions

## Monitoring and Observability

1. **Logs**: CloudWatch Logs or EFK stack (Elasticsearch, Fluentd, Kibana)
2. **Metrics**: Prometheus and Grafana for cluster and app metrics
3. **Tracing**: AWS X-Ray for distributed tracing
4. **Alerts**: CloudWatch Alarms or Prometheus Alertmanager
5. **Dashboards**: Kubernetes Dashboard or Lens IDE

## Success Criteria

The deployment will be considered successful when:
1. GitHub Actions workflows execute without errors
2. Docker images are successfully pushed to ECR
3. Argo CD syncs and deploys the application to EKS
4. Application pods are running and healthy
5. LoadBalancer URL is accessible and application functions correctly
6. All AWS services (DynamoDB, S3, Bedrock) are accessible from pods
7. Automated deployments work on subsequent code pushes