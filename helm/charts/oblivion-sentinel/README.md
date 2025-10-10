# ⚔️ Oblivion Sentinel

**Oblivion Sentinel** is a Kubernetes self-healing and cleanup controller packaged as a **Helm chart**.  
It continuously scans **Helm-managed pods** (and optionally non-Helm workloads) across selected namespaces and applies a **two-phase remediation** logic to automatically clean up long-unhealthy workloads and stuck Helm releases.

---

## 🧭 Features

- 🧩 Namespace include/exclude filters  
- ⚙️ Two-phase remediation system  
  - **Phase 1 (Soft):** Delete pods unhealthy for ≥ `POD_TTL_DAYS`  
  - **Phase 2 (Hard):** Uninstall Helm releases unhealthy beyond `HELM_TTL_DAYS`  
- 🧠 Sticky mode tracking using annotations (`oblivion/bad-since`, `oblivion/healthy-runs`)  
- ⏱️ Custom TTL per pod via annotation `oblivion/ttl-days`  
- 🔒 RBAC-ready with optional `clusterAdmin` mode  
- 📊 Optional Prometheus Pushgateway metrics integration  
- 🪶 Lightweight CronJob-based design — runs, remediates, exits cleanly  

---

## ⚙️ How It Works

| Phase | Goal | Action | Trigger |
|:------|:------|:---------|:---------|
| **Phase 1 – Soft remediation** | Remove transient pod failures | Delete unhealthy pods | `bad-since` ≥ `POD_TTL_DAYS` |
| **Phase 2 – Hard remediation** | Reset permanently broken releases | `helm uninstall` the release | `bad-since` ≥ `HELM_TTL_DAYS` and `error ratio` ≥ `ERROR_RATIO_THRESHOLD` |

**Sticky mode** ensures that actions only occur if a workload stays unhealthy continuously over time.

---

## 🚀 Quickstart

```bash
# 1️⃣ Install (defaults to DRY_RUN=true for safety)
helm install oblivion-sentinel ./oblivion-sentinel \
  -n ops-tools --create-namespace

# 2️⃣ Run once manually (instead of waiting for the CronJob)
kubectl -n ops-tools create job \
  --from=cronjob/oblivion-sentinel-oblivion-sentinel \
  oblivion-sentinel-once

# 3️⃣ Watch logs
kubectl -n ops-tools logs -f job/oblivion-sentinel-once

# 4️⃣ Disable dry-run once validated
helm upgrade oblivion-sentinel ./oblivion-sentinel \
  -n ops-tools --reuse-values --set config.DRY_RUN=false
```

---

## 🧰 Requirements

- Kubernetes 1.22+ (tested up to 1.30)  
- Helm 3.8+  
- Container image must have `kubectl` + `jq`  
  *(this chart installs `coreutils` automatically for GNU date parsing)*  
- Sufficient RBAC access (see below)

---

## 🔐 RBAC and Security

| Mode | Description | Risk |
|:--|:--|:--|
| `rbac.clusterAdmin: true` | Grants full cluster-admin (simple demo mode) | ⚠️ Full cluster rights |
| `rbac.clusterAdmin: false` | Uses scoped permissions (pods, jobs, secrets, etc.) | ✅ Recommended for production |

All CronJobs run as non-root with a `RuntimeDefault` seccomp profile.

---

## 🧾 Annotated Values

> Below is a fully commented configuration sample (matches your `values.yaml` exactly).

