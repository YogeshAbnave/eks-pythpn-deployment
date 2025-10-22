# 🚀 Quick Start - Deploy in 15 Minutes

This is the fastest path to get your application running on AWS EKS.

## Prerequisites

- AWS CLI configured
- kubectl installed
- eksctl installed
- GitHub account
- Docker installed

## Step-by-Step Commands

### 1. Create EKS Cluster (10 min)

```bash
eksctl create cluster --name cloudage-cluster --region us-east-1 --nodegroup-name cloudage-nodes --node-type t3.medium --nodes 2 --managed
```

### 2. Setup IAM (2 min)

```bash
eksctl utils associate-iam-oidc-provider --cluster cloudage-cluster --region us-east-1 --approve
aws iam create-policy --policy-name CloudAgeEKSPodPolicy --policy-document file://docs/iam-policy.json
eksctl create iamserviceaccount --name cloudage-sa --namespace cloudage --cluster cloudage-cluster --region us-east-1 --attach-policy-arn arn:aws:iam::992167236365:policy/CloudAgeEKSPodPolicy --role-name cloudage-eks-pod-role --approve
```

### 3. Create AWS Resources (1 min)

```bash
aws dynamodb create-table --table-name assignments --attribute-definitions AttributeName=id,AttributeType=S --key-schema AttributeName=id,KeyType=HASH --billing-mode PAY_PER_REQUEST --region us-east-1
aws dynamodb create-table --table-name answers --attribute-definitions AttributeName=student_id,AttributeType=S AttributeName=assignment_question_id,AttributeType=S AttributeName=score,AttributeType=N --key-schema AttributeName=student_id,KeyType=HASH AttributeName=assignment_question_id,KeyType=RANGE --global-secondary-indexes "IndexName=assignment_question_id-index,KeySchema=[{AttributeName=assignment_question_id,KeyType=HASH},{AttributeName=score,KeyType=RANGE}],Projection={ProjectionType=ALL}" --billing-mode PAY_PER_REQUEST --region us-east-1
aws s3 mb s3://mcq-project --region us-east-1
aws ecr create-repository --repository-name cloudage-app --region us-east-1
```

### 4. Install Argo CD (2 min)

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

### 5. Setup GitHub Actions

Create IAM user:
```bash
aws iam create-user --user-name github-actions-cloudage
aws iam create-access-key --user-name github-actions-cloudage
```

Add to GitHub Secrets at https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

### 6. Deploy

```bash
kubectl apply -f argocd/application.yaml
git add . && git commit -m "Deploy" && git push origin main
```

### 7. Get URL

```bash
kubectl get svc cloudage-service -n cloudage --watch
```

## Done! 🎉

Your app is now deployed. Every push to main will auto-deploy.

## Quick Commands

```bash
# Check status
kubectl get pods -n cloudage

# View logs
kubectl logs -n cloudage -l app=cloudage-education --tail=50

# Get URL
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'

# Access Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

## Cleanup

```bash
eksctl delete cluster --name cloudage-cluster --region us-east-1
```

For detailed instructions, see [DEPLOYMENT.md](DEPLOYMENT.md)
