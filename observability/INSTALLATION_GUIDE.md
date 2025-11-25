# 📚 Hướng dẫn Cài đặt Observability Stack - AKS

> **Tài liệu:** Hướng dẫn từng bước cài đặt full observability stack (Prometheus, Grafana, Loki, Tempo, Fluent Bit, Alertmanager)  
> **Môi trường:** Azure Kubernetes Service (AKS)  
> **Cập nhật:** November 2025

---

## 📋 Mục lục

1. [Yêu cầu hệ thống](#-yêu-cầu-hệ-thống)
2. [Kiến trúc tổng quan](#-kiến-trúc-tổng-quan)
3. [Cài đặt Prometheus + Grafana](#-bước-1-cài-đặt-prometheus--grafana)
4. [Cài đặt Loki](#-bước-2-cài-đặt-loki)
5. [Cài đặt Tempo](#-bước-3-cài-đặt-tempo)
6. [Cài đặt Fluent Bit](#-bước-4-cài-đặt-fluent-bit)
7. [Cấu hình Alertmanager](#-bước-5-cấu-hình-alertmanager)
8. [Cấu hình DNS](#-bước-6-cấu-hình-dns)
9. [Xác thực cài đặt](#-bước-7-xác-thực-cài-đặt)
10. [Troubleshooting](#-troubleshooting)

---

## 🔧 Yêu cầu hệ thống

### Kubernetes Cluster
- **AKS Cluster**: 1.28+ (tested on 1.31.13)
- **Node Pool**: Standard_D2s_v3 hoặc lớn hơn
- **RAM**: Minimum 8GB per node (recommended 16GB)
- **CPU**: Minimum 2 vCPU per node
- **Storage**: Azure Managed Disks (Premium_LRS)

### Resource Requirements

| Component | CPU Request | Memory Request | Storage |
|-----------|-------------|----------------|---------|
| Prometheus | 100m | 256Mi | 10Gi |
| Grafana | 100m | 256Mi | 5Gi |
| Alertmanager | 50m | 128Mi | 2Gi |
| Loki | 100m | 256Mi | 10Gi |
| Tempo | 100m | 256Mi | 10Gi |
| Fluent Bit | 50m/node | 64Mi/node | - |
| **TOTAL** | ~600m + 50m/node | ~1200Mi + 64Mi/node | ~37Gi |

**Ví dụ:** 1 node D2s_v3 (2 vCPU, 8GB RAM) = ~7GB allocatable  
→ Đủ cho dev environment với 1 node

### Tools cần cài đặt
```bash
# PowerShell trên Windows
winget install Kubernetes.kubectl
winget install Helm.Helm

# Hoặc Chocolatey
choco install kubernetes-cli helm

# Kiểm tra version
kubectl version --client
helm version
```

### Access Requirements
- **kubectl** configured với AKS cluster
- **Helm 3.x** installed
- **Ingress Controller** (nginx) đã deploy
- **DNS Control** (để tạo A records)

---

## 🏗️ Kiến trúc tổng quan

```
┌─────────────────────────────────────────────────────────────┐
│                    OBSERVABILITY STACK                      │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  Prometheus  │    │     Loki     │    │    Tempo     │  │
│  │   (Metrics)  │    │    (Logs)    │    │   (Traces)   │  │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘  │
│         │                   │                   │          │
│         └───────────────────┼───────────────────┘          │
│                             │                              │
│                    ┌────────▼────────┐                     │
│                    │    Grafana      │                     │
│                    │  (Visualization)│                     │
│                    └────────┬────────┘                     │
│                             │                              │
│                    ┌────────▼────────┐                     │
│                    │ Alertmanager    │                     │
│                    │ (Email Alerts)  │                     │
│                    └─────────────────┘                     │
│                                                             │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Fluent Bit (DaemonSet)                  │  │
│  │         Collects logs from all pods                  │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                            │
                            │ Ingress (HTTPS)
                            ▼
                ┌──────────────────────┐
                │  grafana.domain.com  │
                │    loki.domain.com   │
                │   tempo.domain.com   │
                └──────────────────────┘
```

---

## 📦 BƯỚC 1: Cài đặt Prometheus + Grafana

### 1.1. Chuẩn bị Helm Repository

```powershell
# Add Prometheus Community Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Verify repo
helm search repo prometheus-community/kube-prometheus-stack
```

### 1.2. Tạo Namespace

```powershell
kubectl create namespace monitoring
kubectl label namespace monitoring name=monitoring
```

### 1.3. Review Configuration

File: `Infrastructure/observability/prometheus/values.yaml`

**Các cấu hình quan trọng:**

```yaml
# Prometheus Server
prometheus:
  prometheusSpec:
    retention: 7d              # Giữ metrics 7 ngày
    storageSpec:
      volumeClaimTemplate:
        spec:
          resources:
            requests:
              storage: 10Gi    # 10GB storage
    
    resources:
      requests:
        cpu: 100m
        memory: 256Mi          # Tối ưu cho dev

# Grafana
grafana:
  adminPassword: "Admin@123456"  # ⚠️ ĐỔI SAU KHI CÀI!
  ingress:
    enabled: true
    hosts:
      - grafana.longops.io.vn  # 🔧 ĐỔI DOMAIN CỦA BẠN
```

**📝 Sửa file values.yaml:**

```powershell
# Mở file
code E:\AKS-DEMO\Infrastructure\observability\prometheus\values.yaml

# Tìm và sửa:
# 1. Line ~68: grafana.longops.io.vn → YOUR_DOMAIN
# 2. Line ~43: adminPassword → YOUR_STRONG_PASSWORD (nếu muốn)
```

### 1.4. Deploy Prometheus Stack

```powershell
cd E:\AKS-DEMO\Infrastructure\observability\prometheus

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --create-namespace `
  --values values.yaml `
  --wait `
  --timeout 10m
```

**Output mong đợi:**
```
Release "prometheus" does not exist. Installing it now.
NAME: prometheus
LAST DEPLOYED: Mon Nov 25 14:30:00 2025
NAMESPACE: monitoring
STATUS: deployed
REVISION: 1
```

### 1.5. Verify Deployment

```powershell
# Check pods
kubectl get pods -n monitoring

# Expected output:
# NAME                                                     READY   STATUS
# prometheus-prometheus-prometheus-0                      3/3     Running
# prometheus-grafana-xxxxx-xxxxx                          3/3     Running
# prometheus-kube-state-metrics-xxxxx-xxxxx               1/1     Running
# prometheus-prometheus-node-exporter-xxxxx               1/1     Running
# prometheus-prometheus-operator-xxxxx-xxxxx              1/1     Running

# Check services
kubectl get svc -n monitoring

# Check PVC
kubectl get pvc -n monitoring
```

**Thời gian deploy:** ~5-10 phút (pull images + create PVs)

### 1.6. Access Grafana

**Option A: Port Forward (Test local)**
```powershell
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
# Truy cập: http://localhost:3000
# Username: admin
# Password: Admin@123456 (hoặc password bạn đã đổi)
```

**Option B: Ingress (Production)**
```powershell
# Get Ingress IP
kubectl get ingress -n monitoring prometheus-grafana

# Output:
# NAME                 CLASS   HOSTS                   ADDRESS          PORTS
# prometheus-grafana   nginx   grafana.longops.io.vn   4.144.199.99     80, 443

# Sau khi setup DNS (Bước 6):
# Truy cập: https://grafana.longops.io.vn
```

---

## 📦 BƯỚC 2: Cài đặt Loki

### 2.1. Thêm Grafana Helm Repo

```powershell
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update
```

### 2.2. Review Configuration

File: `Infrastructure/observability/loki/values.yaml`

**Cấu hình SingleBinary mode (tiết kiệm resources):**

```yaml
deploymentMode: SingleBinary  # Single pod = ít resource hơn
loki:
  commonConfig:
    replication_factor: 1     # Không replicate (dev only)
  storage:
    type: filesystem          # Store trên disk
  schemaConfig:
    configs:
      - from: "2024-01-01"
        store: tsdb
        index:
          period: 24h
  limits_config:
    retention_period: 168h    # 7 days

gateway:
  ingress:
    enabled: true
    hosts:
      - host: loki.longops.io.vn  # 🔧 ĐỔI DOMAIN
```

**📝 Sửa domain:**
```powershell
code E:\AKS-DEMO\Infrastructure\observability\loki\values.yaml
# Line ~83: loki.longops.io.vn → YOUR_DOMAIN
```

### 2.3. Deploy Loki

```powershell
cd E:\AKS-DEMO\Infrastructure\observability\loki

helm upgrade --install loki grafana/loki `
  --namespace monitoring `
  --values values.yaml `
  --wait `
  --timeout 10m
```

### 2.4. Verify Loki

```powershell
kubectl get pods -n monitoring -l app.kubernetes.io/name=loki

# Expected:
# loki-0                    1/1     Running
# loki-gateway-xxxxx        1/1     Running

# Test Loki API
kubectl port-forward -n monitoring svc/loki-gateway 3100:80

# Trong terminal khác:
curl http://localhost:3100/ready
# Output: ready
```

---

## 📦 BƯỚC 3: Cài đặt Tempo

### 3.1. Review Configuration

File: `Infrastructure/observability/tempo/values.yaml`

**Cấu hình Distributed Tracing:**

```yaml
tempo:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
  
  retention: 168h  # 7 days
  
  # Receivers for different protocols
  receivers:
    otlp:
      protocols:
        http:
          endpoint: 0.0.0.0:4318  # OpenTelemetry HTTP
        grpc:
          endpoint: 0.0.0.0:4317  # OpenTelemetry gRPC
    jaeger:
      protocols:
        thrift_http:
          endpoint: 0.0.0.0:14268
        grpc:
          endpoint: 0.0.0.0:14250
    zipkin:
      endpoint: 0.0.0.0:9411

ingress:
  enabled: true
  hosts:
    - host: tempo.longops.io.vn  # 🔧 ĐỔI DOMAIN
```

**📝 Sửa domain:**
```powershell
code E:\AKS-DEMO\Infrastructure\observability\tempo\values.yaml
# Line ~54: tempo.longops.io.vn → YOUR_DOMAIN
```

### 3.2. Deploy Tempo

```powershell
cd E:\AKS-DEMO\Infrastructure\observability

helm upgrade --install tempo grafana/tempo `
  --namespace monitoring `
  --values tempo/values.yaml `
  --wait `
  --timeout 10m
```

### 3.3. Verify Tempo

```powershell
kubectl get pods -n monitoring -l app.kubernetes.io/name=tempo

# Expected:
# tempo-xxxxx-xxxxx    1/1     Running

# Test Tempo ready
kubectl port-forward -n monitoring svc/tempo 3100:3100
curl http://localhost:3100/ready
```

---

## 📦 BƯỚC 4: Cài đặt Fluent Bit

### 4.1. Review Configuration

File: `Infrastructure/observability/fluent-bit/values.yaml`

**DaemonSet - Chạy trên mọi node:**

```yaml
config:
  inputs: |
    [INPUT]
        Name              tail
        Path              /var/log/containers/*.log
        Parser            docker
        Tag               kube.*
        Refresh_Interval  5
        Mem_Buf_Limit     5MB

  outputs: |
    [OUTPUT]
        Name   loki
        Match  *
        Host   loki-gateway.monitoring.svc.cluster.local
        Port   80
        Labels job=fluentbit, container=$kubernetes['container_name']
```

### 4.2. Deploy Fluent Bit

```powershell
helm repo add fluent https://fluent.github.io/helm-charts
helm repo update

cd E:\AKS-DEMO\Infrastructure\observability

helm upgrade --install fluent-bit fluent/fluent-bit `
  --namespace monitoring `
  --values fluent-bit/values.yaml `
  --wait
```

### 4.3. Verify Fluent Bit

```powershell
# Should have 1 pod per node
kubectl get pods -n monitoring -l app.kubernetes.io/name=fluent-bit -o wide

# Check logs
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=50

# Should see:
# [info] [output:loki:loki.0] loki_gateway.monitoring.svc.cluster.local:80, HTTP status=204
```

---

## 📦 BƯỚC 5: Cấu hình Alertmanager

### 5.1. Tạo Gmail App Password

**⚠️ YÊU CẦU: Gmail account với 2FA enabled**

1. **Bật 2-Factor Authentication:**
   - Truy cập: https://myaccount.google.com/security
   - Security → 2-Step Verification → Bật

2. **Tạo App Password:**
   - Truy cập: https://myaccount.google.com/apppasswords
   - App name: "AKS Alertmanager"
   - Click "Generate"
   - **Copy 16-ký tự password** (ví dụ: `abcd efgh ijkl mnop`)

### 5.2. Cấu hình Alertmanager

File: `Infrastructure/observability/prometheus/alertmanager-gmail-config.yaml`

**📝 Sửa thông tin:**

```powershell
code E:\AKS-DEMO\Infrastructure\observability\prometheus\alertmanager-gmail-config.yaml
```

**Cần sửa 3 chỗ:**

```yaml
# 1. Secret - Line 12
data:
  smtp-password: YWJjZCBlZmdoIGlqa2wgbW5vcA==  # Base64 của app password
  # Generate: [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes("abcd efgh ijkl mnop"))

# 2. ConfigMap - Line 35
smtp_auth_username: 'your-email@gmail.com'  # Email của bạn

# 3. ConfigMap - Line 52
receivers:
  - name: 'critical-alerts'
    email_configs:
      - to: 'your-alert-email@gmail.com'  # Email nhận alert
```

**Convert password sang Base64:**

```powershell
# Replace 'your-app-password' với 16-ký tự từ Gmail
$password = 'abcd efgh ijkl mnop'
$base64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($password))
Write-Host "Base64: $base64"
```

### 5.3. Apply Alertmanager Config

```powershell
cd E:\AKS-DEMO\Infrastructure\observability\prometheus

# Apply secret và config
kubectl apply -f alertmanager-gmail-config.yaml

# Restart Alertmanager to load config
kubectl rollout restart statefulset -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager

# Check logs
kubectl logs -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0 -c alertmanager --tail=50
```

### 5.4. Apply Custom Alert Rules

```powershell
cd E:\AKS-DEMO\Infrastructure\observability\prometheus

kubectl apply -f alert-rules.yaml

# Verify
kubectl get prometheusrules -n monitoring ftm-alerts
```

**Alert rules bao gồm:**
- FTMBackendDown (critical)
- FTMBackendHighErrorRate (warning)
- FTMBackendHighMemory (warning)
- FTMFrontendDown (critical)
- NodeHighMemoryUsage (critical)
- PodCrashLooping (warning)

### 5.5. Test Alerts

```powershell
# Access Alertmanager UI
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093

# Truy cập: http://localhost:9093
# Check: Status → Receivers → "critical-alerts"

# Test bằng cách scale down backend
kubectl scale deployment ftm-backend -n ftm-dev --replicas=0
# Đợi 2 phút → Sẽ nhận email "FTMBackendDown"

# Scale back up
kubectl scale deployment ftm-backend -n ftm-dev --replicas=1
```

---

## 📦 BƯỚC 6: Cấu hình DNS

### 6.1. Get Ingress External IP

```powershell
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Output:
# NAME                       TYPE           EXTERNAL-IP      PORT(S)
# ingress-nginx-controller   LoadBalancer   4.144.199.99     80:31189/TCP,443:32400/TCP
```

### 6.2. Tạo DNS A Records

**Nếu dùng Azure DNS:**

```powershell
# Variables
$RESOURCE_GROUP = "rg-ftm-aks-dev"
$DNS_ZONE = "longops.io.vn"
$INGRESS_IP = "4.144.199.99"

# Create records
az network dns record-set a add-record `
  --resource-group $RESOURCE_GROUP `
  --zone-name $DNS_ZONE `
  --record-set-name grafana `
  --ipv4-address $INGRESS_IP

az network dns record-set a add-record `
  --resource-group $RESOURCE_GROUP `
  --zone-name $DNS_ZONE `
  --record-set-name loki `
  --ipv4-address $INGRESS_IP

az network dns record-set a add-record `
  --resource-group $RESOURCE_GROUP `
  --zone-name $DNS_ZONE `
  --record-set-name tempo `
  --ipv4-address $INGRESS_IP
```

**Nếu dùng DNS provider khác (Cloudflare, GoDaddy...):**

| Type | Name | Value | TTL |
|------|------|-------|-----|
| A | grafana | 4.144.199.99 | 300 |
| A | loki | 4.144.199.99 | 300 |
| A | tempo | 4.144.199.99 | 300 |

### 6.3. Verify DNS

```powershell
# Test DNS resolution
nslookup grafana.longops.io.vn 8.8.8.8
nslookup loki.longops.io.vn 8.8.8.8
nslookup tempo.longops.io.vn 8.8.8.8

# Test HTTP access
curl -I http://grafana.longops.io.vn
curl -I http://loki.longops.io.vn/ready
curl -I http://tempo.longops.io.vn/ready
```

---

## ✅ BƯỚC 7: Xác thực cài đặt

### 7.1. Check All Pods

```powershell
kubectl get pods -n monitoring

# All should be Running/Completed:
# prometheus-prometheus-prometheus-0                       3/3     Running
# prometheus-grafana-xxxxx-xxxxx                           3/3     Running
# prometheus-kube-state-metrics-xxxxx                      1/1     Running
# prometheus-prometheus-node-exporter-xxxxx                1/1     Running (per node)
# prometheus-prometheus-operator-xxxxx                     1/1     Running
# alertmanager-prometheus-kube-prometheus-alertmanager-0   2/2     Running
# loki-0                                                   1/1     Running
# loki-gateway-xxxxx-xxxxx                                 1/1     Running
# tempo-xxxxx-xxxxx                                        1/1     Running
# fluent-bit-xxxxx                                         1/1     Running (per node)
```

### 7.2. Check Resource Usage

```powershell
# Node resources
kubectl top node

# Pod resources
kubectl top pods -n monitoring --sort-by=memory
```

### 7.3. Check Storage

```powershell
kubectl get pvc -n monitoring

# Should see:
# prometheus-prometheus-prometheus-db-prometheus-prometheus-prometheus-0   10Gi
# loki-storage-loki-0                                                      10Gi
# tempo-storage-tempo-0                                                    10Gi
# grafana-storage                                                          5Gi
# alertmanager-storage-alertmanager-prometheus-...-0                       2Gi
```

### 7.4. Access Grafana

```powershell
# URL: https://grafana.longops.io.vn
# Username: admin
# Password: Admin@123456 (hoặc password bạn đã đổi)
```

**Verify trong Grafana:**

1. **Datasources:**
   - Configuration → Data Sources
   - Should see: Prometheus (default), Loki, Tempo

2. **Pre-installed Dashboards:**
   - Dashboards → Browse
   - Kubernetes / Compute Resources / Cluster
   - Kubernetes / Compute Resources / Namespace (Pods)
   - Node Exporter / Nodes

3. **Explore Metrics:**
   - Explore → Prometheus
   - Query: `up` (shows all scraped targets)

4. **Explore Logs:**
   - Explore → Loki
   - Query: `{namespace="ftm-dev"}`

5. **Alerts:**
   - Alerting → Alert Rules
   - Should see custom rules from `alert-rules.yaml`

---

## 🔧 Troubleshooting

### Issue 1: Pods Pending (Insufficient Resources)

**Symptoms:**
```
kubectl get pods -n monitoring
NAME                          READY   STATUS    RESTARTS   AGE
prometheus-prometheus-0       0/3     Pending   0          5m
```

**Diagnosis:**
```powershell
kubectl describe pod -n monitoring prometheus-prometheus-0

# Look for:
# Events:
#   Warning  FailedScheduling  ... Insufficient memory/cpu
```

**Solution:**
```powershell
# Check node resources
kubectl top node
kubectl describe node

# Option 1: Scale up node pool
az aks nodepool scale `
  --resource-group rg-ftm-aks-dev `
  --cluster-name aks-ftm-dev `
  --name pool2 `
  --node-count 2

# Option 2: Upgrade node VM size
# See: Infrastructure/observability/RESOURCE_REQUIREMENTS.md
```

### Issue 2: Prometheus PVC Stuck in Pending

**Symptoms:**
```
kubectl get pvc -n monitoring
NAME                                 STATUS    VOLUME   CAPACITY
prometheus-prometheus-db-...         Pending            
```

**Solution:**
```powershell
# Check StorageClass
kubectl get storageclass

# Should have 'default' or 'managed-premium'
# If not, create one:
kubectl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: default
provisioner: disk.csi.azure.com
parameters:
  storageaccounttype: Premium_LRS
  kind: Managed
EOF
```

### Issue 3: Grafana 502 Bad Gateway

**Symptoms:**
```
curl https://grafana.longops.io.vn
# 502 Bad Gateway
```

**Diagnosis:**
```powershell
# Check Grafana pod
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana
kubectl logs -n monitoring -l app.kubernetes.io/name=grafana

# Check Ingress
kubectl describe ingress -n monitoring prometheus-grafana
```

**Solution:**
```powershell
# Restart Grafana
kubectl rollout restart deployment -n monitoring prometheus-grafana

# Wait for ready
kubectl rollout status deployment -n monitoring prometheus-grafana
```

### Issue 4: Fluent Bit Not Sending Logs to Loki

**Symptoms:**
```
# No logs in Grafana Explore → Loki
```

**Diagnosis:**
```powershell
kubectl logs -n monitoring -l app.kubernetes.io/name=fluent-bit --tail=100

# Look for errors:
# [error] [output:loki:loki.0] HTTP status=400
```

**Solution:**
```powershell
# Check Loki service
kubectl get svc -n monitoring loki-gateway

# Should be: loki-gateway.monitoring.svc.cluster.local:80

# Restart Fluent Bit
kubectl rollout restart daemonset -n monitoring fluent-bit

# Test Loki manually
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://loki-gateway.monitoring.svc.cluster.local/ready
```

### Issue 5: Alertmanager Not Sending Emails

**Symptoms:**
- Alerts firing in Prometheus
- No emails received

**Diagnosis:**
```powershell
# Check Alertmanager logs
kubectl logs -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager-0 -c alertmanager

# Look for:
# level=error msg="Notify for alerts failed" err="...authentication failed..."
```

**Common issues:**
1. **Wrong Gmail app password** → Regenerate trong Google Account
2. **2FA not enabled** → Enable 2FA first
3. **Base64 encoding wrong** → Re-encode password:
   ```powershell
   $password = 'your-16-char-app-password'
   [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($password))
   ```
4. **Email blocked by Gmail** → Check Gmail security: https://myaccount.google.com/security

**Solution:**
```powershell
# Update secret với correct password
kubectl delete secret -n monitoring alertmanager-gmail-secret
kubectl create secret generic alertmanager-gmail-secret `
  --from-literal=smtp-password='your-correct-app-password' `
  -n monitoring

# Restart Alertmanager
kubectl rollout restart statefulset -n monitoring alertmanager-prometheus-kube-prometheus-alertmanager
```

### Issue 6: High Memory Usage / OOMKilled

**Symptoms:**
```
kubectl get pods -n monitoring
NAME                          READY   STATUS      RESTARTS
prometheus-prometheus-0       2/3     OOMKilled   3
```

**Solution:**
```powershell
# Reduce retention period
# Edit values.yaml:
prometheus:
  prometheusSpec:
    retention: 3d  # Giảm từ 7d → 3d

# Upgrade release
helm upgrade prometheus prometheus-community/kube-prometheus-stack `
  --namespace monitoring `
  --values prometheus/values.yaml `
  --reuse-values
```

---

## 📊 Resource Monitoring

### Check Overall Cluster Health

```powershell
# Node resources
kubectl top node

# Pod resources in monitoring namespace
kubectl top pods -n monitoring --sort-by=memory

# Persistent Volume usage
kubectl get pvc -n monitoring
kubectl exec -it -n monitoring prometheus-prometheus-prometheus-0 -c prometheus -- df -h /prometheus
```

### Expected Resource Usage (1 Node D2s_v3)

| Component | CPU | Memory | Comments |
|-----------|-----|--------|----------|
| Prometheus | 200-500m | 600-800Mi | Depends on scrape frequency |
| Grafana | 50-100m | 200-300Mi | Idle usage |
| Loki | 100-200m | 300-400Mi | Depends on log volume |
| Tempo | 50-100m | 200-300Mi | Low usage in dev |
| Fluent Bit | 50m | 64Mi | Per node |
| **TOTAL** | ~1-2 vCPU | ~3-4GB | Out of 7GB allocatable |

---

## 🎯 Next Steps

Sau khi cài đặt xong, tham khảo:

1. **[USAGE_GUIDE.md](./USAGE_GUIDE.md)** - Hướng dẫn sử dụng Grafana, tạo dashboards, query logs/metrics
2. **[README.md](./README.md)** - Tổng quan architecture và concepts
3. **[RESOURCE_REQUIREMENTS.md](./RESOURCE_REQUIREMENTS.md)** - Chi tiết về resources và scaling

---

## 📚 References

- **Prometheus Operator**: https://prometheus-operator.dev/
- **Grafana Loki**: https://grafana.com/docs/loki/latest/
- **Grafana Tempo**: https://grafana.com/docs/tempo/latest/
- **Fluent Bit**: https://docs.fluentbit.io/
- **Helm Charts**: 
  - kube-prometheus-stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
  - loki: https://github.com/grafana/loki/tree/main/production/helm/loki
  - tempo: https://github.com/grafana/helm-charts/tree/main/charts/tempo

---

**✅ Hoàn thành Installation Guide!**

Bạn đã có một observability stack đầy đủ trên AKS. Tiếp theo, học cách sử dụng trong **USAGE_GUIDE.md**.