```yaml
# ===== Container image =====
image:
  repository: alpine/k8s            # Base image containing kubectl; helm+jq installed at runtime
  tag: "1.30.3"
  pullPolicy: IfNotPresent

# ===== Schedule (CronJobs) =====
reaper:
  schedule: "0 8,22 * * *"          # Run daily at 8:00 and 22:00 (cluster timezone)
  timeZone: null                     # Optional, e.g. "Asia/Ho_Chi_Minh"
  startingDeadlineSeconds: null      # Allow job start delay, e.g. 3600 for 1h grace window

metrics:
  enable: false                      # Enable separate metrics push CronJob
  schedule: "*/5 * * * *"            # Run every 5 minutes if enabled
  timeZone: null
  startingDeadlineSeconds: null

# ===== ServiceAccount =====
serviceAccount:
  create: true
  name: ""                           # Leave empty = chart fullname
  annotations: {}

# ===== RBAC =====
rbac:
  create: true
  clusterAdmin: false                # true = cluster-admin (demo), false = scoped RBAC (recommended)

# Scoped RBAC (used when clusterAdmin=false)
rbacResources:
  - apiGroups: [""]
    resources: ["pods","services","configmaps","secrets","serviceaccounts","persistentvolumeclaims"]
    verbs: ["*"]
  - apiGroups: ["apps"]
    resources: ["deployments","daemonsets","statefulsets","replicasets"]
    verbs: ["*"]
  - apiGroups: ["batch"]
    resources: ["jobs","cronjobs"]
    verbs: ["*"]
  - apiGroups: ["networking.k8s.io","extensions"]
    resources: ["ingresses","ingressclasses","networkpolicies"]
    verbs: ["*"]
  - apiGroups: ["policy"]
    resources: ["poddisruptionbudgets"]
    verbs: ["*"]
  - apiGroups: ["autoscaling"]
    resources: ["horizontalpodautoscalers"]
    verbs: ["*"]
  - apiGroups: ["rbac.authorization.k8s.io"]
    resources: ["roles","rolebindings"]
    verbs: ["*"]

# ===== Main configuration (exported to ConfigMap) =====
config:
  # --- Namespace filters ---
  INCLUDE_NS_LIST: "production,staging"                 # Only scan these namespaces
  INCLUDE_NS_REGEX: ""                                  # Optional regex filter, e.g. "^(production|staging)$"
  EXCLUDE_NS_REGEX: "^(kube-|devops-|calico-system$|tigera-operator$|ingress-nginx$|monitoring$|middleware$|default$)"
  EXCLUDE_NS_LIST: "devops-manager,kube-system,calico-system"
  EXCLUDE_RELEASE_REGEX: "^(core-|platform-).*$"        # Skip Helm releases matching regex

  # --- Opt-out and TTL enforcement ---
  OPT_OUT_KEY: "oblivion/ignore"                       # If any pod in group has this label/annotation=true → skip
  TTL_OVERRIDE_ANNOTATION_KEY: "oblivion/ttl-days"     # Custom per-pod TTL override annotation
  TTL_ENFORCE_MODE: "clear_zero"                       # ignore | clear_zero | clear_all | set
  TTL_ENFORCE_VALUE: ""                                # Used if mode=set, e.g. "3"
  APPLY_TO_PODS_TOO: "true"                            # Apply enforcement to pods
  RECONCILER_DRY_RUN: "false"                          # true = print, false = apply annotations

  # --- Phase 1 (soft remediation) ---
  POD_TTL_DAYS: "3"                                    # Days before deleting bad pods
  DELETE_PODS_ON_PHASE1: "true"
  DELETE_PODS_FORCE: "true"                            # Use --force --grace-period=0
  MAX_PODS_DELETE_PER_RUN: "500"

  # --- Phase 2 (hard remediation) ---
  HELM_TTL_DAYS: "6"                                   # Days before uninstalling Helm release
  ERROR_RATIO_THRESHOLD: "60"                          # % bad pods to trigger uninstall
  MAX_RELEASES_PER_RUN: "50"

  # --- Health classification ---
  MIN_RESTARTS: "3"                                    # Min restart count to mark as persistently bad
  ERROR_REASONS: "CrashLoopBackOff,ImagePullBackOff,ErrImagePull,CreateContainerConfigError,CreateContainerError,RunContainerError,ContainerCannotRun,InvalidImageName"

  # --- Execution behavior ---
  DRY_RUN: "true"                                      # Simulate actions (safe mode)
  HELM_TIMEOUT: "5m"                                   # Helm uninstall timeout
  HELM_WAIT: "true"
  HELM_DEBUG: "false"

  # --- Sticky mode tracking ---
  STICKY_MODE: "true"                                  # Enable sticky tracking
  BAD_SINCE_ANNOTATION_KEY: "oblivion/bad-since"       # Annotation for “first seen bad”
  BACKFILL_NOTREADY: "true"                            # Backfill from Pod Ready condition
  HEALTHY_CLEAR_AFTER_RUNS: "3"                        # Clear after 3 consecutive stable healthy runs
  HEALTHY_STABLE_MINUTES: "30"                         # Each stable run must last ≥ 30m
  HEALTHY_RUNS_ANNOTATION_KEY: "oblivion/healthy-runs" # Counter annotation
  RESET_BAD_SINCE_WHEN_HEALTHY: "false"                # Legacy immediate clear mode

  # --- Metrics (optional) ---
  METRICS_ENABLE: "false"
  PUSHGATEWAY_URL: "http://prometheus-pushgateway.monitoring.svc:9091"
  PUSHGATEWAY_JOB: "oblivion_sentinel"
  PUSHGATEWAY_INSTANCE: ""
  PUSHGATEWAY_CLUSTER: ""

# ===== Pod-level options =====
resources: {}
nodeSelector: {}
tolerations:
  - key: "kubernetes.azure.com/scalesetpriority"
    operator: "Equal"
    value: "spot"
    effect: "NoSchedule"

affinity: {}
podSecurityContext:
  runAsNonRoot: true
  seccompProfile:
    type: RuntimeDefault

securityContext:
  runAsNonRoot: false
  allowPrivilegeEscalation: false

extraEnv:
  - name: HELM_CACHE_HOME
    value: /tmp/helm/cache
  - name: HELM_CONFIG_HOME
    value: /tmp/helm/config
  - name: HELM_DATA_HOME
    value: /tmp/helm/data

extraVolumeMounts:
  - name: tmp
    mountPath: /tmp
extraVolumes:
  - name: tmp
    emptyDir: {}
```

