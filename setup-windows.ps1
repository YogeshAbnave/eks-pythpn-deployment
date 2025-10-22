# CloudAge Education App - Windows Setup Script
# This script installs required tools and sets up the EKS deployment

Write-Host "🚀 CloudAge Education App - Windows Setup" -ForegroundColor Green
Write-Host "=========================================" -ForegroundColor Green
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if (-not $isAdmin) {
    Write-Host "⚠️  This script requires Administrator privileges to install tools." -ForegroundColor Yellow
    Write-Host "Please run PowerShell as Administrator and try again." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Follow the manual setup in QUICKSTART.md" -ForegroundColor Cyan
    exit 1
}

# Function to check if a command exists
function Test-Command($cmdname) {
    return [bool](Get-Command -Name $cmdname -ErrorAction SilentlyContinue)
}

Write-Host "📋 Checking prerequisites..." -ForegroundColor Yellow
Write-Host ""

# Check Chocolatey
if (-not (Test-Command "choco")) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
}

Write-Host "✅ Chocolatey is available" -ForegroundColor Green

# Install required tools
$tools = @(
    @{name="aws-cli"; command="aws"; package="awscli"},
    @{name="kubectl"; command="kubectl"; package="kubernetes-cli"},
    @{name="eksctl"; command="eksctl"; package="eksctl"},
    @{name="git"; command="git"; package="git"}
)

foreach ($tool in $tools) {
    if (-not (Test-Command $tool.command)) {
        Write-Host "Installing $($tool.name)..." -ForegroundColor Yellow
        choco install $tool.package -y
    } else {
        Write-Host "✅ $($tool.name) is already installed" -ForegroundColor Green
    }
}

# Refresh environment variables
Write-Host ""
Write-Host "🔄 Refreshing environment variables..." -ForegroundColor Yellow
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

# Verify installations
Write-Host ""
Write-Host "🔍 Verifying installations..." -ForegroundColor Yellow

$verifications = @(
    @{name="AWS CLI"; command="aws --version"},
    @{name="kubectl"; command="kubectl version --client"},
    @{name="eksctl"; command="eksctl version"},
    @{name="git"; command="git --version"}
)

$allGood = $true
foreach ($verify in $verifications) {
    try {
        $output = Invoke-Expression $verify.command 2>$null
        Write-Host "✅ $($verify.name): OK" -ForegroundColor Green
    } catch {
        Write-Host "❌ $($verify.name): Not working" -ForegroundColor Red
        $allGood = $false
    }
}

if (-not $allGood) {
    Write-Host ""
    Write-Host "⚠️  Some tools are not working properly." -ForegroundColor Yellow
    Write-Host "Please restart your PowerShell session and try again." -ForegroundColor Yellow
    Write-Host "Or follow the manual setup in QUICKSTART.md" -ForegroundColor Cyan
    exit 1
}

Write-Host ""
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ All tools installed successfully!" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""

# Check AWS configuration
Write-Host "🔐 Checking AWS configuration..." -ForegroundColor Yellow
try {
    $awsIdentity = aws sts get-caller-identity 2>$null | ConvertFrom-Json
    Write-Host "✅ AWS configured for account: $($awsIdentity.Account)" -ForegroundColor Green
} catch {
    Write-Host "⚠️  AWS not configured. Please run: aws configure" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "You'll need:" -ForegroundColor Cyan
    Write-Host "- AWS Access Key ID" -ForegroundColor Cyan
    Write-Host "- AWS Secret Access Key" -ForegroundColor Cyan
    Write-Host "- Default region: us-east-1" -ForegroundColor Cyan
    Write-Host "- Default output format: json" -ForegroundColor Cyan
    Write-Host ""
    $configure = Read-Host "Configure AWS now? (y/n)"
    if ($configure -eq "y" -or $configure -eq "Y") {
        aws configure
    }
}

Write-Host ""
Write-Host "📚 Next Steps:" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Configure AWS (if not done): aws configure" -ForegroundColor White
Write-Host "2. Follow the deployment guide:" -ForegroundColor White
Write-Host "   - QUICKSTART.md (15-minute setup)" -ForegroundColor White
Write-Host "   - DEPLOYMENT.md (detailed guide)" -ForegroundColor White
Write-Host "   - START-HERE.md (overview)" -ForegroundColor White
Write-Host ""
Write-Host "3. Or run the automated setup:" -ForegroundColor White
Write-Host "   ./setup-eks.sh" -ForegroundColor White
Write-Host ""
Write-Host "🎉 Ready to deploy to AWS EKS!" -ForegroundColor Green