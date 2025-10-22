# CloudAge Education App - AWS EKS Deployment

A GenAI-powered education platform for teachers to create assignments and students to learn English, deployed on AWS EKS with GitOps using Argo CD.

> **🚀 NEW TO THIS PROJECT?** Start with [START-HERE.md](START-HERE.md) for a quick overview and deployment guide!

**GitHub Repository**: https://github.com/YogeshAbnave/eks-pythpn-deployment

## 🚀 Features

### For Teachers
- Create questions from sentences using Amazon Bedrock LLMs
- Generate images based on sentences using text-to-image models
- Save assignments to a centralized assignment bank
- Browse and manage all created assignments

### For Students
- Select and review assignments from the assignment bank
- Answer questions and receive AI-powered grading
- Get suggested word and sentence improvements
- View leaderboard with top scores

## 🏗️ Architecture

```
GitHub → GitHub Actions → Amazon ECR → Argo CD → AWS EKS
                                              ↓
                                    DynamoDB + S3 + Bedrock
```

### Technology Stack
- **Frontend**: Streamlit
- **Backend**: Python 3.9
- **AI/ML**: Amazon Bedrock (Nova, Titan, Mistral models)
- **Database**: Amazon DynamoDB
- **Storage**: Amazon S3
- **Container Registry**: Amazon ECR
- **Orchestration**: AWS EKS (Kubernetes)
- **GitOps**: Argo CD
- **CI/CD**: GitHub Actions

## 📋 Prerequisites

- AWS Account with appropriate permissions
- AWS CLI installed and configured
- kubectl installed
- eksctl installed (recommended)
- Docker installed (for local testing)
- GitHub account
- Git installed

## 🎯 Quick Start - Single Push Deployment

### Step 1: Clone and Setup Repository

```bash
# Clone the repository
git clone https://github.com/YogeshAbnave/eks-pythpn-deployment.git
cd eks-pythpn-deployment
```

### Step 2: Create AWS EKS Cluster

```bash
# Create EKS cluster (takes ~15 minutes)
eksctl create cluster \
  --name cloudage-cluster \
  --region us-east-1 \
  --nodegroup-name cloudage-nodes \
  --node-type t3.medium \
  --nodes 2 \
  --nodes-min 2 \
  --nodes-max 4 \
  --managed

# Verify cluster
kubectl get nodes
```

**Detailed instructions**: [docs/eks-setup.md](docs/eks-setup.md)

### Step 3: Setup IAM Roles for Service Accounts

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

### Step 4: Create AWS Resources

```bash
# Create DynamoDB tables
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

# Create S3 bucket
aws s3 mb s3://mcq-project --region us-east-1

# Create ECR repository
aws ecr create-repository --repository-name cloudage-app --region us-east-1
```

### Step 5: Install Argo CD

```bash
# Install Argo CD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for Argo CD to be ready
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo

# Access Argo CD UI (in a new terminal)
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open https://localhost:8080 and login with admin/<password>
```

**Detailed instructions**: [docs/argocd-setup.md](docs/argocd-setup.md)

### Step 6: Configure GitHub Secrets

Go to https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions

1. Create IAM user for GitHub Actions:
```bash
aws iam create-user --user-name github-actions-cloudage
```

2. Attach ECR permissions (see [docs/github-secrets.md](docs/github-secrets.md))

3. Create access keys:
```bash
aws iam create-access-key --user-name github-actions-cloudage
```

4. Add secrets to GitHub:
   - Go to repository **Settings** → **Secrets and variables** → **Actions**
   - Add `AWS_ACCESS_KEY_ID`
   - Add `AWS_SECRET_ACCESS_KEY`

**Detailed instructions**: [docs/github-secrets.md](docs/github-secrets.md)

### Step 7: Deploy Application

```bash
# Create Argo CD application
kubectl apply -f argocd/application.yaml

# Push code to GitHub (triggers CI/CD)
git add .
git commit -m "Initial deployment"
git push origin main
```

### Step 8: Access Your Application

```bash
# Wait for LoadBalancer to be provisioned (2-3 minutes)
kubectl get svc cloudage-service -n cloudage --watch

# Get application URL
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Access your application at: `http://<LOAD_BALANCER_URL>`

## 🔄 CI/CD Pipeline

The deployment pipeline is fully automated:

1. **Push to GitHub** → Triggers GitHub Actions workflow
2. **Build Docker Image** → Creates container from source code
3. **Push to ECR** → Stores image in Amazon ECR
4. **Update Manifest** → Updates deployment.yaml with new image tag
5. **Argo CD Sync** → Automatically deploys to EKS
6. **Health Checks** → Verifies deployment success

### Making Changes

Simply push code changes to the main branch:

```bash
# Make your changes
git add .
git commit -m "Your changes"
git push origin main

# GitHub Actions will automatically:
# 1. Build new Docker image
# 2. Push to ECR
# 3. Update Kubernetes manifests
# 4. Argo CD will deploy to EKS
```

## 🧪 Local Development

### Run Locally

```bash
# Install dependencies
pip install -r requirements.txt

# Run Streamlit app
streamlit run Home.py
```

### Build Docker Image Locally

```bash
docker build -t cloudage-app:local .
docker run -p 8501:80 cloudage-app:local
```

## 📊 Monitoring

### Check Application Status

```bash
# Check pods
kubectl get pods -n cloudage

# Check service
kubectl get svc -n cloudage

# View logs
kubectl logs -n cloudage -l app=cloudage-education --tail=100

# Check Argo CD sync status
kubectl get applications -n argocd
```

### Argo CD Dashboard

Access at: https://localhost:8080 (if using port-forward)

View:
- Sync status
- Application health
- Resource tree
- Deployment history

