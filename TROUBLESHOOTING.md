# 🔧 Troubleshooting Guide

Common issues and solutions for deploying the CloudAge Education App to AWS EKS.

## 🛠️ Tool Installation Issues

### Issue: `eksctl: command not found`

**Solution for Windows:**
```powershell
# Run PowerShell as Administrator
.\setup-windows.ps1
```

**Solution for macOS:**
```bash
brew tap weaveworks/tap
brew install weaveworks/tap/eksctl
```

**Solution for Linux:**
```bash
curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
```

### Issue: `kubectl: command not found`

**Solution:**
```bash
# Windows (Chocolatey)
choco install kubernetes-cli

# macOS
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Issue: `aws: command not found`

**Solution:**
```bash
# Windows (Chocolatey)
choco install awscli

# macOS
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

## 🔐 AWS Configuration Issues

### Issue: `Unable to locate credentials`

**Solution:**
```bash
aws configure
```

Enter:
- AWS Access Key ID
- AWS Secret Access Key
- Default region: `us-east-1`
- Default output format: `json`

### Issue: `Access Denied` errors

**Causes & Solutions:**

1. **Insufficient IAM permissions**
   - Ensure your AWS user has `AdministratorAccess` or EKS-specific permissions
   - Check IAM policies attached to your user

2. **Wrong region**
   - Ensure you're using `us-east-1` region
   - Update AWS config: `aws configure set region us-east-1`

3. **Expired credentials**
   - Regenerate access keys in AWS Console
   - Update with `aws configure`

## 🐳 Docker Issues

### Issue: `Docker daemon not running`

**Solution:**
```bash
# Windows: Start Docker Desktop
# macOS: Start Docker Desktop
# Linux: 
sudo systemctl start docker
sudo systemctl enable docker
```

### Issue: `Permission denied` when running Docker

**Solution for Linux:**
```bash
sudo usermod -aG docker $USER
# Log out and log back in
```

## ☸️ Kubernetes Issues

### Issue: `The connection to the server localhost:8080 was refused`

**Solution:**
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name cloudage-cluster

# Verify connection
kubectl get nodes
```

### Issue: `error: You must be logged in to the server (Unauthorized)`

**Solutions:**

1. **Update kubeconfig:**
   ```bash
   aws eks update-kubeconfig --region us-east-1 --name cloudage-cluster
   ```

2. **Check AWS credentials:**
   ```bash
   aws sts get-caller-identity
   ```

3. **Verify cluster exists:**
   ```bash
   aws eks list-clusters --region us-east-1
   ```

### Issue: Pods stuck in `Pending` state

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n cloudage
kubectl get events -n cloudage --sort-by='.lastTimestamp'
```

**Common causes:**
1. **Insufficient resources:** Scale up node group
2. **Image pull errors:** Check ECR permissions
3. **Scheduling issues:** Check node selectors/taints

## 🔄 GitHub Actions Issues

### Issue: Workflow fails with `flake8` errors

**Solution:**
```bash
# Fix linting errors locally
pip install flake8
flake8 .

# Common fixes:
# - Remove trailing whitespace
# - Fix indentation (use spaces, not tabs)
# - Split multiple imports to separate lines
# - Remove unused variables
```

### Issue: `AWS credentials not found` in GitHub Actions

