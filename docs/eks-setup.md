# AWS EKS Cluster Setup Guide

This guide walks you through setting up an AWS EKS cluster for the CloudAge Education App.

## Prerequisites

- AWS CLI installed and configured
- kubectl installed
- eksctl installed (recommended) or AWS Console access
- AWS account with appropriate permissions

## Option 1: Create EKS Cluster using eksctl (Recommended)

### Step 1: Install eksctl

```bash
# macOS
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl

# Linux
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin

# Windows (using Chocolatey)
choco install eksctl
```

### Step 2: Create EKS Cluster

```bash
eksctl create cluster \
  --name cloudage-cluster \
  --region us-east-1 \
  --nodegroup-name cloudage-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed
```

This command will:
- Create a VPC with public and private subnets
- Create an EKS cluster named `cloudage-cluster`
- Create a managed node group with 2-4 t3.medium instances
- Configure kubectl automatically

### Step 3: Verify Cluster

```bash
kubectl get nodes
kubectl get namespaces
```

## Option 2: Create EKS Cluster using AWS Console

1. Go to AWS EKS Console
2. Click "Create cluster"
3. Configure cluster:
   - Name: `cloudage-cluster`
   - Kubernetes version: 1.28 or later
   - Cluster service role: Create new or use existing
4. Configure networking:
   - VPC: Use default or create new
   - Subnets: Select at least 2 subnets in different AZs
   - Security groups: Use default
5. Configure logging (optional)
6. Review and create
7. Wait for cluster to be active (10-15 minutes)
8. Create node group:
   - Name: `cloudage-nodes`
   - Instance type: t3.medium
   - Desired size: 2
   - Min size: 2
   - Max size: 4

### Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name cloudage-cluster
```

## Step 4: Create IAM Role for Service Accounts (IRSA)

### Create OIDC Provider

```bash
eksctl utils associate-iam-oidc-provider \
  --cluster cloudage-cluster \
  --region us-east-1 \
  --approve
```

### Create IAM Policy

```bash
aws iam create-policy \
  --policy-name CloudAgeEKSPodPolicy \
  --policy-document file://docs/iam-policy.json
```

### Create IAM Role and Service Account

```bash
eksctl create iamserviceaccount \
  --name cloudage-sa \
  --namespace cloudage \
  --cluster cloudage-cluster \
  --region us-east-1 \
  --attach-policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy \
  --role-name cloudage-eks-pod-role \
  --approve
```

**Note**: This will automatically create the service account in Kubernetes and link it to the IAM role.

## Step 5: Create AWS Resources

### Create DynamoDB Tables

```bash
# Create assignments table
aws dynamodb create-table \
  --table-name assignments \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# Create answers table with GSI
aws dynamodb create-table \
  --table-name answers \
  --attribute-definitions \
    AttributeName=student_id,AttributeType=S \
    AttributeName=assignment_question_id,AttributeType=S \
    AttributeName=score,AttributeType=N \
  --key-schema \
    AttributeName=student_id,KeyType=HASH \
    AttributeName=assignment_question_id,KeyType=RANGE \
  --global-secondary-indexes \
    "IndexName=assignment_question_id-index,KeySchema=[{AttributeName=assignment_question_id,KeyType=HASH},{AttributeName=score,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Create S3 Bucket

```bash
aws s3 mb s3://mcq-project --region us-east-1
```

## Step 6: Verify Setup

```bash
# Check cluster status
kubectl cluster-info

# Check nodes
kubectl get nodes

# Check service account
kubectl get sa cloudage-sa -n cloudage

# Describe service account to see IAM role annotation
kubectl describe sa cloudage-sa -n cloudage
```

## Troubleshooting

### Issue: kubectl cannot connect to cluster

```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cloudage-cluster

# Verify AWS credentials
aws sts get-caller-identity
```

### Issue: Nodes not joining cluster

- Check security groups allow communication
- Verify IAM role has required permissions
- Check node group status in AWS Console

### Issue: Service account not working

```bash
# Verify OIDC provider
aws eks describe-cluster --name cloudage-cluster --query "cluster.identity.oidc.issuer" --output text

# Check IAM role trust relationship
aws iam get-role --role-name cloudage-eks-pod-role
```

## Cleanup

To delete the cluster and all resources:

```bash
# Delete the cluster (this will also delete node groups)
eksctl delete cluster --name cloudage-cluster --region us-east-1

# Delete IAM policy
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy

# Delete DynamoDB tables
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1

# Delete S3 bucket (must be empty first)
aws s3 rb s3://mcq-project --force --region us-east-1
```

## Next Steps

After setting up the EKS cluster, proceed to:
1. [Argo CD Setup](argocd-setup.md)
2. [GitHub Secrets Configuration](github-secrets.md)
3. Deploy the application by pushing to GitHub
