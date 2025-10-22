# 🎯 START HERE - CloudAge Education App Deployment

Welcome! This guide will help you deploy the CloudAge Education App to AWS EKS in **15 minutes**.

## 📦 What You Have

A complete, production-ready deployment pipeline with:
- ✅ Kubernetes manifests for EKS
- ✅ GitHub Actions CI/CD pipeline
- ✅ Argo CD GitOps configuration
- ✅ Automated setup scripts
- ✅ Comprehensive documentation

## 🚀 Quick Deploy (Choose Your Path)

### Option 1: Automated Setup (Recommended)

Run the automated setup script:

```bash
# Make script executable (Git Bash/WSL/Linux)
chmod +x setup-eks.sh

# Run setup
./setup-eks.sh
```

This will automatically:
1. Create EKS cluster
2. Setup IAM roles
3. Create AWS resources (DynamoDB, S3, ECR)
4. Install Argo CD

Then follow the on-screen instructions to complete deployment.

### Option 2: Manual Setup (Step-by-Step)

Follow the [QUICKSTART.md](QUICKSTART.md) guide for manual commands.

### Option 3: Detailed Guide

Read [DEPLOYMENT.md](DEPLOYMENT.md) for comprehensive instructions with explanations.

## 📋 Prerequisites

Before starting, ensure you have:

- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] eksctl installed (`eksctl version`)
- [ ] Git installed (`git --version`)
- [ ] AWS account with admin permissions
- [ ] GitHub account

## 🔑 Important URLs

- **GitHub Repository**: https://github.com/YogeshAbnave/eks-pythpn-deployment
- **GitHub Secrets**: https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions
- **Argo CD** (after setup): https://localhost:8080 (via port-forward)

## 📚 Documentation Guide

| Document | Purpose | When to Use |
|----------|---------|-------------|
| **START-HERE.md** (this file) | Quick overview | Start here! |
| [QUICKSTART.md](QUICKSTART.md) | 15-minute deployment | Fast manual setup |
| [DEPLOYMENT.md](DEPLOYMENT.md) | Detailed guide | Need explanations |
| [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) | Step tracker | Track progress |
| [DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md) | Architecture overview | Understand system |
| [README.md](README.md) | Full documentation | Complete reference |
| [docs/eks-setup.md](docs/eks-setup.md) | EKS cluster setup | Cluster details |
| [docs/argocd-setup.md](docs/argocd-setup.md) | Argo CD setup | GitOps details |
| [docs/github-secrets.md](docs/github-secrets.md) | GitHub configuration | CI/CD setup |

## ⚡ Super Quick Start (If You're Impatient)

```bash
# 1. Run automated setup
./setup-eks.sh

# 2. Create GitHub IAM user and get credentials
aws iam create-user --user-name github-actions-cloudage
aws iam create-access-key --user-name github-actions-cloudage

# 3. Add credentials to GitHub Secrets
# Go to: https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions
# Add: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

# 4. Deploy
kubectl apply -f argocd/application.yaml
git push origin main

# 5. Get URL
./scripts/get-app-url.sh
```

## 🎯 What Happens After Setup

Once setup is complete, your deployment workflow is:

```bash
# Make code changes
vim Home.py

# Commit and push
git add .
git commit -m "Update feature"
git push origin main

# That's it! GitHub Actions + Argo CD automatically:
# 1. Build Docker image
# 2. Push to ECR
# 3. Update Kubernetes manifests
# 4. Deploy to EKS
```

## 🔍 Verify Deployment

After deployment, check:

```bash
# Check pods
kubectl get pods -n cloudage

# Check service
kubectl get svc -n cloudage

# View logs
kubectl logs -n cloudage -l app=cloudage-education --tail=50

# Get application URL
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🎨 Architecture Overview

```
┌─────────────┐
│  Developer  │
│  git push   │
└──────┬──────┘
       │
       ▼
┌─────────────────┐
│ GitHub Actions  │
│ - Build Image   │
│ - Push to ECR   │
│ - Update YAML   │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│    Argo CD      │
│ - Auto Sync     │
│ - Deploy        │
└──────┬──────────┘
       │
       ▼
┌─────────────────┐
│    AWS EKS      │
│ - 2 Pods        │
│ - LoadBalancer  │
│ - DynamoDB      │
│ - S3            │
│ - Bedrock       │
└─────────────────┘
```

## 💰 Cost Estimate

Approximate monthly costs (us-east-1):
- EKS Cluster: $73
- 2x t3.medium: ~$60
- Load Balancer: ~$16
- DynamoDB: ~$5-10 (pay per request)
- S3: ~$1-5
- ECR: ~$1
- **Total: ~$156-165/month**

## 🐛 Troubleshooting

### Common Issues

| Problem | Solution |
|---------|----------|
| eksctl not found | Install eksctl: https://eksctl.io/installation/ |
| AWS credentials error | Run `aws configure` |
| kubectl can't connect | Run `aws eks update-kubeconfig --region us-east-1 --name cloudage-cluster` |
| Pods not starting | Check logs: `kubectl logs -n cloudage <pod-name>` |
| LoadBalancer pending | Wait 2-3 minutes, check AWS console |

### Get Help

1. Check logs: `kubectl logs -n cloudage -l app=cloudage-education`
2. Check events: `kubectl get events -n cloudage --sort-by='.lastTimestamp'`
3. Check Argo CD: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
4. Review documentation in `docs/` folder

## 🧹 Cleanup

To delete everything and stop charges:

```bash
# Delete application
kubectl delete -f argocd/application.yaml

# Delete cluster (this deletes everything)
eksctl delete cluster --name cloudage-cluster --region us-east-1

# Delete AWS resources
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1
aws s3 rb s3://mcq-project --force --region us-east-1
aws ecr delete-repository --repository-name cloudage-app --force --region us-east-1
```

## ✅ Success Checklist

Your deployment is successful when:

- [ ] EKS cluster is running
- [ ] Pods show status "Running"
- [ ] LoadBalancer has external URL
- [ ] Application accessible in browser
- [ ] Can create assignments
- [ ] Can answer questions
- [ ] Argo CD shows "Synced" and "Healthy"
- [ ] GitHub Actions workflow passes

## 🎓 Learning Resources

- **Kubernetes**: https://kubernetes.io/docs/home/
- **Argo CD**: https://argo-cd.readthedocs.io/
- **AWS EKS**: https://docs.aws.amazon.com/eks/
- **GitHub Actions**: https://docs.github.com/en/actions

## 🚦 Next Steps

1. **Now**: Run `./setup-eks.sh` or follow [QUICKSTART.md](QUICKSTART.md)
2. **After Setup**: Configure GitHub Secrets
3. **Deploy**: Push to GitHub
4. **Monitor**: Check Argo CD dashboard
5. **Iterate**: Make changes and push again

## 📞 Support

- Review [DEPLOYMENT.md](DEPLOYMENT.md) for detailed troubleshooting
- Check [DEPLOYMENT-CHECKLIST.md](DEPLOYMENT-CHECKLIST.md) to track progress
- Consult documentation in `docs/` folder

---

**Ready?** Choose your path above and start deploying! 🚀

**Recommended**: Run `./setup-eks.sh` for automated setup, then follow the on-screen instructions.