## 🔧 Troubleshooting

### Application not accessible

```bash
# Check pod status
kubectl get pods -n cloudage

# Check pod logs
kubectl logs -n cloudage <POD_NAME>

# Check service
kubectl describe svc cloudage-service -n cloudage
```

### Image pull errors

```bash
# Verify ECR repository
aws ecr describe-repositories --repository-names cloudage-app --region us-east-1

# Check image exists
aws ecr list-images --repository-name cloudage-app --region us-east-1
```

### Argo CD sync issues

```bash
# Check application status
kubectl get application cloudage-app -n argocd

# View sync errors
kubectl describe application cloudage-app -n argocd

# Manual sync
kubectl patch application cloudage-app -n argocd --type merge -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
```

## 🗂️ Project Structure

```
eks-python-deployment/
├── .github/
│   └── workflows/
│       └── build-and-push.yml    # CI/CD pipeline
├── k8s/
│   ├── namespace.yaml            # Kubernetes namespace
│   ├── configmap.yaml            # Application configuration
│   ├── secret.yaml               # Secrets template
│   ├── serviceaccount.yaml       # Service account with IAM role
│   ├── deployment.yaml           # Application deployment
│   └── service.yaml              # LoadBalancer service
├── argocd/
│   └── application.yaml          # Argo CD application definition
├── docs/
│   ├── eks-setup.md              # EKS cluster setup guide
│   ├── argocd-setup.md           # Argo CD installation guide
│   ├── github-secrets.md         # GitHub secrets configuration
│   └── iam-policy.json           # IAM policy for pods
├── components/
│   ├── Parameter_store.py        # Configuration helpers
│   └── ui_template.py            # UI components
├── pages/
│   ├── 1_Create_Assignments.py   # Teacher interface
│   ├── 2_Show_Assignments.py     # Assignment browser
│   └── 3_Complete_Assignments.py # Student interface
├── Home.py                       # Main application entry
├── requirements.txt              # Python dependencies
├── Dockerfile                    # Container definition
└── README.md                     # This file
```

## 🔐 Security

- IAM Roles for Service Accounts (IRSA) for pod authentication
- No hardcoded AWS credentials in code
- GitHub Secrets for CI/CD credentials
- Network policies for pod isolation
- Resource limits to prevent resource exhaustion

## 💰 Cost Estimation

Approximate monthly costs (us-east-1):

- **EKS Cluster**: $73/month
- **EC2 Instances** (2x t3.medium): ~$60/month
- **Load Balancer**: ~$16/month
- **DynamoDB**: Pay per request (minimal for testing)
- **S3**: Pay per storage and requests (minimal)
- **ECR**: $0.10/GB/month
- **Bedrock**: Pay per API call

**Total**: ~$150-200/month for development/testing

## 🧹 Cleanup

To avoid ongoing charges, delete all resources:

```bash
# Delete Argo CD application
kubectl delete -f argocd/application.yaml

# Delete EKS cluster
eksctl delete cluster --name cloudage-cluster --region us-east-1

# Delete DynamoDB tables
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1

# Delete S3 bucket
aws s3 rb s3://mcq-project --force --region us-east-1

# Delete ECR repository
aws ecr delete-repository --repository-name cloudage-app --force --region us-east-1

# Delete IAM resources
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy
```

## 📚 Documentation

- [EKS Setup Guide](docs/eks-setup.md)
- [Argo CD Setup Guide](docs/argocd-setup.md)
- [GitHub Secrets Configuration](docs/github-secrets.md)
- [IAM Policy](docs/iam-policy.json)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Push to GitHub
5. CI/CD will automatically deploy to your EKS cluster

## 📝 License

This project is for educational purposes.

## 🆘 Support

For issues or questions:
1. Check the troubleshooting section
2. Review documentation in `docs/` folder
3. Check Argo CD UI for deployment status
4. Review GitHub Actions logs for CI/CD issues




# 1. Create EKS cluster (10 min)
eksctl create cluster --name cloudage-cluster --region us-east-1 --nodegroup-name cloudage-nodes --node-type t3.medium --nodes 2 --managed

# 2. Setup IAM (2 min)
eksctl utils associate-iam-oidc-provider --cluster cloudage-cluster --region us-east-1 --approve
aws iam create-policy --policy-name CloudAgeEKSPodPolicy --policy-document file://docs/iam-policy.json
eksctl create iamserviceaccount --name cloudage-sa --namespace cloudage --cluster cloudage-cluster --region us-east-1 --attach-policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy --role-name cloudage-eks-pod-role --approve

# 3. Create AWS resources (1 min)
aws dynamodb create-table --table-name assignments --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
aws dynamodb create-table --table-name answers --attribute-definitions AttributeName=student_id,AttributeType=S AttributeName=assignment_question_id,AttributeType=S AttributeName=score,AttributeType=N --key-schema AttributeName=student_id,KeyType=HASH AttributeName=assignment_question_id,KeyType=RANGE --global-secondary-indexes "IndexName=assignment_question_id-index,KeySchema=[{AttributeName=assignment_question_id,KeyType=HASH},{AttributeName=score,KeyType=RANGE}],Projection={ProjectionType=ALL}" --billing-mode PAY_PER_REQUEST --region us-east-1
aws s3 mb s3://mcq-project --region us-east-1
aws ecr create-repository --repository-name cloudage-app --region us-east-1

# 4. Install Argo CD (2 min)
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# 5. Configure GitHub Secrets (add AWS credentials)

# 6. Deploy!
sed -i 's/YOUR_USERNAME/your-github-username/g' argocd/application.yaml
kubectl apply -f argocd/application.yaml
git push origin main
