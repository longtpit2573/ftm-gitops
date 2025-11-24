# Jenkins Setup Guide - CI/CD cho FTM Project

## 1. Truy cập Jenkins UI

```powershell
# Kiểm tra DNS
nslookup jenkins.longops.io.vn

# Mở Jenkins
start http://jenkins.longops.io.vn
```

**Thông tin đăng nhập:**
- URL: http://jenkins.longops.io.vn
- Username: `admin`
- Password: Lấy bằng lệnh:
  ```powershell
  kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
  ```

---

## 2. Cài đặt Plugins

**Manage Jenkins → Plugins → Available plugins**

### Plugins cần thiết:

1. **Docker Pipeline** - Build và push Docker images
2. **Docker** - Docker integration
3. **Kubernetes CLI** - Chạy kubectl commands
4. **Kubernetes** - Kubernetes cloud integration
5. **Git** - Git SCM support
6. **GitHub** - GitHub integration và webhooks
7. **GitHub Branch Source** - Multi-branch pipelines
8. **Pipeline** - Pipeline support (thường đã có sẵn)
9. **Pipeline: Stage View** - Visualization
10. **Blue Ocean** (Optional) - Modern UI cho pipelines
11. **Credentials Binding** - Bind credentials to environment variables (thường đã có sẵn)
12. **Slack Notification** (Optional) - Notifications

### Cách cài:

1. Vào **Manage Jenkins** → **Plugins**
2. Tab **Available plugins**
3. Dùng search box tìm từng plugin
4. Tick chọn các plugins trên
5. Click **Install**
6. Tick **Restart Jenkins when installation is complete and no jobs are running**
7. Đợi Jenkins restart (2-3 phút)
8. Login lại

---

## 3. Cấu hình Credentials

### 3.1 Lấy ACR Passwords

```powershell
# Backend ACR password
az acr credential show --name acrftmbackenddev --query "passwords[0].value" -o tsv
# Output: <YOUR_BACKEND_ACR_PASSWORD>

# Frontend ACR password
az acr credential show --name acrftmfrontenddev --query "passwords[0].value" -o tsv
```
# Output: <YOUR_FRONTEND_ACR_PASSWORD>
### 3.2 Tạo GitHub Personal Access Token

1. Vào https://github.com/settings/tokens
2. Click **Generate new token (classic)**
3. Token name: `Jenkins CI/CD`
4. Expiration: `No expiration` hoặc `90 days`
5. Select scopes:
   - ✅ **repo** (Full control of private repositories)
   - ✅ **workflow** (Update GitHub Action workflows)
   - ✅ **admin:repo_hook** (Full control of repository hooks)
6. Click **Generate token**
7. **Copy token ngay** (chỉ hiển thị 1 lần)

```
ghp_XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX
```

### 3.3 Thêm Credentials vào Jenkins

**Manage Jenkins → Credentials → System → Global credentials (unrestricted) → Add Credentials**

#### Credential 1: ACR Backend

- **Kind:** `Username with password`
- **Scope:** `Global (Jenkins, nodes, items, all child items, etc)`
- **Username:** `acrftmbackenddev`
- **Password:** (paste password từ lệnh az acr credential show)
- **ID:** `acr-credentials`
- **Description:** `Azure Container Registry - Backend`
- Click **Create**

#### Credential 2: ACR Frontend

- **Kind:** `Username with password`
- **Scope:** `Global`
- **Username:** `acrftmfrontenddev`
- **Password:** (paste password từ lệnh az acr credential show)
- **ID:** `acr-frontend-credentials`
- **Description:** `Azure Container Registry - Frontend`
- Click **Create**

#### Credential 3: GitHub PAT

- **Kind:** `Username with password`
- **Scope:** `Global`
- **Username:** `longtpit2573`
- **Password:** (paste GitHub Personal Access Token)
- **ID:** `git-credentials`
- **Description:** `GitHub Personal Access Token for CI/CD`
- Click **Create**

---

## 4. Tạo Pipeline Jobs

### 4.1 Backend Pipeline

1. **Dashboard → New Item**
2. **Item name:** `ftm-backend-pipeline`
3. **Type:** `Pipeline`
4. Click **OK**

**Configuration:**

- **General:**
  - Description: `FTM Backend CI/CD Pipeline (.NET 7)`
  - ✅ GitHub project: `https://github.com/longtpit2573/FTM-BE/`

- **Build Triggers:**
  - ✅ **GitHub hook trigger for GITScm polling**

- **Pipeline:**
  - Definition: `Pipeline script from SCM`
  - SCM: `Git`
  - Repository URL: `https://github.com/longtpit2573/FTM-BE.git`
  - Credentials: `longtpit2573/****** (GitHub Personal Access Token for CI/CD)`
  - Branch Specifier: `*/main`
  - Script Path: `Jenkinsfile`

- Click **Save**

### 4.2 Frontend Pipeline

Làm tương tự:

