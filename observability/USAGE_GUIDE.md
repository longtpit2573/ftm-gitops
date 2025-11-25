# 📊 Hướng dẫn Sử dụng Observability Stack

> **Tài liệu:** Hướng dẫn chi tiết sử dụng Grafana, query metrics/logs/traces, tạo dashboards, và troubleshooting  
> **Môi trường:** Azure Kubernetes Service (AKS)  
> **Cập nhật:** November 2025

---

## 📋 Mục lục

1. [Truy cập Grafana](#-truy-cập-grafana)
2. [Sử dụng Metrics (Prometheus)](#-sử-dụng-metrics-prometheus)
3. [Sử dụng Logs (Loki)](#-sử-dụng-logs-loki)
4. [Sử dụng Traces (Tempo)](#-sử-dụng-traces-tempo)
5. [Tạo Custom Dashboards](#-tạo-custom-dashboards)
6. [Alert Management](#-alert-management)
7. [Troubleshooting với Observability](#-troubleshooting-với-observability)
8. [Best Practices](#-best-practices)

---

## 🌐 Truy cập Grafana

### URL và Credentials

```
URL: https://grafana.longops.io.vn
Username: admin
Password: Admin@123456
```

**⚠️ QUAN TRỌNG:** Đổi password ngay sau lần đăng nhập đầu tiên!

```
1. Login → Admin (góc phải) → Profile
2. Tab "Change Password"
3. Nhập password mới
4. Save
```

### Hoặc Port-Forward (Nếu chưa setup DNS)

```powershell
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Truy cập: http://localhost:3000
```

### Kiểm tra Datasources

```
1. Configuration (⚙️) → Data Sources
2. Verify 3 datasources:
   ✅ Prometheus (default) - http://prometheus-kube-prometheus-prometheus:9090
   ✅ Loki - http://loki-gateway:80
   ✅ Tempo - http://tempo:3100
```

**Test datasources:**
- Click vào từng datasource → "Save & Test"
- Phải thấy: ✅ "Data source is working"

---

## 📈 Sử dụng Metrics (Prometheus)

### 1. Explore Metrics

**Navigation:** Explore (🧭) → Chọn "Prometheus" ở dropdown

### 2. Basic Queries

#### 2.1. CPU Usage của tất cả pods

```promql
# CPU usage (cores)
sum(rate(container_cpu_usage_seconds_total{namespace="ftm-dev"}[5m])) by (pod)

# CPU usage (%)
sum(rate(container_cpu_usage_seconds_total{namespace="ftm-dev"}[5m])) by (pod) 
/ sum(container_spec_cpu_quota{namespace="ftm-dev"} / container_spec_cpu_period{namespace="ftm-dev"}) by (pod) 
* 100
```

**Giải thích:**
- `rate([5m])`: Tính average trong 5 phút
- `by (pod)`: Group theo pod name
- Click "Run Query" → Thấy graph

#### 2.2. Memory Usage

```promql
# Memory working set (đang dùng thực tế)
sum(container_memory_working_set_bytes{namespace="ftm-dev"}) by (pod)

# Memory limit
sum(container_spec_memory_limit_bytes{namespace="ftm-dev"}) by (pod)

# Memory usage (%)
sum(container_memory_working_set_bytes{namespace="ftm-dev"}) by (pod)
/ sum(container_spec_memory_limit_bytes{namespace="ftm-dev"}) by (pod)
* 100
```

#### 2.3. Pod Restart Count

```promql
# Total restarts
sum(kube_pod_container_status_restarts_total{namespace="ftm-dev"}) by (pod)

# Restart rate (restarts per minute)
rate(kube_pod_container_status_restarts_total{namespace="ftm-dev"}[5m]) * 60
```

#### 2.4. HTTP Request Rate (Backend)

```promql
# Total requests per second
sum(rate(http_requests_total{namespace="ftm-dev"}[5m])) by (endpoint)

# 5xx error rate
sum(rate(http_requests_total{namespace="ftm-dev",status=~"5.."}[5m])) by (endpoint)
```

**⚠️ Note:** Backend phải export metrics này. Xem phần "Instrumentation" bên dưới.

#### 2.5. Node Resources

```promql
# Node CPU usage (%)
100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Node Memory usage (%)
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Node Disk usage (%)
100 - ((node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"}) * 100)
```

### 3. Query Builder vs Code Mode

**Query Builder (Recommended cho beginners):**
- Click "Metrics browser" → Browse available metrics
- Select labels → Auto-generate query

**Code Mode (Advanced):**
- Type PromQL directly
- Use autocomplete (Ctrl+Space)
- See [PromQL Cheat Sheet](https://promlabs.com/promql-cheat-sheet/)

### 4. Time Range và Refresh

```
Góc phải trên:
- Time range: Last 1 hour / 6 hours / 24 hours / 7 days
- Refresh: Auto-refresh every 5s / 10s / 30s / 1m
```

### 5. Visualizations

Sau khi query, switch visualization:
- **Graph**: Time series line chart
- **Table**: Tabular data
- **Stat**: Single number
- **Gauge**: Progress bar

---

## 📝 Sử dụng Logs (Loki)

### 1. Explore Logs

**Navigation:** Explore (🧭) → Chọn "Loki" ở dropdown

### 2. Basic Log Queries (LogQL)

#### 2.1. All logs from namespace

```logql
{namespace="ftm-dev"}
```

#### 2.2. Logs from specific pod

```logql
{namespace="ftm-dev", pod="ftm-backend-7897b5c994-xxxxx"}
```

**Tip:** Dùng autocomplete - gõ `{` và nhấn Ctrl+Space

#### 2.3. Logs from container

```logql
{namespace="ftm-dev", container="backend"}
```

#### 2.4. Filter logs by content

```logql
# Contains "error" (case-insensitive)
{namespace="ftm-dev"} |~ "(?i)error"

# Contains "exception" or "error"
{namespace="ftm-dev"} |~ "exception|error"

# Does NOT contain "health"
{namespace="ftm-dev"} != "health"

# Starts with "[Error]"
{namespace="ftm-dev"} |~ "^\\[Error\\]"
```

**LogQL Operators:**
- `|=`: Contains (exact)
- `!=`: Does not contain
- `|~`: Regex match
- `!~`: Regex does not match

#### 2.5. Parse JSON logs

```logql
# If backend logs JSON: {"level":"error", "message":"DB connection failed"}
{namespace="ftm-dev", container="backend"} 
| json 
| level="error"

# Count errors per minute
count_over_time({namespace="ftm-dev"} | json | level="error" [1m])
```

#### 2.6. Rate queries

```logql
# Log lines per second
rate({namespace="ftm-dev"}[5m])

# Error logs per second
rate({namespace="ftm-dev"} |~ "error" [5m])

# Top 5 pods by log volume
topk(5, sum by (pod) (rate({namespace="ftm-dev"}[5m])))
```

### 3. Live Tailing

```
1. Enter query: {namespace="ftm-dev"}
2. Click "Live" button (góc phải)
3. Logs sẽ stream real-time
4. Click "Stop" để dừng
```

### 4. Context - Xem logs xung quanh

```
1. Click vào 1 log line
2. Click "Show context"
3. Thấy 10 dòng trước + sau log đó
```

### 5. Log Formatting

**Switch view:**
- **Table**: Structured columns (time, labels, log)
- **Logs**: Raw log lines
- **JSON**: Pretty-printed JSON

**Tip:** Click vào log line → Labels → Click label value để filter nhanh

---

## 🔍 Sử dụng Traces (Tempo)

### 1. Prerequisites

**Backend phải instrument với OpenTelemetry:**

```csharp
// Program.cs - .NET Backend
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProvider =>
    {
        tracerProvider
            .AddAspNetCoreInstrumentation()
            .AddHttpClientInstrumentation()
            .AddSqlClientInstrumentation()
            .AddOtlpExporter(options =>
            {
                options.Endpoint = new Uri("http://tempo.monitoring.svc.cluster.local:4317");
            });
    });
```

### 2. Explore Traces

**Navigation:** Explore (🧭) → Chọn "Tempo" ở dropdown

### 3. Search Traces

#### 3.1. Search by Service Name

```
Service Name: ftm-backend
Operation: /api/users/login
```

#### 3.2. Search by Tags

```
Tags:
  http.method = POST
  http.status_code = 500
  http.url = /api/order/create
```

#### 3.3. Search by Duration

```
Duration: > 1000ms  (tìm requests chậm hơn 1 giây)
```

### 4. Analyze Trace

**Khi click vào 1 trace:**

```
├── HTTP POST /api/order/create [2.3s total]
    ├── Database Query: SELECT * FROM Orders [800ms]
    ├── HTTP Call: Payment Gateway [1.2s]  ← SLOW!
    ├── Database Insert: INSERT INTO Orders [100ms]
    └── Cache Set: Redis [50ms]
```

**Insights:**
- **Flamegraph**: Visual timeline
- **Spans**: Individual operations
- **Duration**: Each span time
- **Tags**: Metadata (SQL query, HTTP status, etc.)

### 5. Correlate Logs with Traces

**Nếu backend log trace_id:**

```json
{"level":"error", "message":"Payment failed", "trace_id":"abc123xyz"}
```

**Trong Loki → Click trace_id → Jump to Tempo trace**

---

## 📊 Tạo Custom Dashboards

### 1. Create New Dashboard

```
1. Dashboards (☰) → New Dashboard
2. Add Panel → Add Visualization
3. Select Datasource: Prometheus
4. Enter Query
5. Customize Panel
6. Save Dashboard
```

### 2. Example: FTM Backend Dashboard

#### Panel 1: Request Rate

```
Title: HTTP Request Rate
Query: sum(rate(http_requests_total{namespace="ftm-dev", service="ftm-backend"}[5m]))
Visualization: Graph (Time series)
Unit: requests/sec
```

#### Panel 2: Error Rate

```
Title: 5xx Error Rate
Query: sum(rate(http_requests_total{namespace="ftm-dev", status=~"5.."}[5m])) / sum(rate(http_requests_total{namespace="ftm-dev"}[5m])) * 100
Visualization: Stat
Unit: percent (0-100)
Thresholds: 
  Green: 0-1%
  Yellow: 1-5%
  Red: >5%
```

#### Panel 3: Response Time

```
Title: P95 Response Time
Query: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket{namespace="ftm-dev"}[5m])) by (le))
Visualization: Graph
Unit: seconds
```

#### Panel 4: CPU Usage

```
Title: Backend CPU Usage
Query: sum(rate(container_cpu_usage_seconds_total{namespace="ftm-dev", pod=~"ftm-backend.*"}[5m])) by (pod)
Visualization: Graph (Stacked area)
Unit: cores
```

#### Panel 5: Memory Usage

```
Title: Backend Memory Usage
Query: sum(container_memory_working_set_bytes{namespace="ftm-dev", pod=~"ftm-backend.*"}) by (pod)
Visualization: Graph (Lines)
Unit: bytes
```

#### Panel 6: Pod Status

```
Title: Running Pods
Query: sum(kube_pod_status_phase{namespace="ftm-dev", pod=~"ftm-backend.*", phase="Running"})
Visualization: Stat (Big number)
```

#### Panel 7: Recent Logs (Loki)

```
Datasource: Loki
Query: {namespace="ftm-dev", container="backend"} |~ "error|exception"
Visualization: Logs
Show: Last 50 lines
```

### 3. Dashboard Variables

**Tạo dropdown để chọn namespace:**

```
1. Dashboard Settings (⚙️) → Variables → Add Variable
2. Name: namespace
3. Type: Query
4. Datasource: Prometheus
5. Query: label_values(kube_pod_info, namespace)
6. Save
```

**Dùng trong queries:**

```promql
sum(rate(container_cpu_usage_seconds_total{namespace="$namespace"}[5m]))
```

### 4. Dashboard Links

**Link giữa các dashboards:**

```
1. Dashboard Settings → Links → Add Link
2. Type: Dashboard
3. Target: FTM Backend Dashboard
4. Icon: external link
```

### 5. Time Variables

```promql
# Automatic time range in query
rate(http_requests_total[5m])

# Use dashboard time range
rate(http_requests_total[$__range])
```

### 6. Annotations (Mark events)

```
1. Dashboard → Settings → Annotations → Add Annotation
2. Name: Deployments
3. Datasource: Prometheus
4. Query: changes(kube_deployment_status_observed_generation{namespace="ftm-dev"}[5m]) > 0
```

Sẽ show vertical line khi có deployment mới.

### 7. Export & Import Dashboard

**Export:**
```
Dashboard Settings → JSON Model → Copy to Clipboard
Save to file: ftm-backend-dashboard.json
```

**Import:**
```
Dashboards → Import → Upload JSON file
```

---

## 🚨 Alert Management

### 1. View Active Alerts

```
Alerting (🔔) → Alert Rules
```

### 2. Custom Alert Rules (via Prometheus)

**File:** `Infrastructure/observability/prometheus/alert-rules.yaml`

**Example: High Memory Alert**

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: ftm-custom-alerts
  namespace: monitoring
spec:
  groups:
  - name: ftm-backend
    interval: 30s
    rules:
    - alert: BackendHighMemory
      expr: |
        sum(container_memory_working_set_bytes{namespace="ftm-dev", pod=~"ftm-backend.*"})
        / sum(container_spec_memory_limit_bytes{namespace="ftm-dev", pod=~"ftm-backend.*"})
        > 0.9
      for: 5m
      labels:
        severity: warning
        service: ftm-backend
      annotations:
        summary: "Backend memory usage > 90%"
        description: "Backend pod {{ $labels.pod }} is using {{ $value | humanizePercentage }} of memory limit"
```

**Apply:**
```powershell
kubectl apply -f alert-rules.yaml
```

### 3. Silence Alerts

```
1. Alerting → Silences → New Silence
2. Matcher: alertname = BackendHighMemory
3. Duration: 2 hours
4. Comment: "Maintenance window"
5. Create
```

### 4. Alert Notification Channels

**Configured:** Gmail (via Alertmanager)

**Add Slack (Example):**

```yaml
# alertmanager-config.yaml
receivers:
  - name: 'slack-alerts'
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/WEBHOOK/URL'
        channel: '#alerts'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

route:
  routes:
    - match:
        severity: critical
      receiver: slack-alerts
      continue: true
```

---

## 🔧 Troubleshooting với Observability

### Scenario 1: Backend trả về 500 error

**Step 1: Check metrics - Có spike errors không?**

```promql
# Grafana → Explore → Prometheus
rate(http_requests_total{namespace="ftm-dev", status="500"}[5m])
```

**Step 2: Check logs - Lỗi gì?**

```logql
# Grafana → Explore → Loki
{namespace="ftm-dev", container="backend"} |~ "(?i)error|exception"
```

**Step 3: Check traces - Request nào chậm?**

```
Grafana → Explore → Tempo
Search: http.status_code = 500
```

**Step 4: Correlate - Tìm trace_id trong logs**

```logql
{namespace="ftm-dev"} | json | trace_id="abc123xyz"
```

### Scenario 2: Pod restart liên tục

**Step 1: Check restart count**

```promql
kube_pod_container_status_restarts_total{namespace="ftm-dev"}
```

**Step 2: Check resource limits**

```promql
# Memory usage vs limit
container_memory_working_set_bytes{namespace="ftm-dev", pod="ftm-backend-xxx"}
/ container_spec_memory_limit_bytes{namespace="ftm-dev", pod="ftm-backend-xxx"}
```

**Step 3: Check logs before crash**

```powershell
# Kubectl - logs from previous crashed container
kubectl logs -n ftm-dev ftm-backend-xxx --previous
```

**Step 4: Check OOMKill events**

```logql
{namespace="ftm-dev"} |~ "OOMKilled|Out of memory"
```

### Scenario 3: Slow API response

**Step 1: Check P95 latency**

```promql
histogram_quantile(0.95, 
  sum(rate(http_request_duration_seconds_bucket{namespace="ftm-dev"}[5m])) by (le, endpoint)
)
```

**Step 2: Find slow traces**

```
Tempo → Search
Duration: > 2000ms
Service: ftm-backend
```

**Step 3: Analyze spans trong trace**

```
Click trace → Flamegraph
Identify slowest span (e.g., Database query 1.8s)
```

**Step 4: Optimize code/query**

### Scenario 4: High CPU usage

**Step 1: Which pod?**

```promql
topk(5, 
  sum(rate(container_cpu_usage_seconds_total{namespace="ftm-dev"}[5m])) by (pod)
)
```

**Step 2: When did it start?**

```
Grafana → Thay đổi time range → Last 24 hours
Identify spike time
```

**Step 3: Correlate với deployment**

```
Dashboard → Annotations (deployment events)
Check nếu spike trùng với deployment mới
```

**Step 4: Profile application**

```csharp
// Enable diagnostic profiling endpoint
app.MapGet("/debug/pprof", async context => {
    // CPU profile, memory dump, etc.
});
```

---

## 💡 Best Practices

### 1. Metrics Naming

**Follow Prometheus conventions:**

```
# GOOD
http_requests_total{method="GET", status="200"}
http_request_duration_seconds{endpoint="/api/users"}

# BAD
HTTPRequests
RequestDuration_ms
```

### 2. Label Cardinality

**❌ Avoid high-cardinality labels:**

```promql
# BAD - user_id has millions of values
http_requests_total{user_id="12345"}

# GOOD - Use predefined categories
http_requests_total{user_tier="premium"}
```

### 3. Query Performance

**Use recording rules cho expensive queries:**

```yaml
# prometheus-rules.yaml
groups:
  - name: recorded
    interval: 30s
    rules:
      - record: job:http_requests:rate5m
        expr: sum(rate(http_requests_total[5m])) by (job)
```

**Dùng trong dashboard:**
```promql
job:http_requests:rate5m{job="ftm-backend"}
```

### 4. Log Levels

**Structure logs properly:**

```csharp
// Backend logging
_logger.LogInformation("User {UserId} logged in", userId);
_logger.LogWarning("Payment retry attempt {Attempt}", attempt);
_logger.LogError(exception, "Database connection failed for {Operation}", operation);
```

**Benefits:**
- Structured logs → Easy to parse in Loki
- Proper levels → Easy to filter
- Context variables → Better debugging

### 5. Trace Sampling

**Don't trace everything - Sample strategically:**

```csharp
builder.Services.AddOpenTelemetry()
    .WithTracing(tracerProvider =>
    {
        tracerProvider.SetSampler(new TraceIdRatioBasedSampler(0.1)); // 10% sampling
    });
```

### 6. Dashboard Organization

```
Create folder structure:
├── FTM Application
│   ├── Backend Overview
│   ├── Frontend Overview
│   ├── Database
│   └── External APIs
├── Infrastructure
│   ├── Kubernetes Cluster
│   ├── Nodes
│   └── Storage
└── Business Metrics
    ├── Orders
    ├── Users
    └── Revenue
```

### 7. Alert Fatigue Prevention

**Rules for good alerts:**
1. **Actionable**: Alert chỉ khi cần human intervention
2. **Meaningful**: Include context trong description
3. **Grouped**: Group related alerts để tránh spam
4. **Tuned**: Adjust thresholds để giảm false positives

**Example:**

```yaml
# ❌ BAD - Alert on every error
- alert: AnyError
  expr: rate(http_requests_total{status="500"}[1m]) > 0

# ✅ GOOD - Alert on sustained high error rate
- alert: HighErrorRate
  expr: |
    sum(rate(http_requests_total{status=~"5.."}[5m])) 
    / sum(rate(http_requests_total[5m])) 
    > 0.05
  for: 10m  # Must persist 10 minutes
```

### 8. Retention Policies

**Balance between cost and usefulness:**

```yaml
# Prometheus - Short-term, high-resolution
retention: 7d

# Loki - Medium-term logs
retention_period: 168h  # 7 days

# Tempo - Short-term traces (expensive)
retention: 72h  # 3 days

# Long-term: Use Thanos/Cortex for Prometheus
# Export to Azure Blob Storage for Loki
```

### 9. Security

**Protect Grafana:**

```yaml
# grafana.ini
[auth.anonymous]
enabled = false  # Disable anonymous access

[auth.basic]
enabled = true

[security]
admin_password = <strong-password>
secret_key = <random-secret-key>
```

**Use RBAC:**
```
1. Configuration → Users → Add User
2. Role: Viewer (chỉ xem dashboards)
3. Or: Editor (create dashboards)
```

### 10. Documentation

**Document dashboards:**

```
1. Dashboard Settings → Description
2. Add Markdown text panel với:
   - Purpose của dashboard
   - Các metrics quan trọng
   - Links tới runbooks
   - Contact team
```

---

## 📚 Advanced Topics

### 1. Custom Metrics từ Application

**.NET Backend Example:**

```csharp
// Startup.cs
services.AddSingleton<IMetrics>(_ => 
{
    var metrics = new MetricServer(port: 9090);
    metrics.Start();
    return Metrics.DefaultRegistry;
});

// OrderController.cs
private readonly Counter _orderCounter = Metrics.CreateCounter(
    "ftm_orders_total", 
    "Total orders created",
    new CounterConfiguration { LabelNames = new[] { "status" } }
);

[HttpPost]
public async Task<IActionResult> CreateOrder(Order order)
{
    // ... business logic ...
    _orderCounter.WithLabels(order.Status).Inc();
    return Ok();
}
```

**Query trong Grafana:**

```promql
rate(ftm_orders_total[5m])
sum(ftm_orders_total) by (status)
```

### 2. LogQL Advanced Queries

**Extract và aggregate values từ logs:**

```logql
# Count errors by endpoint
sum by (endpoint) (
  count_over_time(
    {namespace="ftm-dev"} 
    | json 
    | level="error" 
    [5m]
  )
)

# Average response time từ logs
avg_over_time(
  {namespace="ftm-dev"} 
  | json 
  | unwrap duration 
  [5m]
)
```

### 3. Tempo Service Graph

**Enable trong Grafana:**

```
1. Explore → Tempo
2. Tab "Service Graph"
3. See visual map of service dependencies
```

**Shows:**
- Request flow: Frontend → Backend → Database
- Error rates per connection
- Latency per hop

### 4. Distributed Tracing Context Propagation

**Frontend → Backend trace propagation:**

```typescript
// Frontend (React)
const response = await fetch('/api/order', {
  headers: {
    'traceparent': generateTraceParent(), // W3C Trace Context
  }
});
```

```csharp
// Backend (.NET)
app.Use(async (context, next) =>
{
    // Extract traceparent header
    var traceparent = context.Request.Headers["traceparent"];
    // Propagate to downstream calls...
    await next();
});
```

---

## 🎓 Learning Resources

### PromQL
- **Official Docs**: https://prometheus.io/docs/prometheus/latest/querying/basics/
- **PromQL Cheat Sheet**: https://promlabs.com/promql-cheat-sheet/
- **Query Examples**: https://prometheus.io/docs/prometheus/latest/querying/examples/

### LogQL
- **Official Docs**: https://grafana.com/docs/loki/latest/logql/
- **Log Queries**: https://grafana.com/docs/loki/latest/logql/log_queries/
- **Metric Queries**: https://grafana.com/docs/loki/latest/logql/metric_queries/

### Grafana
- **Fundamentals**: https://grafana.com/tutorials/grafana-fundamentals/
- **Dashboard Best Practices**: https://grafana.com/docs/grafana/latest/best-practices/best-practices-for-creating-dashboards/

### OpenTelemetry
- **.NET Instrumentation**: https://opentelemetry.io/docs/instrumentation/net/
- **Automatic Instrumentation**: https://github.com/open-telemetry/opentelemetry-dotnet-instrumentation

---

## 📞 Support

**Issues với Observability Stack:**
- GitHub Issues: https://github.com/yourorg/Infrastructure/issues
- Team Contact: devops@yourcompany.com
- Documentation: `Infrastructure/observability/README.md`

**Monitoring Health:**
```powershell
# Check all monitoring pods
kubectl get pods -n monitoring

# Grafana status
kubectl get ingress -n monitoring prometheus-grafana
```

---

**✅ Hoàn thành Usage Guide!**

Bây giờ bạn đã biết cách sử dụng full observability stack. Happy monitoring! 📊🔍📈
