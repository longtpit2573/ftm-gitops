# Deploy Jenkins to AKS using Helm
# Run this script from Infrastructure/scripts directory

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Jenkins Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Step 1: Create namespace
Write-Host "[1/6] Creating jenkins namespace..." -ForegroundColor Yellow
kubectl apply -f ../platform/jenkins/namespace.yaml

# Step 2: Add Jenkins Helm repo
Write-Host "[2/6] Adding Jenkins Helm repository..." -ForegroundColor Yellow
helm repo add jenkins https://charts.jenkins.io
helm repo update

# Step 3: Install Jenkins
Write-Host "[3/6] Installing Jenkins with Helm..." -ForegroundColor Yellow
Write-Host "This may take 3-5 minutes..." -ForegroundColor Gray

helm install jenkins jenkins/jenkins `
  --namespace jenkins `
  --values jenkins-values.yaml `
  --wait `
  --timeout 10m

# Step 4: Wait for Jenkins to be ready
Write-Host "[4/6] Waiting for Jenkins pod to be ready..." -ForegroundColor Yellow
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller -n jenkins --timeout=300s

# Step 5: Apply Ingress
Write-Host "[5/6] Creating Ingress for Jenkins..." -ForegroundColor Yellow
kubectl apply -f ../platform/jenkins/ingress.yaml

# Step 6: Get access info
Write-Host "[6/6] Deployment complete!" -ForegroundColor Green
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Jenkins Access Information" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "URL: " -NoNewline
Write-Host "http://jenkins.longops.io.vn" -ForegroundColor Green
Write-Host ""
Write-Host "Username: " -NoNewline
Write-Host "admin" -ForegroundColor Green
Write-Host ""
Write-Host "Password: " -NoNewline
Write-Host "Admin@123456" -ForegroundColor Green
Write-Host ""
Write-Host "Note: Please add DNS record:" -ForegroundColor Yellow
Write-Host "  jenkins.longops.io.vn -> 4.144.199.99" -ForegroundColor Gray
Write-Host ""

# Additional info
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Next Steps" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "1. Add DNS A record at tenten.vn:" -ForegroundColor White
Write-Host "   jenkins.longops.io.vn -> 4.144.199.99" -ForegroundColor Gray
Write-Host ""
Write-Host "2. Wait 5-10 minutes for DNS propagation" -ForegroundColor White
Write-Host ""
Write-Host "3. Access Jenkins UI and change admin password" -ForegroundColor White
Write-Host ""
Write-Host "4. Configure credentials:" -ForegroundColor White
Write-Host "   - ACR credentials (for Docker push)" -ForegroundColor Gray
Write-Host "   - GitHub PAT (for Git operations)" -ForegroundColor Gray
Write-Host "   - Kubeconfig (for kubectl operations)" -ForegroundColor Gray
Write-Host ""
Write-Host "5. Create pipelines for FTM-BE and FTM-FE" -ForegroundColor White
Write-Host ""

# Show pod status
Write-Host "Current Jenkins pod status:" -ForegroundColor Yellow
kubectl get pods -n jenkins
