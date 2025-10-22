# ✅ Deployment Checklist

Use this checklist to ensure all steps are completed for successful deployment.

## Pre-Deployment Checklist

### Prerequisites
- [ ] AWS CLI installed and configured (`aws --version`)
- [ ] kubectl installed (`kubectl version --client`)
- [ ] eksctl installed (`eksctl version`)
- [ ] Docker installed (`docker --version`)
- [ ] Git installed (`git --version`)
- [ ] GitHub account created
- [ ] AWS account with admin permissions
- [ ] GitHub repository created and cloned

### Repository Setup
- [ ] Code cloned to local machine from https://github.com/YogeshAbnave/eks-pythpn-deployment.git
- [ ] Argo CD application already configured with correct GitHub URL
- [ ] Reviewed and understood the architecture

## Deployment Steps

### Step 1: EKS Cluster Creation (10 minutes)
- [ ] Run eksctl create cluster command
- [ ] Wait for cluster creation to complete
- [ ] Verify cluster: `kubectl get nodes`
- [ ] Verify namespaces: `kubectl get namespaces`

### Step 2: IAM Setup (2 minutes)
- [ ] Associate OIDC provider with cluster
- [ ] Create IAM policy from `docs/iam-policy.json`
- [ ] Create service account with IAM role
- [ ] Verify service account: `kubectl get sa cloudage-sa -n cloudage`

### Step 3: AWS Resources (1 minute)
- [ ] Create DynamoDB `assignments` table
- [ ] Create DynamoDB `answers` table with GSI
- [ ] Create S3 bucket `mcq-project`
- [ ] Create ECR repository `cloudage-app`
- [ ] Verify resources in AWS Console

### Step 4: Argo CD Installation (2 minutes)
- [ ] Create argocd namespace
- [ ] Install Argo CD manifests
- [ ] Wait for pods to be ready
- [ ] Get admin password and save it
- [ ] Test port-forward: `kubectl port-forward svc/argocd-server -n argocd 8080:443`
- [ ] Access Argo CD UI at https://localhost:8080

### Step 5: GitHub Actions Setup (2 minutes)
- [ ] Create IAM user `github-actions-cloudage`
- [ ] Create and attach policy for ECR access
- [ ] Create access keys
- [ ] Save AccessKeyId and SecretAccessKey
- [ ] Go to https://github.com/YogeshAbnave/eks-pythpn-deployment/settings/secrets/actions
- [ ] Add `AWS_ACCESS_KEY_ID` to GitHub Secrets
- [ ] Add `AWS_SECRET_ACCESS_KEY` to GitHub Secrets
- [ ] Verify secrets in GitHub repository settings

### Step 6: Deploy Application (1 minute)
- [ ] Apply Argo CD application: `kubectl apply -f argocd/application.yaml`
- [ ] Commit all changes: `git add . && git commit -m "Initial deployment"`
- [ ] Push to GitHub: `git push origin main`
- [ ] Watch GitHub Actions workflow in Actions tab
- [ ] Verify workflow completes successfully

### Step 7: Verify Deployment (2 minutes)
- [ ] Check Argo CD application status: `kubectl get application cloudage-app -n argocd`
- [ ] Verify pods are running: `kubectl get pods -n cloudage`
- [ ] Check service status: `kubectl get svc -n cloudage`
- [ ] Wait for LoadBalancer to provision
- [ ] Get application URL: `kubectl get svc cloudage-service -n cloudage -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'`
- [ ] Access application in browser
- [ ] Test creating an assignment
- [ ] Test answering questions

## Post-Deployment Verification

### Application Health
- [ ] All pods show status "Running"
- [ ] Pods pass liveness probes
- [ ] Pods pass readiness probes
- [ ] LoadBalancer has external hostname/IP
- [ ] Application accessible via browser
- [ ] No errors in pod logs

### Argo CD Status
- [ ] Application shows "Synced" status
- [ ] Application shows "Healthy" status
- [ ] No sync errors in Argo CD UI
- [ ] Resource tree shows all resources green

### GitHub Actions
- [ ] Workflow completed successfully
- [ ] Docker image pushed to ECR
- [ ] Deployment manifest updated with new image tag
- [ ] No errors in workflow logs

### AWS Resources
- [ ] ECR repository contains Docker image
- [ ] DynamoDB tables exist and are active
- [ ] S3 bucket exists
- [ ] EKS cluster is active
- [ ] Load Balancer is active
- [ ] IAM roles are properly configured

