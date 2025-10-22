#!/bin/bash

# CloudAge Education App - EKS Setup Script
# This script automates the initial setup of AWS EKS cluster and resources
# Usage: ./setup-eks.sh

set -e

echo "🚀 CloudAge Education App - EKS Setup"
echo "======================================"
echo ""
echo "This script will:"
echo "1. Create EKS cluster"
echo "2. Setup IAM roles for service accounts"
echo "3. Create AWS resources (DynamoDB, S3, ECR)"
echo "4. Install Argo CD"
echo ""
read -p "Continue? (y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
fi

# Configuration
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID="992167236365"
CLUSTER_NAME="cloudage-cluster"
NODE_GROUP_NAME="cloudage-nodes"
SERVICE_ACCOUNT_NAME="cloudage-sa"
NAMESPACE="cloudage"
IAM_POLICY_NAME="CloudAgeEKSPodPolicy"
IAM_ROLE_NAME="cloudage-eks-pod-role"

echo ""
echo "📋 Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  AWS Account: $AWS_ACCOUNT_ID"
echo "  Cluster Name: $CLUSTER_NAME"
echo "  Namespace: $NAMESPACE"
echo ""

# Step 1: Create EKS Cluster
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📦 Step 1: Creating EKS Cluster (this takes ~10-15 minutes)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if eksctl get cluster --name $CLUSTER_NAME --region $AWS_REGION &>/dev/null; then
    echo "✅ Cluster $CLUSTER_NAME already exists"
else
    echo "Creating EKS cluster..."
    eksctl create cluster \
        --name $CLUSTER_NAME \
        --region $AWS_REGION \
        --nodegroup-name $NODE_GROUP_NAME \
        --node-type t3.medium \
        --nodes 2 \
        --nodes-min 2 \
        --nodes-max 4 \
        --managed
    echo "✅ EKS cluster created successfully"
fi

# Verify cluster
echo ""
echo "Verifying cluster..."
kubectl get nodes
echo ""

# Step 2: Setup IAM for Service Accounts
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔐 Step 2: Setting up IAM Roles for Service Accounts"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Associate OIDC provider
echo "Associating OIDC provider..."
eksctl utils associate-iam-oidc-provider \
    --cluster $CLUSTER_NAME \
    --region $AWS_REGION \
    --approve
echo "✅ OIDC provider associated"

# Create IAM policy
echo ""
echo "Creating IAM policy..."
if aws iam get-policy --policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} &>/dev/null; then
    echo "✅ IAM policy already exists"
else
    aws iam create-policy \
        --policy-name $IAM_POLICY_NAME \
        --policy-document file://docs/iam-policy.json
    echo "✅ IAM policy created"
fi

# Create service account with IAM role
echo ""
echo "Creating service account with IAM role..."
if kubectl get sa $SERVICE_ACCOUNT_NAME -n $NAMESPACE &>/dev/null; then
    echo "✅ Service account already exists"
else
    eksctl create iamserviceaccount \
        --name $SERVICE_ACCOUNT_NAME \
        --namespace $NAMESPACE \
        --cluster $CLUSTER_NAME \
        --region $AWS_REGION \
        --attach-policy-arn arn:aws:iam::${AWS_ACCOUNT_ID}:policy/${IAM_POLICY_NAME} \
        --role-name $IAM_ROLE_NAME \
        --approve
    echo "✅ Service account created"
fi

# Step 3: Create AWS Resources
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "☁️  Step 3: Creating AWS Resources"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Create DynamoDB tables
echo "Creating DynamoDB tables..."

if aws dynamodb describe-table --table-name assignments --region $AWS_REGION &>/dev/null; then
    echo "✅ DynamoDB table 'assignments' already exists"
else
    aws dynamodb create-table \
        --table-name assignments \
        --attribute-definitions AttributeName=id,AttributeType=S \
        --key-schema AttributeName=id,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region $AWS_REGION
    echo "✅ DynamoDB table 'assignments' created"
fi

if aws dynamodb describe-table --table-name answers --region $AWS_REGION &>/dev/null; then
    echo "✅ DynamoDB table 'answers' already exists"
else
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
        --region $AWS_REGION
    echo "✅ DynamoDB table 'answers' created"
fi

# Create S3 bucket
echo ""
echo "Creating S3 bucket..."
if aws s3 ls s3://mcq-project &>/dev/null; then
    echo "✅ S3 bucket 'mcq-project' already exists"
else
    aws s3 mb s3://mcq-project --region $AWS_REGION
    echo "✅ S3 bucket 'mcq-project' created"
fi

# Create ECR repository
echo ""
echo "Creating ECR repository..."
if aws ecr describe-repositories --repository-names cloudage-app --region $AWS_REGION &>/dev/null; then
    echo "✅ ECR repository 'cloudage-app' already exists"
else
    aws ecr create-repository --repository-name cloudage-app --region $AWS_REGION
    echo "✅ ECR repository 'cloudage-app' created"
fi

# Step 4: Install Argo CD
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 Step 4: Installing Argo CD"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

if kubectl get namespace argocd &>/dev/null; then
    echo "✅ Argo CD namespace already exists"
else
    echo "Creating Argo CD namespace..."
    kubectl create namespace argocd
    echo "✅ Namespace created"
fi

echo ""
echo "Installing Argo CD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo ""
echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
echo "✅ Argo CD installed successfully"

# Get Argo CD admin password
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔑 Argo CD Admin Credentials"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Username: admin"
echo -n "Password: "
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "💡 Save this password! You'll need it to access Argo CD UI"
echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Setup Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "📋 Next Steps:"
echo ""
echo "1. Configure GitHub Secrets:"
echo "   Go to: https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions"
echo "   Add: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY"
echo ""
echo "2. Deploy the application:"
echo "   kubectl apply -f argocd/application.yaml"
echo "   git push origin main"
echo ""
echo "3. Access Argo CD UI:"
echo "   kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "   Open: https://localhost:8080"
echo ""
echo "4. Get application URL (after deployment):"
echo "   ./scripts/get-app-url.sh"
echo ""
echo "📚 For detailed instructions, see:"
echo "   - QUICKSTART.md"
echo "   - DEPLOYMENT.md"
echo "   - DEPLOYMENT-CHECKLIST.md"
echo ""
