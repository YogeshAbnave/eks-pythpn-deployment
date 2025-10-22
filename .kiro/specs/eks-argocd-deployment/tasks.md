# Implementation Plan

- [x] 1. Set up GitHub repository structure and configuration files


  - Create .gitignore file to exclude Python cache, temp files, and AWS credentials
  - Create .dockerignore file to exclude unnecessary files from Docker build
  - Create k8s/ directory for Kubernetes manifests
  - Create argocd/ directory for Argo CD configuration
  - Create .github/workflows/ directory for GitHub Actions
  - _Requirements: 1.1, 1.2, 1.3, 1.4_


- [x] 2. Create Kubernetes namespace and configuration manifests


  - [ ] 2.1 Create k8s/namespace.yaml
    - Define cloudage namespace for application resources


    - _Requirements: 4.1_
  
  - [x] 2.2 Create k8s/configmap.yaml


    - Define ConfigMap with ASSIGNMENTS_TABLE, AWS_REGION, BEDROCK_MODEL_ID, S3_BUCKET
    - Include all environment variables needed by the application
    - _Requirements: 4.3, 2.4_

  


  - [ ] 2.3 Create k8s/secret.yaml template
    - Create template for Kubernetes secrets (without actual sensitive values)
    - Include placeholders for AWS credentials if needed


    - Add instructions for creating actual secrets
    - _Requirements: 7.2_

- [ ] 3. Create Kubernetes service account with IAM role configuration
  - [x] 3.1 Create k8s/serviceaccount.yaml


    - Define service account named cloudage-sa
    - Add annotation for IAM role ARN (eks.amazonaws.com/role-arn)
    - _Requirements: 4.4, 7.3_
  
  - [x] 3.2 Create IAM policy document for EKS pods

    - Write JSON policy with DynamoDB permissions (PutItem, GetItem, Scan, Query)
    - Add S3 permissions (PutObject, GetObject, ListBucket)
    - Add Bedrock permissions (InvokeModel, InvokeModelWithResponseStream)
    - Save as docs/iam-policy.json for reference

    - _Requirements: 7.3_

- [ ] 4. Create Kubernetes deployment manifest
  - [ ] 4.1 Create k8s/deployment.yaml
    - Define Deployment with 2 replicas for high availability

    - Set container image to ECR repository URL with placeholder tag
    - Configure resource requests (250m CPU, 512Mi memory)
    - Configure resource limits (500m CPU, 1Gi memory)
    - _Requirements: 4.1, 2.4_
  
  - [ ] 4.2 Add environment variables and ConfigMap reference
    - Reference cloudage-config ConfigMap for environment variables
    - Mount service account token for AWS authentication
    - _Requirements: 4.3, 2.4_
  
  - [ ] 4.3 Configure health probes
    - Add liveness probe with HTTP GET on port 80 path /
    - Add readiness probe with HTTP GET on port 80 path /
    - Set appropriate initialDelaySeconds, periodSeconds, timeoutSeconds
    - _Requirements: 5.3, 5.5_
  
  - [ ] 4.4 Configure deployment strategy
    - Set rolling update strategy with maxSurge: 1 and maxUnavailable: 0
    - Add pod labels for service selector
    - _Requirements: 4.6_

- [x] 5. Create Kubernetes service manifest for external access


  - Create k8s/service.yaml with type LoadBalancer
  - Configure port 80 mapping to container port 80
  - Add selector labels to match deployment pods
  - Configure health check annotations for AWS Load Balancer
  - _Requirements: 5.1, 5.2, 5.3, 5.4_

- [x] 6. Create Argo CD application definition


  - Create argocd/application.yaml
  - Configure source repository URL (GitHub repo)
  - Set target revision to main branch
  - Set path to k8s/ directory
  - Configure automated sync policy with prune and selfHeal enabled
  - Set destination namespace to cloudage
  - _Requirements: 4.5, 4.6_

