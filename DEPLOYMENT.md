# Complete Deployment Guide - Single Push to EKS

This guide provides step-by-step instructions to deploy the CloudAge Education App to AWS EKS with a single push using GitHub Actions and Argo CD.

## 🎯 Overview

After initial setup, every code push to GitHub will automatically:
1. Build Docker image
2. Push to Amazon ECR
3. Update Kubernetes manifests
4. Deploy to EKS via Argo CD

## ⚡ Quick Deployment (15 minutes)

### Prerequisites Check

```bash
# Verify AWS CLI
aws --version

# Verify kubectl
kubectl version --client

# Verify eksctl
eksctl version

# Verify Docker
docker --version

# Verify Git
git --version
```

### Step 1: Create EKS Cluster (10 minutes)

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

**Wait for completion** - This takes about 10-15 minutes.

### Step 2: Setup IAM for Pods (2 minutes)

```bash
# Associate OIDC provider
eksctl utils associate-iam-oidc-provider \
  --cluster cloudage-cluster \
  --region us-east-1 \
  --approve

# Create IAM policy
aws iam create-policy \
  --policy-name CloudAgeEKSPodPolicy \
  --policy-document file://docs/iam-policy.json

# Create service account with IAM role
eksctl create iamserviceaccount \
  --name cloudage-sa \
  --namespace cloudage \
  --cluster cloudage-cluster \
  --region us-east-1 \
  --attach-policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy \
  --role-name cloudage-eks-pod-role \
  --approve
```

### Step 3: Create AWS Resources (1 minute)

```bash
# DynamoDB tables
aws dynamodb create-table \
  --table-name assignments \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

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

# S3 bucket
aws s3 mb s3://mcq-project --region us-east-1

# ECR repository
aws ecr create-repository --repository-name cloudage-app --region us-east-1
```

### Step 4: Install Argo CD (2 minutes)

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
echo "Argo CD Admin Password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**Save the password!**

### Step 5: Configure GitHub (2 minutes)

#### Create IAM User for GitHub Actions

```bash
# Create user
aws iam create-user --user-name github-actions-cloudage

# Create and attach policy
cat > github-actions-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:DescribeRepositories",
        "ecr:ListImages"
      ],
      "Resource": "*"
    }
  ]
}
EOF

aws iam create-policy \
  --policy-name GitHubActionsCloudAgePolicy \
  --policy-document file://github-actions-policy.json

aws iam attach-user-policy \
  --user-name github-actions-cloudage \
  --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy

# Create access keys
aws iam create-access-key --user-name github-actions-cloudage
```

**Save the AccessKeyId and SecretAccessKey!**

#### Add Secrets to GitHub

1. Go to your GitHub repository
2. Settings → Secrets and variables → Actions
3. Add secrets:
   - `AWS_ACCESS_KEY_ID`: (from above)
   - `AWS_SECRET_ACCESS_KEY`: (from above)

### Step 6: Verify Repository Configuration

The Argo CD application is already configured with your GitHub repository:
- Repository: https://github.com/YogeshAbnave/eks-pythpn-deployment.git
- No changes needed!

### Step 7: Deploy! (1 minute)

```bash
# Create Argo CD application
kubectl apply -f argocd/application.yaml

# Push to GitHub (triggers CI/CD)
git push origin main
```

### Step 8: Get Application URL (2 minutes)

```bash
# Wait for LoadBalancer
kubectl get svc cloudage-service -n cloudage --watch

# Or use the helper script
./scripts/get-app-url.sh
```

## 🎉 Success!

Your application is now deployed! Every push to main will automatically deploy.

## 📊 Verify Deployment

### Check GitHub Actions

1. Go to your repository on GitHub
2. Click "Actions" tab
3. Watch the workflow run

### Check Argo CD

```bash
# Port forward to Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open https://localhost:8080
# Login with admin and the password from Step 4
```

### Check Kubernetes

```bash
# Check pods
kubectl get pods -n cloudage

# Check service
kubectl get svc -n cloudage

# Check logs
kubectl logs -n cloudage -l app=cloudage-education --tail=50
```