---

## 🧪 Manual Run and Logs

Run an immediate job:

```bash
kubectl -n ops-tools create job \
  --from=cronjob/oblivion-sentinel-oblivion-sentinel \
  oblivion-sentinel-once
```

Then check results:

```bash
kubectl -n ops-tools logs -f job/oblivion-sentinel-once
```

Expected logs include:
```
[oblivion-sentinel] sticky check production/isu-care-api: total=1 errNow=1 ratioNow=100% stickyAge=0d (0h59m)
[oblivion-sentinel] phase1 pods_deleted=0 ; phase2 release_candidates=0 ; releases_uninstalled=0
```

---

## 🔧 Troubleshooting

| Symptom | Cause | Fix |
|:--|:--|:--|
| `yaml: invalid map key` | Helm template spacing | Use `{{ include "oblivion-sentinel.fullname" . }}` without spaces |
| Age always `0` | `date` not GNU or missing coreutils | Chart installs it automatically; confirm logs show `installing coreutils for GNU date...` |
| No pods processed | Namespace excluded or regex mismatch | Check `INCLUDE_NS_LIST` and `EXCLUDE_NS_REGEX` |
| `helm uninstall` fails | RBAC scope too narrow | Set `rbac.clusterAdmin=true` or extend `rbacResources` |
| Sticky never clears | Not stable long enough | Lower `HEALTHY_STABLE_MINUTES` or increase `HEALTHY_CLEAR_AFTER_RUNS` |

---

## 👤 Maintainer

**ThanhPhat IT**  
DevOps Engineer / Kubernetes Tools Author  
📧 thanhphat@itblognote.com
🌐 [https://www.itblognote.com](https://www.itblognote.com)

---

## 📜 License

MIT License © 2025 **ThanhPhat IT**