- [x] 7. Create GitHub Actions workflow for Docker build and ECR push

  - [x] 7.1 Create .github/workflows/build-and-push.yml


    - Configure workflow to trigger on push to main branch
    - Add checkout action to get repository code
    - _Requirements: 6.1, 6.2_
  
  - [x] 7.2 Add AWS authentication and ECR login steps

    - Configure AWS credentials action using GitHub Secrets
    - Add ECR login step using aws-actions/amazon-ecr-login
    - _Requirements: 3.1, 7.1_
  
  - [x] 7.3 Add Docker build and push steps

    - Extract metadata for Docker tags (commit SHA, version, latest)
    - Build Docker image using docker/build-push-action
    - Tag image with multiple tags for traceability
    - Push image to Amazon ECR
    - _Requirements: 2.5, 3.3, 3.4, 6.3_
  
  - [x] 7.4 Add image scanning and output steps

    - Scan Docker image for vulnerabilities (optional)
    - Output image tag for use in deployment workflow
    - Add retry logic for ECR push failures
    - _Requirements: 3.5, 7.4_

- [ ] 8. Create GitHub Actions workflow for deployment
  - [ ] 8.1 Create .github/workflows/deploy.yml
    - Configure workflow to trigger after build-and-push completes
    - Add checkout action to get repository code
    - _Requirements: 6.4_
  
  - [ ] 8.2 Update Kubernetes manifests with new image tag
    - Use sed or yq to update image tag in k8s/deployment.yaml
    - Commit and push changes back to repository
    - Configure git user for automated commits
    - _Requirements: 6.4_
  
  - [ ] 8.3 Add Argo CD sync trigger (optional)
    - Install Argo CD CLI in workflow
    - Trigger manual sync of cloudage-app application
    - Wait for sync to complete successfully
    - _Requirements: 6.5_
  
  - [ ] 8.4 Retrieve and output LoadBalancer URL
    - Use kubectl to get service external IP/hostname
    - Wait for LoadBalancer to be provisioned
    - Output URL as workflow output or comment on commit
    - _Requirements: 5.2_

- [ ] 9. Create setup documentation and helper scripts
  - [x] 9.1 Create docs/eks-setup.md


    - Document EKS cluster creation using eksctl or AWS Console
    - Include commands for creating IAM roles for service accounts
    - Document kubectl configuration steps
    - _Requirements: 1.4_
  
  - [x] 9.2 Create docs/argocd-setup.md


    - Document Argo CD installation on EKS cluster
    - Include commands for accessing Argo CD UI
    - Document application creation and sync steps
    - _Requirements: 1.4_
  
  - [x] 9.3 Create docs/github-secrets.md


    - List all required GitHub Secrets with descriptions
    - Provide instructions for obtaining AWS credentials
    - Document how to add secrets to GitHub repository
    - _Requirements: 7.1_
  


  - [ ] 9.4 Update README.md with deployment instructions
    - Add overview of the deployment architecture
    - Include step-by-step deployment guide
    - Add troubleshooting section
    - Include commands for accessing the deployed application
    - _Requirements: 1.4_

- [ ] 10. Create helper scripts for local development and testing
  - [ ] 10.1 Create scripts/build-local.sh
    - Script to build Docker image locally
    - Include commands for testing the container locally
    - _Requirements: 2.1, 2.2_
  
  - [ ] 10.2 Create scripts/deploy-local.sh
    - Script to apply Kubernetes manifests to local cluster (minikube/kind)
    - Include validation commands



    - _Requirements: 4.1_
  
  - [ ] 10.3 Create scripts/get-app-url.sh
    - Script to retrieve LoadBalancer URL from EKS
    - Include wait logic for LoadBalancer provisioning
    - _Requirements: 5.2_

- [ ]* 11. Validate and test the complete deployment pipeline
  - Test Docker build locally
  - Validate all Kubernetes manifests with kubectl apply --dry-run
  - Test GitHub Actions workflows with manual triggers
  - Verify Argo CD syncs deployment successfully
  - Access application via LoadBalancer URL and test functionality
  - Verify AWS service access (DynamoDB, S3, Bedrock) from pods