**Solution:**
1. Go to: https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions
2. Add secrets:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`

### Issue: `ECR repository does not exist`

**Solution:**
```bash
aws ecr create-repository --repository-name cloudage-app --region us-east-1
```

## 🔄 Argo CD Issues

### Issue: Application stuck in `Progressing` state

**Diagnosis:**
```bash
kubectl get application cloudage-app -n argocd
kubectl describe application cloudage-app -n argocd
```

**Solutions:**

1. **Manual sync:**
   ```bash
   kubectl patch application cloudage-app -n argocd \
     --type merge \
     -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'
   ```

2. **Check repository access:**
   - Verify GitHub repository URL in `argocd/application.yaml`
   - Ensure repository is public or Argo CD has access

### Issue: `Failed to load target state`

**Solutions:**

1. **Check manifest syntax:**
   ```bash
   kubectl apply -f k8s/ --dry-run=client
   ```

2. **Verify file paths:**
   - Ensure `k8s/` directory exists
   - Check all YAML files are valid

### Issue: Can't access Argo CD UI

**Solution:**
```bash
# Port forward to Argo CD
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access at: https://localhost:8080
# Username: admin
# Password: (from above command)
```

## 🌐 LoadBalancer Issues

### Issue: LoadBalancer stuck in `Pending` state

**Diagnosis:**
```bash
kubectl describe svc cloudage-service -n cloudage
```

**Solutions:**

1. **Wait longer:** LoadBalancer provisioning takes 2-3 minutes
2. **Check AWS Console:** Verify Load Balancer is being created
3. **Check security groups:** Ensure proper ingress rules
4. **Verify subnets:** Ensure subnets are properly tagged for ELB

### Issue: Can't access application via LoadBalancer URL

**Solutions:**

1. **Check pods are running:**
   ```bash
   kubectl get pods -n cloudage
   ```

2. **Check service endpoints:**
   ```bash
   kubectl get endpoints -n cloudage
   ```

3. **Check security groups:**
   - Allow inbound traffic on port 80
   - Check both EKS node security groups and LoadBalancer security groups

4. **Test connectivity:**
   ```bash
   # Port forward to test app directly
   kubectl port-forward svc/cloudage-service -n cloudage 8080:80
   # Access at: http://localhost:8080
   ```

## 🗄️ Database Issues

### Issue: `ResourceNotFoundException` for DynamoDB

**Solution:**
```bash
# Create missing tables
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
```

### Issue: S3 bucket access denied

**Solutions:**

1. **Create bucket:**
   ```bash
   aws s3 mb s3://mcq-project --region us-east-1
   ```

2. **Check IAM permissions:**
   - Verify service account has S3 permissions
   - Check IAM role policy in `docs/iam-policy.json`

## 🔍 General Debugging

### Get comprehensive status

```bash
# Check all resources
kubectl get all -n cloudage

# Check events
kubectl get events -n cloudage --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n cloudage -l app=cloudage-education --tail=100

# Check Argo CD status
kubectl get applications -n argocd

# Check AWS resources
aws eks describe-cluster --name cloudage-cluster --region us-east-1
aws dynamodb list-tables --region us-east-1
aws s3 ls
aws ecr describe-repositories --region us-east-1
```

### Resource usage

```bash
# Check pod resource usage
kubectl top pods -n cloudage

# Check node resource usage
kubectl top nodes

# Check resource limits
kubectl describe deployment cloudage-app -n cloudage
```

## 🆘 Getting Help

### Documentation

- [START-HERE.md](START-HERE.md) - Quick overview
- [QUICKSTART.md](QUICKSTART.md) - 15-minute setup
- [DEPLOYMENT.md](DEPLOYMENT.md) - Detailed guide
- [COMMANDS.md](COMMANDS.md) - Command reference

### Logs to check

1. **Application logs:**
   ```bash
   kubectl logs -n cloudage -l app=cloudage-education --tail=100
   ```

2. **Kubernetes events:**
   ```bash
   kubectl get events -n cloudage --sort-by='.lastTimestamp'
   ```

3. **GitHub Actions logs:**
   - Go to repository → Actions tab → Click on failed workflow

4. **Argo CD logs:**
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
   ```

### Common command patterns

```bash
# Restart everything
kubectl rollout restart deployment cloudage-app -n cloudage

# Delete and recreate
kubectl delete -f k8s/
kubectl apply -f k8s/

# Force Argo CD sync
kubectl patch application cloudage-app -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{"revision":"HEAD"}}}'

# Get application URL
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

## 🧹 Clean Slate (Nuclear Option)

If everything is broken and you want to start fresh:

```bash
# Delete everything
kubectl delete namespace cloudage
kubectl delete namespace argocd
eksctl delete cluster --name cloudage-cluster --region us-east-1

# Delete AWS resources
aws dynamodb delete-table --table-name assignments --region us-east-1
aws dynamodb delete-table --table-name answers --region us-east-1
aws s3 rb s3://mcq-project --force --region us-east-1
aws ecr delete-repository --repository-name cloudage-app --force --region us-east-1

# Start over with setup
./setup-eks.sh
```

---

**Still stuck?** Check the specific documentation files or create an issue in the repository.