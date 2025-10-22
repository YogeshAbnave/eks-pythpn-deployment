# GitHub Secrets Configuration Guide

This guide explains how to configure GitHub Secrets for the CI/CD pipeline to deploy to AWS EKS.

## Required Secrets

The GitHub Actions workflows require the following secrets to be configured in your repository:

| Secret Name | Description | How to Obtain |
|------------|-------------|---------------|
| `AWS_ACCESS_KEY_ID` | AWS access key for ECR and EKS access | AWS IAM Console |
| `AWS_SECRET_ACCESS_KEY` | AWS secret key | AWS IAM Console |

## Step 1: Create IAM User for GitHub Actions

### Create IAM User

```bash
aws iam create-user --user-name github-actions-cloudage
```

### Create IAM Policy

Create a file named `github-actions-policy.json`:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAccess",
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
        "ecr:CreateRepository",
        "ecr:ListImages"
      ],
      "Resource": "*"
    },
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:ListClusters"
      ],
      "Resource": "*"
    }
  ]
}
```

### Attach Policy to User

```bash
# Create the policy
aws iam create-policy \
  --policy-name GitHubActionsCloudAgePolicy \
  --policy-document file://github-actions-policy.json

# Attach policy to user
aws iam attach-user-policy \
  --user-name github-actions-cloudage \
  --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy
```

### Create Access Keys

```bash
aws iam create-access-key --user-name github-actions-cloudage
```

**Important**: Save the output! You'll need:
- `AccessKeyId`
- `SecretAccessKey`

## Step 2: Add Secrets to GitHub Repository

### Via GitHub Web Interface

1. Go to your GitHub repository
2. Click on **Settings** tab
3. In the left sidebar, click **Secrets and variables** → **Actions**
4. Click **New repository secret**
5. Add each secret:

#### Secret 1: AWS_ACCESS_KEY_ID
- **Name**: `AWS_ACCESS_KEY_ID`
- **Value**: (paste the AccessKeyId from Step 1)
- Click **Add secret**

#### Secret 2: AWS_SECRET_ACCESS_KEY
- **Name**: `AWS_SECRET_ACCESS_KEY`
- **Value**: (paste the SecretAccessKey from Step 1)
- Click **Add secret**

### Via GitHub CLI (Alternative)

```bash
# Install GitHub CLI if not already installed
# macOS: brew install gh
# Linux: https://github.com/cli/cli/blob/trunk/docs/install_linux.md
# Windows: choco install gh

# Login to GitHub
gh auth login

# Add secrets
gh secret set AWS_ACCESS_KEY_ID --body "YOUR_ACCESS_KEY_ID"
gh secret set AWS_SECRET_ACCESS_KEY --body "YOUR_SECRET_ACCESS_KEY"
```

## Step 3: Verify Secrets

### Check Secrets in GitHub

1. Go to repository **Settings** → **Secrets and variables** → **Actions**
2. You should see:
   - ✅ AWS_ACCESS_KEY_ID
   - ✅ AWS_SECRET_ACCESS_KEY

### Test Workflow

1. Make a small change to your code
2. Commit and push to main branch
3. Go to **Actions** tab in GitHub
4. Watch the workflow run
5. Check for any authentication errors

## Optional: Additional Secrets

Depending on your setup, you may want to add these optional secrets:

### ARGOCD_SERVER and ARGOCD_AUTH_TOKEN

If you want GitHub Actions to trigger Argo CD sync:

```bash
# Get Argo CD server URL
kubectl get svc argocd-server -n argocd

# Get Argo CD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Login and get auth token
argocd login <ARGOCD_SERVER> --username admin --password <PASSWORD>
argocd account generate-token --account admin

# Add to GitHub secrets
gh secret set ARGOCD_SERVER --body "<ARGOCD_SERVER_URL>"
gh secret set ARGOCD_AUTH_TOKEN --body "<TOKEN>"
```

### SLACK_WEBHOOK_URL

For deployment notifications:

```bash
# Create Slack webhook: https://api.slack.com/messaging/webhooks
gh secret set SLACK_WEBHOOK_URL --body "<WEBHOOK_URL>"
```

## Security Best Practices

### 1. Use Least Privilege

The IAM user should only have permissions needed for ECR and EKS operations.

### 2. Rotate Credentials Regularly

```bash
# Create new access key
aws iam create-access-key --user-name github-actions-cloudage

# Update GitHub secrets with new keys

# Delete old access key
aws iam delete-access-key --user-name github-actions-cloudage --access-key-id <OLD_KEY_ID>
```

### 3. Use OIDC (Recommended for Production)

Instead of long-lived credentials, use GitHub's OIDC provider:

```bash
# Create OIDC provider
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1

# Create IAM role with trust policy for GitHub Actions
# Then update workflow to use aws-actions/configure-aws-credentials@v4 with role-to-assume
```

### 4. Monitor Access

```bash
# Check recent access key usage
aws iam get-access-key-last-used --access-key-id <ACCESS_KEY_ID>

# View CloudTrail logs for API calls
aws cloudtrail lookup-events --lookup-attributes AttributeKey=Username,AttributeValue=github-actions-cloudage
```

## Troubleshooting

### Issue: "Error: Credentials could not be loaded"

- Verify secrets are named exactly: `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
- Check for extra spaces or newlines in secret values
- Ensure IAM user has correct permissions

### Issue: "Error: Access Denied" when pushing to ECR

- Verify IAM policy includes ECR permissions
- Check ECR repository exists or policy allows CreateRepository
- Ensure AWS region matches (us-east-1)

### Issue: Secrets not available in workflow

- Secrets are only available in workflows triggered by push/pull_request from the same repository
- Forked repositories don't have access to secrets (security feature)

## Cleanup

To remove IAM user and credentials:

```bash
# List access keys
aws iam list-access-keys --user-name github-actions-cloudage

# Delete access keys
aws iam delete-access-key --user-name github-actions-cloudage --access-key-id <KEY_ID>

# Detach policies
aws iam detach-user-policy \
  --user-name github-actions-cloudage \
  --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy

# Delete user
aws iam delete-user --user-name github-actions-cloudage

# Delete policy
aws iam delete-policy --policy-arn arn:aws:iam::992167236365:policy/GitHubActionsCloudAgePolicy
```

## Next Steps

After configuring secrets:
1. Push code to GitHub main branch
2. GitHub Actions will automatically build and push Docker image to ECR
3. Argo CD will detect changes and deploy to EKS
4. Access your application via LoadBalancer URL