- **Item name:** `ftm-frontend-pipeline`
- **Description:** `FTM Frontend CI/CD Pipeline (React + Vite)`
- **GitHub project:** `https://github.com/longtpit2573/FTM-FE/`
- ✅ **GitHub hook trigger for GITScm polling**
- **Repository URL:** `https://github.com/longtpit2573/FTM-FE.git`
- **Credentials:** `git-credentials`
- **Branch:** `*/main`
- **Script Path:** `Jenkinsfile`

---

## 5. Setup GitHub Webhooks

### 5.1 Backend Repository

1. Vào https://github.com/longtpit2573/FTM-BE/settings/hooks
2. Click **Add webhook**
3. **Payload URL:** `http://jenkins.longops.io.vn/github-webhook/`
4. **Content type:** `application/json`
5. **SSL verification:** Enable SSL verification
6. **Which events?** `Just the push event`
7. ✅ **Active**
8. Click **Add webhook**

### 5.2 Frontend Repository

Làm tương tự với repo FTM-FE:
- Vào https://github.com/longtpit2573/FTM-FE/settings/hooks
- Payload URL: `http://jenkins.longops.io.vn/github-webhook/`
- Content type: `application/json`
- Events: `Just the push event`

---

## 6. Test Pipeline

### 6.1 Test Manual Build

1. Vào Jenkins Dashboard
2. Click vào `ftm-backend-pipeline`
3. Click **Build Now**
4. Xem **Console Output** để theo dõi build

### 6.2 Test Webhook Trigger

```powershell
# Test backend
cd E:\AKS-DEMO\FTM-BE
echo "# Test Jenkins CI" >> README.md
git add README.md
git commit -m "test: trigger Jenkins build"
git push origin main
```

**Verify:**
1. Jenkins tự động trigger build
2. Console Output hiển thị các stages
3. Image được push lên ACR
4. GitOps repo được update
5. ArgoCD sync và deploy pods mới

### 6.3 Kiểm tra kết quả

```powershell
# Check Jenkins build status
# → Xem trong Jenkins UI

# Check image trong ACR
az acr repository show-tags --name acrftmbackenddev --repository ftm-backend --orderby time_desc --output table

# Check GitOps repo được update
cd E:\AKS-DEMO\Infrastructure
git pull
cat applications/overlays/dev/kustomization.yaml

# Check pods deployment
kubectl get pods -n ftm-dev -o wide
kubectl describe pod <pod-name> -n ftm-dev

# Check application
curl http://longops.io.vn/api/health
```

---

## 7. Troubleshooting

### Jenkins không nhận webhook

```powershell
# Check Jenkins service
kubectl get svc jenkins -n jenkins

# Check ingress
kubectl get ingress -n jenkins
kubectl describe ingress jenkins -n jenkins

# Test webhook từ GitHub
# → GitHub repo → Settings → Webhooks → Recent Deliveries
# → Click vào delivery → Xem Request/Response
```

### Build failed - Docker login

```powershell
# Verify ACR credentials
az acr credential show --name acrftmbackenddev

# Check credentials trong Jenkins
# Manage Jenkins → Credentials → acr-credentials
```

### Build failed - Git clone

```powershell
# Verify GitHub PAT còn valid
# https://github.com/settings/tokens

# Test clone manually
git clone https://github.com/longtpit2573/FTM-BE.git
```

### Pipeline không update GitOps repo

- Check `git-credentials` có đủ quyền `repo` và `workflow`
- Verify GitOps repo URL trong Jenkinsfile
- Check Git config trong Jenkins pod:
  ```powershell
  kubectl exec -it jenkins-0 -n jenkins -- git config --global user.name
  ```

---

## 8. Security Best Practices

1. **Đổi Jenkins admin password:**
   - Manage Jenkins → Users → admin → Configure → Password

2. **Enable CSRF Protection:**
   - Manage Jenkins → Security → Prevent Cross Site Request Forgery exploits (đã enabled mặc định)

3. **Rotate secrets định kỳ:**
   - ACR passwords: 90 days
   - GitHub PAT: 90 days
   - Jenkins admin password: 90 days

4. **Backup Jenkins configuration:**
   ```powershell
   kubectl get pvc -n jenkins
   # PVC jenkins chứa toàn bộ config và job history
   ```

---

## 9. Next Steps

- [ ] Setup Slack notifications cho build status
- [ ] Configure email notifications
- [ ] Add SonarQube integration cho code quality
- [ ] Setup staging environment pipeline
- [ ] Configure Jenkins backup schedule
- [ ] Add security scanning (Trivy, Snyk) vào pipeline
- [ ] Setup monitoring cho Jenkins với Prometheus/Grafana

---

## Appendix: Useful Commands

```powershell
# Get Jenkins password
kubectl get secret jenkins -n jenkins -o jsonpath="{.data.jenkins-admin-password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }

# Restart Jenkins pod
kubectl rollout restart statefulset jenkins -n jenkins

# View Jenkins logs
kubectl logs -f jenkins-0 -n jenkins

# Port forward (nếu DNS chưa hoạt động)
kubectl port-forward svc/jenkins -n jenkins 8080:8080

# Check ACR repositories
az acr repository list --name acrftmbackenddev --output table
az acr repository list --name acrftmfrontenddev --output table

# Check ArgoCD sync status
kubectl get application ftm-dev -n argocd
```
