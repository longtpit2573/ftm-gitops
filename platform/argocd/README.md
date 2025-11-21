# ArgoCD Infrastructure

> All ArgoCD-related configurations in one place

## 📁 Files in this directory

### Application Definitions
- **`app-dev.yaml`**: ArgoCD Application for dev environment
  - Defines what to deploy (applications/overlays/dev)
  - Auto-sync enabled with prune and self-heal
  - Deploys to ftm-dev namespace

### ArgoCD Configuration
- **`project.yaml`**: ArgoCD Project with RBAC
  - Defines source repos whitelist
  - Destination namespaces (ftm-*)
  - Roles: developer (read-only), devops (full access)

- **`ingress.yaml`**: Exposes ArgoCD UI
  - URL: http://argocd.longops.io.vn
  - Uses Nginx Ingress Controller
  - HTTP only (server.insecure mode)

## 🚀 Deployment

### Step 1: Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s
```

### Step 2: Configure for HTTP Ingress

```bash
# Enable insecure mode (no TLS)
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'

# Restart server to apply changes
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd
```

### Step 3: Apply all ArgoCD infrastructure

```bash
# Apply Project, Ingress, and Applications
kubectl apply -f infrastructure/argocd/

# Or apply individually:
kubectl apply -f infrastructure/argocd/project.yaml
kubectl apply -f infrastructure/argocd/ingress.yaml
kubectl apply -f infrastructure/argocd/app-dev.yaml
```

### Step 4: Get admin credentials

```bash
# Get initial admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Or use PowerShell:
$password = kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}"
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($password))
```

## 🌐 Access

### ArgoCD UI
- **URL**: http://argocd.longops.io.vn
- **Username**: `admin`
- **Password**: Get from secret (see above)

### DNS Setup
Add DNS A record at your DNS provider (e.g., tenten.vn):
```
Host: argocd.longops.io.vn
Type: A
Value: 4.144.199.99  # Your Ingress LoadBalancer IP
TTL: 300
```

## 📋 Applications

### ftm-dev

Current application deployed:

```yaml
Name: ftm-dev
Source:
  Repo: https://github.com/longtpit2573/ftm-gitops.git
  Path: applications/overlays/dev
  Branch: main

Destination:
  Cluster: in-cluster (https://kubernetes.default.svc)
  Namespace: ftm-dev

Sync Policy:
  Automated: Yes
  Prune: Yes (delete resources not in Git)
  Self Heal: Yes (revert manual changes)
  Create Namespace: Yes
```

### Adding New Applications

Create new application YAML file:

```yaml
# infrastructure/argocd/app-staging.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: ftm-staging
  namespace: argocd
spec:
  project: ftm-project
  
  source:
    repoURL: https://github.com/longtpit2573/ftm-gitops.git
    targetRevision: main
    path: applications/overlays/staging
  
  destination:
    server: https://kubernetes.default.svc
    namespace: ftm-staging
  
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

Then apply:
```bash
kubectl apply -f infrastructure/argocd/app-staging.yaml
```

## 🔧 Configuration Details

### Why server.insecure?

ArgoCD by default expects HTTPS. Since we use:
- Nginx Ingress without TLS termination
- HTTP only (no SSL certificates)

We need to tell ArgoCD to accept HTTP connections:
```bash
kubectl patch configmap argocd-cmd-params-cm -n argocd \
  --type merge \
  -p '{"data":{"server.insecure":"true"}}'
```

### Ingress Annotations

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "false"  # Don't force HTTPS
  nginx.ingress.kubernetes.io/backend-protocol: "HTTP"  # Backend uses HTTP
```

## 🔍 Monitoring

### Check ArgoCD Status

```bash
# Check all pods
kubectl get pods -n argocd

# Check applications
kubectl get applications -n argocd

# Get application details
kubectl get application ftm-dev -n argocd -o yaml
```

### Check Sync Status

```bash
# Using kubectl
kubectl get application ftm-dev -n argocd -o jsonpath='{.status.sync.status}'

# Using ArgoCD CLI
argocd app get ftm-dev
```

## 🔄 Operations

### Manual Sync

```bash
# Via CLI
argocd app sync ftm-dev

# Via kubectl
kubectl patch application ftm-dev -n argocd \
  --type merge \
  -p '{"operation":{"initiatedBy":{"username":"admin"},"sync":{}}}'
```

### View Logs

```bash
# Application controller logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller -f

# Server logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server -f
```

## 🔧 Troubleshooting

### Application OutOfSync

```bash
# Check diff
argocd app diff ftm-dev

# Force sync
argocd app sync ftm-dev --force
```

### Cannot Access UI

```bash
# Check ingress
kubectl get ingress -n argocd
kubectl describe ingress argocd-ingress -n argocd

# Check service
kubectl get svc argocd-server -n argocd

# Check DNS
nslookup argocd.longops.io.vn 8.8.8.8
```

### ComparisonError

If ArgoCD shows "ComparisonError" or cannot sync:

```bash
# Check repo access
argocd repo list

# Re-add repo if needed
argocd repo add https://github.com/longtpit2573/ftm-gitops.git
```

## 📚 Documentation

- **ARGOCD_USAGE_GUIDE.md**: Detailed ArgoCD usage guide
- **Official Docs**: https://argo-cd.readthedocs.io
- **Best Practices**: https://argoproj.github.io/argo-cd/user-guide/best_practices/

## 🔗 Related

- **Applications**: `../../applications/`
- **Jenkins**: `../jenkins/`
- **Scripts**: `../../scripts/`

---

**Best Practice**: Keep all ArgoCD configurations in this directory for easy management and team collaboration.