## Testing Checklist

### Functional Testing
- [ ] Home page loads correctly
- [ ] Can navigate to "Create Assignments" page
- [ ] Can enter text and generate questions
- [ ] Can generate images (if enabled)
- [ ] Can save assignments
- [ ] Can view assignments in "Show Assignments"
- [ ] Can select assignment in "Complete Assignments"
- [ ] Can answer questions
- [ ] Scoring works correctly
- [ ] Suggestions are generated
- [ ] Leaderboard displays correctly

### Integration Testing
- [ ] DynamoDB read/write operations work
- [ ] S3 image upload/download works
- [ ] Bedrock API calls succeed
- [ ] No permission errors in logs

## Monitoring Setup

### Observability
- [ ] Can view pod logs: `kubectl logs -n cloudage -l app=cloudage-education`
- [ ] Can access Argo CD dashboard
- [ ] Can view resource usage: `kubectl top pods -n cloudage`
- [ ] GitHub Actions notifications working

## Security Checklist

### Credentials
- [ ] No AWS credentials hardcoded in code
- [ ] GitHub Secrets properly configured
- [ ] IAM roles use least privilege
- [ ] Service account uses IRSA (not access keys)

### Network
- [ ] LoadBalancer security groups configured
- [ ] Pods can access AWS services
- [ ] No unnecessary ports exposed

## Documentation Review

- [ ] Read [README.md](README.md)
- [ ] Read [QUICKSTART.md](QUICKSTART.md)
- [ ] Read [DEPLOYMENT.md](DEPLOYMENT.md)
- [ ] Reviewed [docs/eks-setup.md](docs/eks-setup.md)
- [ ] Reviewed [docs/argocd-setup.md](docs/argocd-setup.md)
- [ ] Reviewed [docs/github-secrets.md](docs/github-secrets.md)

## Troubleshooting Checklist

If something goes wrong, check:

### GitHub Actions Issues
- [ ] AWS credentials are correct in GitHub Secrets
- [ ] ECR repository exists
- [ ] IAM user has ECR permissions
- [ ] Workflow syntax is correct

### Argo CD Issues
- [ ] GitHub repository URL is correct
- [ ] Argo CD can access repository
- [ ] Manifests are valid YAML
- [ ] Namespace exists

### Pod Issues
- [ ] Image exists in ECR
- [ ] Image tag is correct in deployment.yaml
- [ ] Service account has IAM role annotation
- [ ] Resource limits are not too restrictive
- [ ] ConfigMap exists

### LoadBalancer Issues
- [ ] Service type is LoadBalancer
- [ ] Security groups allow traffic
- [ ] Waited 2-3 minutes for provisioning
- [ ] AWS Load Balancer Controller is running

### Application Issues
- [ ] DynamoDB tables exist
- [ ] S3 bucket exists
- [ ] IAM role has correct permissions
- [ ] Environment variables are set correctly
- [ ] Bedrock models are available in region

## Cleanup Checklist

When you're done and want to delete everything:

- [ ] Delete Argo CD application: `kubectl delete -f argocd/application.yaml`
- [ ] Delete Argo CD: `kubectl delete namespace argocd`
- [ ] Delete EKS cluster: `eksctl delete cluster --name cloudage-cluster --region us-east-1`
- [ ] Delete DynamoDB tables
- [ ] Delete S3 bucket (must be empty)
- [ ] Delete ECR repository
- [ ] Delete IAM policies and users
- [ ] Remove GitHub Secrets

## Success Criteria

✅ Deployment is successful when:

- All pods are running
- LoadBalancer has external URL
- Application is accessible via browser
- All features work correctly
- Argo CD shows "Synced" and "Healthy"
- GitHub Actions workflow passes
- No errors in logs

## Next Steps After Deployment

- [ ] Bookmark LoadBalancer URL
- [ ] Save Argo CD admin password
- [ ] Set up monitoring/alerting (optional)
- [ ] Configure custom domain (optional)
- [ ] Enable HTTPS with cert-manager (optional)
- [ ] Set up backup strategy
- [ ] Document any customizations

## Notes

Use this space to track any issues or customizations:

```
Date: ___________
Issue: ___________
Resolution: ___________

Date: ___________
Customization: ___________
Reason: ___________
```

---

**Estimated Total Time**: 15-20 minutes for initial setup

**Ongoing Deployments**: 30 seconds (just `git push`)