## 🔄 Making Changes

```bash
# Make your code changes
vim Home.py

# Commit and push
git add .
git commit -m "Update home page"
git push origin main

# GitHub Actions will automatically:
# 1. Build new Docker image
# 2. Push to ECR
# 3. Update deployment.yaml
# 4. Argo CD will deploy to EKS

# Watch the deployment
kubectl get pods -n cloudage --watch
```

## 🐛 Troubleshooting

### GitHub Actions fails

```bash
# Check workflow logs in GitHub Actions tab
# Common issues:
# - AWS credentials incorrect
# - ECR repository doesn't exist
# - Permissions issues
```

### Argo CD not syncing

```bash
# Check application status
kubectl get application cloudage-app -n argocd

# View details
kubectl describe application cloudage-app -n argocd

# Manual sync
kubectl patch application cloudage-app -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

### Pods not starting

```bash
# Check pod status
kubectl get pods -n cloudage

# Check pod logs
kubectl logs -n cloudage <POD_NAME>

# Check events
kubectl get events -n cloudage --sort-by='.lastTimestamp'

# Common issues:
# - Image pull errors: Check ECR permissions
# - CrashLoopBackOff: Check application logs
# - Pending: Check node resources
```

### LoadBalancer not provisioning

```bash
# Check service
kubectl describe svc cloudage-service -n cloudage

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer

# Verify security groups allow traffic
```

## 📈 Monitoring

### View Application Logs

```bash
# Real-time logs
kubectl logs -n cloudage -l app=cloudage-education -f

# Last 100 lines
kubectl logs -n cloudage -l app=cloudage-education --tail=100
```

### Check Resource Usage

```bash
# Pod resource usage
kubectl top pods -n cloudage

# Node resource usage
kubectl top nodes
```

### Argo CD Dashboard

Access at https://localhost:8080 (with port-forward)

View:
- Sync status
- Application health
- Resource tree
- Deployment history
- Rollback options

## 🔐 Security Best Practices

1. **Rotate IAM credentials regularly**
2. **Use least privilege IAM policies**
3. **Enable ECR image scanning**
4. **Use Kubernetes secrets for sensitive data**
5. **Enable pod security policies**
6. **Use network policies to restrict traffic**

## 💰 Cost Management

### Monitor Costs

```bash
# Check running resources
kubectl get nodes
kubectl get pods --all-namespaces

# Estimate costs:
# - EKS cluster: $73/month
# - 2x t3.medium: ~$60/month
# - Load Balancer: ~$16/month
# - DynamoDB: Pay per request
# - S3: Pay per storage
# Total: ~$150-200/month
```

### Reduce Costs

```bash
# Scale down nodes
eksctl scale nodegroup --cluster=cloudage-cluster --name=cloudage-nodes --nodes=1

# Delete when not in use
eksctl delete cluster --name cloudage-cluster --region us-east-1
```

## 🧹 Complete Cleanup

```bash
# Delete application
kubectl delete -f argocd/application.yaml

# Delete Argo CD
kubectl delete namespace argocd

# Delete EKS cluster
eksctl delete cluster --name cloudage-cluster --region us-east-1

# Delete AWS resources
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1
aws s3 rb s3://mcq-project --force --region us-east-1
aws ecr delete-repository --repository-name cloudage-app --force --region us-east-1

# Delete IAM resources
aws iam detach-user-policy \
  --user-name github-actions-cloudage \
  --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy
aws iam delete-user --user-name github-actions-cloudage
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy
```

## 📚 Additional Resources

- [EKS Setup Guide](docs/eks-setup.md)
- [Argo CD Setup Guide](docs/argocd-setup.md)
- [GitHub Secrets Guide](docs/github-secrets.md)
- [IAM Policy](docs/iam-policy.json)

## 🆘 Getting Help

1. Check logs: `kubectl logs -n cloudage -l app=cloudage-education`
2. Check events: `kubectl get events -n cloudage`
3. Check Argo CD UI for sync status
4. Review GitHub Actions logs
5. Consult documentation in `docs/` folder
