# 📘 ArgoCD Usage Guide - Professional GitOps Workflow

## 🎯 Mục Lục

1. [Giới thiệu ArgoCD](#giới-thiệu-argocd)
2. [Kiến trúc và Khái niệm](#kiến-trúc-và-khái-niệm)
3. [Truy cập ArgoCD UI](#truy-cập-argocd-ui)
4. [Quản lý Applications](#quản-lý-applications)
5. [Sync Operations](#sync-operations)
6. [Monitoring và Troubleshooting](#monitoring-và-troubleshooting)
7. [Best Practices](#best-practices)
8. [ArgoCD CLI](#argocd-cli)
9. [Advanced Features](#advanced-features)

---

## 📖 Giới thiệu ArgoCD

**ArgoCD** là công cụ Continuous Delivery (CD) cho Kubernetes, theo mô hình **GitOps** - Git là nguồn chân lý duy nhất (Single Source of Truth).

### Tại sao dùng ArgoCD?

```
┌─────────────────────────────────────────────────────────────┐
│                    GitOps Workflow                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. Developer push code → Git                               │
│  2. CI build → Push image → ACR                             │
│  3. CI update manifest → Git                                │
│  4. ArgoCD detect change                                    │
│  5. ArgoCD sync → Kubernetes                                │
│  6. Kubernetes deploy → Production                          │
│                                                             │
│  ✅ Audit trail (Git history)                               │
│  ✅ Rollback dễ dàng (Git revert)                           │
│  ✅ Multi-cluster deployment                                │
│  ✅ Self-healing (auto fix drift)                           │
└─────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Kiến trúc và Khái niệm

### Core Concepts

```yaml
Application:
  - Đại diện cho một ứng dụng K8s
  - Liên kết Git repo → K8s cluster
  - Định nghĩa sync policy

Project:
  - Nhóm nhiều applications
  - Định nghĩa RBAC (ai được làm gì)
  - Giới hạn source repos và destinations

Sync Status:
  - Synced: Git == Cluster ✅
  - OutOfSync: Git ≠ Cluster ⚠️
  - Unknown: Không xác định được 🤷

Health Status:
  - Healthy: Resources chạy OK ✅
  - Progressing: Đang deploy 🔄
  - Degraded: Có lỗi ❌
  - Suspended: Tạm dừng ⏸️
```

### ArgoCD Architecture

```
┌──────────────────────────────────────────────────────────┐
│                    ArgoCD Server                         │
│  ┌────────────┐  ┌──────────────┐  ┌────────────────┐  │
│  │   Web UI   │  │  gRPC API    │  │  REST API      │  │
│  └────────────┘  └──────────────┘  └────────────────┘  │
└────────────┬─────────────────────────────────────────────┘
             │
    ┌────────┴────────┐
    │                 │
    ▼                 ▼
┌─────────────┐  ┌──────────────────┐
│ Git Repo    │  │ Kubernetes API   │
│ (Source)    │  │ (Destination)    │
└─────────────┘  └──────────────────┘
```

---

## 🔐 Truy cập ArgoCD UI

### Login

```bash
URL: http://argocd.longops.io.vn
Username: admin
Password: lmwA4QsIuLV-wJMa  # Lấy từ: kubectl -n argocd get secret argocd-initial-admin-secret
```

### Đổi Password (Bắt buộc sau lần đầu login)

**UI:**
1. Click **User Info** (góc phải trên)
2. Click **Update Password**
3. Nhập old password và new password
4. Click **Save**

**CLI:**
```bash
argocd account update-password
```

---

## 📦 Quản lý Applications

### Applications View

```
┌───────────────────────────────────────────────────────────┐
│  Applications                          [+ NEW APP]         │
├───────────────────────────────────────────────────────────┤
│                                                           │
│  □ ftm-dev                                                │
│    Status: Synced ✅    Health: Healthy ✅                │
│    Repo: github.com/longtpit2573/ftm-gitops               │
│    Path: overlays/dev                                     │
│    Namespace: ftm-dev                                     │
│    Last Sync: 5 minutes ago                               │
│                                                           │
└───────────────────────────────────────────────────────────┘
```

### Application Details - Tree View

Click vào application để xem chi tiết:

```
ftm-dev
├── Namespace (ftm-dev)
│   ├── ConfigMap (ftm-backend-config)
│   ├── ConfigMap (ftm-frontend-config)
│   ├── Secret (ftm-backend-secrets)
│   │
│   ├── Service (ftm-backend-service)
│   │   └── Endpoints
│   │
│   ├── Deployment (ftm-backend)
│   │   └── ReplicaSet
│   │       └── Pod (ftm-backend-xxx) ✅ Running
│   │
│   ├── Service (ftm-frontend-service)
│   │   └── Endpoints
│   │
│   ├── Deployment (ftm-frontend)
│   │   └── ReplicaSet
│   │       └── Pod (ftm-frontend-xxx) ✅ Running
│   │
│   └── Ingress (ftm-ingress)
│       ├── Rule: longops.io.vn/api → backend
│       └── Rule: longops.io.vn/ → frontend
```

### View Options

**1. Tree View** (Mặc định)
- Hiển thị cấu trúc phân cấp
- Dễ nhìn relationships giữa resources
- **Use case:** Debug dependencies

**2. Network View**
```
┌─────────────┐      ┌──────────────┐      ┌─────────┐
│   Ingress   │─────→│   Service    │─────→│   Pod   │
└─────────────┘      └──────────────┘      └─────────┘
```
- Hiển thị network topology
- **Use case:** Hiểu traffic flow

**3. List View**
- Dạng bảng (table)
- **Use case:** Scan nhanh nhiều resources

---

## 🔄 Sync Operations

### Manual Sync

**Khi nào cần Sync:**
- Git repo có commit mới
- Cluster bị drift (ai đó sửa trực tiếp bằng kubectl)
- Muốn deploy version mới

**Cách Sync:**

1. Click button **SYNC** trên toolbar
2. Popup hiện ra với options:

```
┌────────────────────────────────────────┐
│  Synchronize Application               │
├────────────────────────────────────────┤
│                                        │
│  Revision: HEAD ▼                      │
│                                        │
│  Options:                              │
│  ☑ Prune Resources                     │
│  ☐ Dry Run                             │
│  ☐ Apply Only                          │
│  ☐ Force                               │
│                                        │
│  Select Resources:                     │
│  ☑ All (15 resources)                  │
│  ☐ Deployment/ftm-backend              │
│  ☐ Deployment/ftm-frontend             │
│  ...                                   │
│                                        │
│  [SYNCHRONIZE]  [CANCEL]               │
└────────────────────────────────────────┘
```

### Sync Options Explained

| Option | Mô tả | Khi nào dùng |
|--------|-------|--------------|
| **Prune** | Xóa resources không có trong Git | Khi xóa manifest khỏi Git |
| **Dry Run** | Preview thay đổi, không apply | Test trước khi deploy thật |
| **Apply Only** | Chỉ apply, không sync | Debug specific resources |
| **Force** | Replace resources (kubectl replace) | Khi có conflict |

### Auto-Sync Configuration

**Enable trong Application manifest:**

```yaml
spec:
  syncPolicy:
    automated:
      prune: true        # Tự động xóa resources thừa
      selfHeal: true     # Tự động fix drift
      allowEmpty: false  # Không cho phép xóa hết resources
```

**⚠️ Cảnh báo:**
- **Prune**: Cẩn thận! Có thể xóa data
- **SelfHeal**: Sẽ revert mọi thay đổi manual trong cluster

---

## 📊 Monitoring và Troubleshooting

### 1. View Logs

**Pod Logs:**
1. Click vào **Pod** (màu xanh lá)
2. Tab **LOGS** xuất hiện
3. Options:
   - **Container**: Chọn container (nếu multi-container)
   - **Tail**: Số dòng hiển thị
   - **Follow**: Real-time streaming
   - **Since**: Thời gian (1h, 24h, ...)

**Filter logs:**
```bash
# Tìm errors
grep -i error

# Tìm warnings  
grep -i warning
```

### 2. Terminal vào Pod

1. Click vào **Pod**
2. Tab **TERMINAL**
3. Chọn container
4. Gõ lệnh:

```bash
# Check environment variables
env | grep JWT

# Check disk space
df -h

# Check processes
ps aux

# Network test
curl http://ftm-backend-service/health

# Check files
ls -la /app
cat /app/appsettings.json
```

### 3. Resource Details

**View YAML:**
1. Click icon **⋮** (3 chấm) bên resource
2. Chọn **Details**
3. Xem full YAML manifest

**Live vs Desired State:**
```
┌──────────────────────────────────────────────┐
│  Desired (Git)         Live (Cluster)        │
├──────────────────────────────────────────────┤
│  replicas: 2          replicas: 1            │
│  image: v1.0.2        image: v1.0.1          │
│                                              │
│  → OutOfSync ⚠️                              │
└──────────────────────────────────────────────┘
```

### 4. Events

**View Events:**
```bash
kubectl get events -n ftm-dev --sort-by='.lastTimestamp'
```

**Common Events:**
- `Pulled`: Image pulled successfully
- `Created`: Container created
- `Started`: Container started
- `Failed`: Lỗi (xem message)
- `BackOff`: CrashLoopBackOff

### 5. Diff View

**So sánh Git vs Cluster:**

1. Click button **APP DIFF**
2. Xem side-by-side comparison

```diff
# Git (Desired)
- replicas: 1
+ replicas: 2

# Cluster (Live)  
  replicas: 1
```

---

## 🎯 Best Practices

### 1. Application Structure

```
✅ Good:
ftm-gitops/
├── base/              # Shared configs
│   ├── backend/
│   └── frontend/
└── overlays/          # Environment-specific
    ├── dev/
    └── prod/

❌ Bad:
manifests/
├── backend-dev.yaml   # Duplicate code
├── backend-prod.yaml
├── frontend-dev.yaml
└── frontend-prod.yaml
```

### 2. Sync Policy Strategy

**Development:**
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
```
→ Deploy ngay, fix drift tự động

**Production:**
```yaml
syncPolicy:
  automated: null  # Manual sync only
```
→ Cần approval trước khi deploy

### 3. Secret Management

**❌ Never:**
```yaml
# Don't commit secrets to Git!
data:
  password: bXlwYXNzd29yZA==
```

**✅ Best:**
```bash
# Store secrets in Kubernetes directly
kubectl create secret generic app-secrets \
  --from-literal=password='...' \
  -n ftm-dev

# Reference in deployment
envFrom:
  - secretRef:
      name: app-secrets
```

**🏆 Enterprise:**
- **Azure Key Vault** + CSI Driver
- **Sealed Secrets** (encrypt in Git)
- **External Secrets Operator**

### 4. Resource Limits

**Always set:**
```yaml
resources:
  requests:      # Minimum guarantee
    cpu: 100m
    memory: 256Mi
  limits:        # Maximum allowed
    cpu: 500m
    memory: 512Mi
```

### 5. Health Checks

```yaml
livenessProbe:    # Container alive?
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 30
  periodSeconds: 10

readinessProbe:   # Ready to serve traffic?
  httpGet:
    path: /ready
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 5
```

---

## 💻 ArgoCD CLI

### Installation

```bash
# Windows (PowerShell)
$version = "v2.9.3"
$url = "https://github.com/argoproj/argo-cd/releases/download/$version/argocd-windows-amd64.exe"
Invoke-WebRequest -Uri $url -OutFile argocd.exe

# Linux/Mac
curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
chmod +x argocd
sudo mv argocd /usr/local/bin/
```

### Login

```bash
# Login to ArgoCD
argocd login argocd.longops.io.vn \
  --username admin \
  --password 'lmwA4QsIuLV-wJMa' \
  --insecure
```

### Common Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get ftm-dev

# Sync application
argocd app sync ftm-dev

# Sync with prune
argocd app sync ftm-dev --prune

# Watch sync status
argocd app sync ftm-dev --watch

# Rollback to previous version
argocd app rollback ftm-dev

# View history
argocd app history ftm-dev

# Delete application
argocd app delete ftm-dev

# Diff (Git vs Cluster)
argocd app diff ftm-dev

# Manifests (preview YAML)
argocd app manifests ftm-dev
```

### Sync Specific Resources

```bash
# Sync only backend
argocd app sync ftm-dev \
  --resource apps:Deployment:ftm-backend

# Sync multiple resources
argocd app sync ftm-dev \
  --resource apps:Deployment:ftm-backend \
  --resource v1:Service:ftm-backend-service
```

---

## 🚀 Advanced Features

### 1. Sync Waves

**Deploy resources theo thứ tự:**

```yaml
# 1. Database first
apiVersion: v1
kind: Service
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "0"

# 2. Backend second
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"

# 3. Frontend last
apiVersion: apps/v1
kind: Deployment
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "2"
```

### 2. Sync Hooks

**Chạy jobs trước/sau sync:**

```yaml
# Pre-sync: DB migration
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: HookSucceeded

# Post-sync: Cache warming
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: PostSync
```

### 3. Resource Ignore

**Ignore specific fields:**

```yaml
# Application
metadata:
  annotations:
    argocd.argoproj.io/compare-options: IgnoreExtraneous

# Ignore replicas (HPA manages it)
spec:
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas
```

### 4. Notifications

**Slack integration:**

```yaml
# ConfigMap: argocd-notifications-cm
apiVersion: v1
kind: ConfigMap
data:
  service.slack: |
    token: xoxb-your-token
  
  trigger.on-deployed: |
    - when: app.status.operationState.phase in ['Succeeded']
      send: [app-deployed]
  
  template.app-deployed: |
    message: |
      Application {{.app.metadata.name}} deployed!
      Version: {{.app.status.sync.revision}}
```

### 5. Multi-Cluster Management

**Add cluster:**

```bash
# Get kubeconfig for new cluster
az aks get-credentials --resource-group rg-prod --name aks-prod

# Add to ArgoCD
argocd cluster add aks-prod-context \
  --name production-cluster

# Deploy to multiple clusters
argocd app create multi-app \
  --dest-server https://prod-cluster-api \
  --dest-namespace production
```

### 6. ApplicationSets

**Deploy đến nhiều environments tự động:**

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: ftm-multi-env
spec:
  generators:
    - list:
        elements:
          - env: dev
            replicas: 1
          - env: staging
            replicas: 2
          - env: production
            replicas: 3
  
  template:
    metadata:
      name: 'ftm-{{env}}'
    spec:
      source:
        path: overlays/{{env}}
      destination:
        namespace: 'ftm-{{env}}'
      syncPolicy:
        automated:
          prune: true
```

---

## 📚 Workflow Examples

### Scenario 1: Deploy New Version

```bash
# 1. Developer commit code
git commit -m "feat: new feature"
git push

# 2. CI build and push image
docker build -t acrftmbackenddev.azurecr.io/ftm-backend:v1.0.5 .
docker push acrftmbackenddev.azurecr.io/ftm-backend:v1.0.5

# 3. Update manifest
cd ftm-gitops/overlays/dev
kustomize edit set image ftm-backend:v1.0.5
git commit -m "deploy: update to v1.0.5"
git push

# 4. ArgoCD auto-sync (or manual)
argocd app sync ftm-dev --watch

# 5. Verify
kubectl get pods -n ftm-dev
curl http://longops.io.vn/api/health
```

### Scenario 2: Rollback

```bash
# View history
argocd app history ftm-dev

# Rollback to revision 5
argocd app rollback ftm-dev 5

# Or via Git
git revert HEAD
git push
argocd app sync ftm-dev
```

### Scenario 3: Emergency Fix (Hotfix)

```bash
# 1. Fix code and build
git commit -m "hotfix: critical bug"
docker build -t ...:hotfix-123 .
docker push

# 2. Update manifest
kustomize edit set image ftm-backend:hotfix-123
git commit -m "hotfix: deploy emergency patch"
git push

# 3. Force sync immediately
argocd app sync ftm-dev --force --prune

# 4. Monitor
argocd app wait ftm-dev --health
```

---

## 🔍 Troubleshooting Guide

### Problem: Application OutOfSync

**Cause:** Git ≠ Cluster

**Solution:**
```bash
# Check diff
argocd app diff ftm-dev

# Sync to Git state
argocd app sync ftm-dev --prune
```

### Problem: Sync Failed

**Cause:** Invalid YAML, resource conflict

**Solution:**
```bash
# Check logs
argocd app logs ftm-dev

# Validate manifests locally
kustomize build overlays/dev | kubectl apply --dry-run=client -f -

# Force sync
argocd app sync ftm-dev --force
```

### Problem: Pod CrashLoopBackOff

**Cause:** Application error

**Solution:**
```bash
# View logs
kubectl logs -f pod-name -n ftm-dev

# Check events
kubectl describe pod pod-name -n ftm-dev

# Terminal into pod
kubectl exec -it pod-name -n ftm-dev -- sh
```

### Problem: Service Unavailable

**Cause:** Service/Ingress misconfigured

**Solution:**
```bash
# Check service
kubectl get svc -n ftm-dev
kubectl describe svc ftm-backend-service -n ftm-dev

# Check endpoints
kubectl get endpoints -n ftm-dev

# Check ingress
kubectl get ingress -n ftm-dev
kubectl describe ingress ftm-ingress -n ftm-dev

# Test internal connectivity
kubectl run test --rm -it --image=busybox -- wget -O- http://ftm-backend-service
```

---

## 📖 Additional Resources

- **Official Docs:** https://argo-cd.readthedocs.io
- **Best Practices:** https://argoproj.github.io/argo-cd/user-guide/best_practices/
- **Examples:** https://github.com/argoproj/argocd-example-apps
- **Community:** https://argoproj.github.io/community/

---

## 🎓 Summary - Key Takeaways

✅ **ArgoCD = GitOps CD cho Kubernetes**
✅ **Git là source of truth duy nhất**
✅ **Auto-sync dev, manual prod**
✅ **Dùng Tree View để debug**
✅ **Terminal/Logs để troubleshoot**
✅ **Sync with Prune để xóa resources thừa**
✅ **Rollback = Git revert**
✅ **Never commit secrets to Git**

---

*Tài liệu này được tạo cho dự án Family Tree Management (FTM)*  
*Author: GitHub Copilot | Date: November 2025*
