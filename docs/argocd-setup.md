# Argo CD Setup Guide

This guide walks you through installing and configuring Argo CD on your EKS cluster for GitOps-based continuous delivery.

## Prerequisites

- EKS cluster running and accessible via kubectl
- kubectl configured to access your cluster
- GitHub repository with Kubernetes manifests

## Step 1: Install Argo CD

### Create Argo CD namespace and install

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### Wait for Argo CD pods to be ready

```bash
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
```

## Step 2: Access Argo CD UI

### Option A: Port Forward (Quick Access)

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Access at: https://localhost:8080

### Option B: LoadBalancer (Production)

```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

Get the LoadBalancer URL:

```bash
kubectl get svc argocd-server -n argocd
```

### Get Initial Admin Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
```

**Username**: `admin`  
**Password**: (output from above command)

## Step 3: Install Argo CD CLI (Optional but Recommended)

### macOS

```bash
brew install argocd
```

### Linux

```bash
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
rm argocd-linux-amd64
```

### Windows

```bash
choco install argocd-cli
```

### Login via CLI

```bash
# If using port-forward
argocd login localhost:8080

# If using LoadBalancer
argocd login <ARGOCD_SERVER_URL>
```

## Step 4: Configure GitHub Repository Access

### Option A: Public Repository (No Authentication)

No additional configuration needed. Argo CD can access public repos directly.

### Option B: Private Repository (SSH Key)

```bash
# Generate SSH key
ssh-keygen -t ed25519 -C "argocd@cloudage" -f ~/.ssh/argocd_ed25519

# Add public key to GitHub
# Go to GitHub → Settings → Deploy keys → Add deploy key
# Paste contents of ~/.ssh/argocd_ed25519.pub

# Add private key to Argo CD
argocd repo add git@github.com:YOUR_USERNAME/eks-python-deployment.git \
  --ssh-private-key-path ~/.ssh/argocd_ed25519
```

### Option C: Private Repository (HTTPS Token)

```bash
# Create GitHub Personal Access Token
# Go to GitHub → Settings → Developer settings → Personal access tokens → Generate new token
# Select scopes: repo (all)

# Add repository to Argo CD
argocd repo add https://github.com/YOUR_USERNAME/eks-python-deployment.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_TOKEN
```

## Step 5: Create Argo CD Application

### Method 1: Using kubectl

Update the `argocd/application.yaml` file with your GitHub repository URL, then apply:

```bash
kubectl apply -f argocd/application.yaml
```

### Method 2: Using Argo CD CLI

```bash
argocd app create cloudage-app \
  --repo https://github.com/YOUR_USERNAME/eks-python-deployment.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace cloudage \
  --sync-policy automated \
  --auto-prune \
  --self-heal
```

### Method 3: Using Argo CD UI

1. Login to Argo CD UI
2. Click "+ NEW APP"
3. Fill in details:
   - **Application Name**: cloudage-app
   - **Project**: default
   - **Sync Policy**: Automatic
   - **Repository URL**: https://github.com/YOUR_USERNAME/eks-python-deployment.git
   - **Revision**: main
   - **Path**: k8s
   - **Cluster URL**: https://kubernetes.default.svc
   - **Namespace**: cloudage
4. Click "CREATE"

## Step 6: Verify Deployment

### Check Application Status

```bash
# Using CLI
argocd app get cloudage-app

# Using kubectl
kubectl get applications -n argocd
```

### Check Application Resources

```bash
# View all resources
argocd app resources cloudage-app

# Check pods
kubectl get pods -n cloudage

# Check service
kubectl get svc -n cloudage
```

### View Sync Status

```bash
argocd app sync cloudage-app
argocd app wait cloudage-app --health
```

## Step 7: Get Application URL

```bash
# Wait for LoadBalancer to be provisioned
kubectl get svc cloudage-service -n cloudage --watch

# Get the external URL
kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

Access your application at: `http://<LOAD_BALANCER_URL>`

## Argo CD Features

### Manual Sync

```bash
argocd app sync cloudage-app
```

### Rollback

```bash
# List history
argocd app history cloudage-app

# Rollback to specific revision
argocd app rollback cloudage-app <REVISION_ID>
```

### View Logs

```bash
# Application logs
argocd app logs cloudage-app

# Specific pod logs
kubectl logs -n cloudage -l app=cloudage-education
```

### Refresh Application

```bash
argocd app get cloudage-app --refresh
```

## Monitoring and Troubleshooting

### Check Application Health

```bash
argocd app get cloudage-app
```

Look for:
- **Sync Status**: Synced
- **Health Status**: Healthy

### Common Issues

#### Issue: Application stuck in "Progressing"

```bash
# Check pod status
kubectl get pods -n cloudage

# Check pod logs
kubectl logs -n cloudage <POD_NAME>

# Check events
kubectl get events -n cloudage --sort-by='.lastTimestamp'
```

#### Issue: Sync fails with "permission denied"

- Verify GitHub repository access (SSH key or token)
- Check Argo CD has correct repository credentials

#### Issue: Application not auto-syncing

```bash
# Enable auto-sync
argocd app set cloudage-app --sync-policy automated
```

#### Issue: Image pull errors

- Verify ECR repository exists
- Check EKS nodes have permission to pull from ECR
- Verify image tag in deployment.yaml is correct

## Best Practices

1. **Use Automated Sync**: Enable auto-sync with self-heal for GitOps workflow
2. **Enable Pruning**: Automatically remove resources deleted from Git
3. **Use Health Checks**: Configure proper liveness and readiness probes
4. **Monitor Sync Status**: Set up notifications for sync failures
5. **Use Projects**: Organize applications into Argo CD projects for better management

## Notifications (Optional)

Configure Slack notifications for deployment events:

```bash
# Install Argo CD notifications
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj-labs/argocd-notifications/stable/manifests/install.yaml

# Configure Slack webhook
kubectl create secret generic argocd-notifications-secret \
  --from-literal=slack-token=<SLACK_WEBHOOK_URL> \
  -n argocd
```

## Cleanup

To remove Argo CD:

```bash
# Delete application
argocd app delete cloudage-app

# Uninstall Argo CD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd
```

## Next Steps

1. Push code changes to GitHub
2. Watch Argo CD automatically sync and deploy
3. Access your application via the LoadBalancer URL
4. Monitor application health in Argo CD UI
