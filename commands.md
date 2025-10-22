# 📝 Quick Command Reference

Essential commands for deploying and managing your CloudAge Education App on AWS EKS.

## 🚀 Initial Setup Commands

### Create EKS Cluster
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

### Setup IAM for Service Accounts
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

### Create AWS Resources
```bash
# DynamoDB - assignments table
aws dynamodb create-table \
  --table-name assignments \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1

# DynamoDB - answers table with GSI
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

### Install Argo CD
```bash
# Create namespace and install
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

## 🔄 Deployment Commands

### Deploy Application
```bash
# Apply Argo CD application
kubectl apply -f argocd/application.yaml

# Push code to trigger deployment
git add .
git commit -m "Deploy application"
git push origin main
```

### Get Application URL
```bash
# Using helper script
./scripts/get-app-url.sh

# Or manually
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 📊 Monitoring Commands

### Check Cluster Status
```bash
# Check nodes
kubectl get nodes

# Check all namespaces
kubectl get namespaces

# Check cluster info
kubectl cluster-info
```

### Check Application Status
```bash
# Check pods
kubectl get pods -n cloudage

# Check pod details
kubectl describe pod <pod-name> -n cloudage

# Check service
kubectl get svc -n cloudage

# Check deployment
kubectl get deployment -n cloudage
```

### View Logs
```bash
# View logs from all pods
kubectl logs -n cloudage -l app=cloudage-education --tail=100

# Follow logs in real-time
kubectl logs -n cloudage -l app=cloudage-education -f

# View logs from specific pod
kubectl logs -n cloudage <pod-name>
```

### Check Argo CD Status
```bash
# Get application status
kubectl get application cloudage-app -n argocd

# Describe application
kubectl describe application cloudage-app -n argocd

# Get all Argo CD applications
kubectl get applications -n argocd
```

## 🔧 Management Commands

### Scale Application
```bash
# Scale to 3 replicas
kubectl scale deployment cloudage-app -n cloudage --replicas=3

# Scale back to 2 replicas
kubectl scale deployment cloudage-app -n cloudage --replicas=2
```

### Update Application
```bash
# Make code changes
vim Home.py

# Commit and push (triggers automatic deployment)
git add .
git commit -m "Update feature"
git push origin main
```

### Restart Pods
```bash
# Restart all pods
kubectl rollout restart deployment cloudage-app -n cloudage

# Check rollout status
kubectl rollout status deployment cloudage-app -n cloudage
```

### Manual Argo CD Sync
```bash
# Trigger manual sync
kubectl patch application cloudage-app -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## 🔍 Debugging Commands

### Check Events
```bash
# Get recent events
kubectl get events -n cloudage --sort-by='.lastTimestamp'

# Watch events in real-time
kubectl get events -n cloudage --watch
```

### Check Resource Usage
```bash
# Pod resource usage
kubectl top pods -n cloudage

# Node resource usage
kubectl top nodes
```

### Exec into Pod
```bash
# Get shell access to pod
kubectl exec -it <pod-name> -n cloudage -- /bin/bash

# Run command in pod
kubectl exec <pod-name> -n cloudage -- ls -la
```

### Port Forward
```bash
# Port forward to application
kubectl port-forward svc/cloudage-service -n cloudage 8080:80

# Port forward to Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## 🔐 Security Commands

### Check Service Account
```bash
# Get service account
kubectl get sa cloudage-sa -n cloudage

# Describe service account (see IAM role)
kubectl describe sa cloudage-sa -n cloudage
```

### Check Secrets
```bash
# List secrets
kubectl get secrets -n cloudage

# Describe secret
kubectl describe secret <secret-name> -n cloudage
```

## 🧹 Cleanup Commands

### Delete Application
```bash
# Delete Argo CD application
kubectl delete -f argocd/application.yaml

# Delete namespace (removes all resources)
kubectl delete namespace cloudage
```

### Delete Argo CD
```bash
# Delete Argo CD
kubectl delete namespace argocd
```

### Delete EKS Cluster
```bash
# Delete entire cluster
eksctl delete cluster --name cloudage-cluster --region us-east-1
```

### Delete AWS Resources
```bash
# Delete DynamoDB tables
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1

# Delete S3 bucket (must be empty)
aws s3 rm s3://mcq-project --recursive
aws s3 rb s3://mcq-project --region us-east-1

# Delete ECR repository
aws ecr delete-repository --repository-name cloudage-app --force --region us-east-1

# Delete IAM policy
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy
```

## 🔄 GitHub Actions Commands

### Trigger Workflow Manually
```bash
# Using GitHub CLI
gh workflow run build-and-push.yml

# Or push to main branch
git push origin main
```

### View Workflow Status
```bash
# Using GitHub CLI
gh run list

# View specific run
gh run view <run-id>
```

## 📦 Docker Commands (Local Testing)

### Build Image Locally
```bash
# Build image
docker build -t cloudage-app:local .

# Run container
docker run -p 8501:80 cloudage-app:local
```

### Push to ECR Manually
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  992167236365.dkr.ecr.us-east-1.amazonaws.com

# Tag image
docker tag cloudage-app:local \
  992167236365.dkr.ecr.us-east-1.amazonaws.com/cloudage-app:manual

# Push image
docker push 992167236365.dkr.ecr.us-east-1.amazonaws.com/cloudage-app:manual
```

## 🧪 Testing Commands

### Lint Code
```bash
# Install flake8
pip install flake8

# Run linting
flake8 .
```

### Validate Kubernetes Manifests
```bash
# Dry run
kubectl apply -f k8s/ --dry-run=client

# Validate specific file
kubectl apply -f k8s/deployment.yaml --dry-run=client
```

## 📚 Useful Aliases

Add these to your `~/.bashrc` or `~/.zshrc`:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods -n cloudage'
alias kgs='kubectl get svc -n cloudage'
alias kl='kubectl logs -n cloudage -l app=cloudage-education --tail=100'
alias kd='kubectl describe'
alias ke='kubectl exec -it'

# Argo CD aliases
alias argocd-ui='kubectl port-forward svc/argocd-server -n argocd 8080:443'
alias argocd-pass='kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d'

# Application aliases
alias app-url='./scripts/get-app-url.sh'
alias app-logs='kubectl logs -n cloudage -l app=cloudage-education -f'
```

## 🔗 Quick Links

- **GitHub Repository**: https://github.com/YogeshAbnave/eks-pythpn-deployment
- **GitHub Secrets**: https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions
- **Argo CD UI**: https://localhost:8080 (after port-forward)

---

**Tip**: Bookmark this file for quick reference during deployment and management!
