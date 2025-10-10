#!/usr/bin/env bash
set -euo pipefail

# =============================
# Oblivion Sentinel - Check Tool
# =============================
# This single file contains:
#  - The checker script
#  - Built-in usage examples (print or run)
#
# What this script does:
# 1) Show sticky annotations for a Helm release: "oblivion/bad-since" and
#    "oblivion/healthy-runs", and compute stickyAge in hours/days.
# 2) Optionally show the same for a non-Helm controller (e.g., deployment/my-raw-yaml-app),
#    reading annotations directly from the controller.
# 3) Optionally check RBAC for the Job's ServiceAccount (can-i get/list/patch/update secrets).
# 4) Optionally read DRY_RUN from a configmap (the one your Job uses via envFrom).
# 5) Watch mode: print ages repeatedly so you can see stickyAge increase over time.
#
# IMPORTANT:
# - If your reaper script SHORT-CIRCUITS annotate when DRY_RUN=true, "bad-since" won't be written,
#   so stickyAge will stay "N/A". If you want DRY_RUN to only disable delete/uninstall while still
#   recording state, allow annotate to run regardless of DRY_RUN.
#
# Requirements: kubectl, jq
#
# ---------------------------
# DEMO defaults (used by --demo)
# ---------------------------
DEMO_REL="${DEMO_REL:-ibn-care-api}"             # change to an existing Helm release
DEMO_NS="${DEMO_NS:-production}"                 # namespace of that release
DEMO_NONHELM="${DEMO_NONHELM:-}"                 # e.g., "deployment/my-raw-yaml-app" or leave empty
DEMO_MGMT_NS="${DEMO_MGMT_NS:-devops-manager}"   # namespace where the SA lives
DEMO_SA="${DEMO_SA:-oblivion-sentinel}"          # ServiceAccount name used by the CronJob
DEMO_CFG_CM="${DEMO_CFG_CM:-oblivion-sentinel-config}"  # configmap that may contain DRY_RUN
DEMO_CFG_CM_NS="${DEMO_CFG_CM_NS:-devops-manager}"      # its namespace

# ---------------------------
# Defaults and flags
# ---------------------------
REL=""                 # Helm release name
NS=""                  # Namespace of the Helm release
NONHELM=""            # Optional non-Helm controller: e.g., deployment/my-raw-yaml-app
MGMT_NS=""            # Namespace where the ServiceAccount lives (for RBAC tests)
SA_NAME=""            # ServiceAccount name used by the CronJob/Job

WATCH_MODE=0
INTERVAL=300          # Seconds between samples in watch mode (default 5 minutes)
COUNT=12              # Samples in watch mode (default 12 times)

BAD_SINCE_KEY="oblivion/bad-since"
HEALTHY_RUNS_KEY="oblivion/healthy-runs"

CFG_CM=""             # Optional: configmap name that contains DRY_RUN
CFG_CM_NS=""          # Namespace of that configmap

PRINT_EXAMPLES=0
RUN_DEMO=0

usage() {
  cat <<'EOF'
Usage:
  sentinel-check.sh --rel REL --ns NS [options]

Required:
  --rel REL                Helm release name
  --ns NS                  Namespace of the Helm release

Optional:
  --nonhelm KIND/NAME      Non-Helm controller to read annotations from (e.g. deployment/my-raw-yaml-app)
  --mgmt-ns NAMESPACE      Namespace where the Job's ServiceAccount lives (for RBAC checks)
  --sa SERVICEACCOUNT      ServiceAccount name used by the Job (for RBAC checks)
  --cfg-cm NAME            ConfigMap name to read DRY_RUN from (optional)
  --cfg-cm-ns NAMESPACE    Namespace of that ConfigMap (optional)

Watch mode:
  --watch                  Enable watch mode (print repeatedly)
  --interval SECONDS       Interval between samples (default: 300)
  --count N                Number of samples (default: 12)

Advanced:
  --bad-key KEY            Annotation key for "bad since" (default: oblivion/bad-since)
  --healthy-key KEY        Annotation key for "healthy runs" (default: oblivion/healthy-runs)

Examples:
  sentinel-check.sh --rel ibn-care-api --ns production
  sentinel-check.sh --rel ibn-care-api --ns production --nonhelm deployment/my-raw-yaml-app
  sentinel-check.sh --rel ibn-care-api --ns production --mgmt-ns devops-manager --sa oblivion-sentinel
  sentinel-check.sh --rel ibn-care-api --ns production --watch --interval 600 --count 6

Helpers:
  --examples               Print complete example commands
  --demo                   Run demo using DEMO_* variables at the top of this file

Notes:
- stickyAge increases only if "bad-since" was set once and not overwritten on each run.
- If DRY_RUN=true AND your script skips annotate calls, "bad-since" stays empty => stickyAge=N/A.
EOF
}

print_examples() {
  cat <<'EXAMPLES'
# =======================
# Complete example calls:
# =======================

# 1) One-shot Helm check
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production

# 2) One-shot Helm + Non-Helm (controller annotations)
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production \
  --nonhelm deployment/my-raw-yaml-app

# 3) Add RBAC check for the Job's ServiceAccount (lives in devops-manager ns)
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production \
  --mgmt-ns devops-manager \
  --sa oblivion-sentinel

# 4) Read DRY_RUN from configmap the Job uses (if any)
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production \
  --cfg-cm oblivion-sentinel-config \
  --cfg-cm-ns devops-manager

# 5) Watch mode (every 10 minutes, 6 samples ~ 1 hour)
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production \
  --watch --interval 600 --count 6

# 6) Combine multiple options
./sentinel-check.sh \
  --rel ibn-care-api \
  --ns production \
  --nonhelm deployment/my-raw-yaml-app \
  --mgmt-ns devops-manager \
  --sa oblivion-sentinel \
  --cfg-cm oblivion-sentinel-config \
  --cfg-cm-ns devops-manager \
  --watch --interval 600 --count 6
EXAMPLES
}

# -------- Parse args --------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --rel) REL="$2"; shift 2;;
    --ns) NS="$2"; shift 2;;
    --nonhelm) NONHELM="$2"; shift 2;;
    --mgmt-ns) MGMT_NS="$2"; shift 2;;
    --sa) SA_NAME="$2"; shift 2;;
    --cfg-cm) CFG_CM="$2"; shift 2;;
    --cfg-cm-ns) CFG_CM_NS="$2"; shift 2;;
    --watch) WATCH_MODE=1; shift 1;;
    --interval) INTERVAL="$2"; shift 2;;
    --count) COUNT="$2"; shift 2;;
    --bad-key) BAD_SINCE_KEY="$2"; shift 2;;
    --healthy-key) HEALTHY_RUNS_KEY="$2"; shift 2;;
    --examples) PRINT_EXAMPLES=1; shift 1;;
    --demo) RUN_DEMO=1; shift 1;;
    -h|--help) usage; exit 0;;
    *) echo "Unknown arg: $1"; usage; exit 1;;
  esac
done

# ---- Requirements ----
command -v kubectl >/dev/null || { echo "kubectl not found"; exit 1; }
command -v jq >/dev/null || { echo "jq not found"; exit 1; }

# ---- Helpers ----
get_latest_helm_secret_name() {
  # prints latest Helm release Secret name (or empty)
  kubectl -n "$NS" get secret -l "owner=helm,name=${REL}" \
    --sort-by=.metadata.creationTimestamp -o name 2>/dev/null \
    | tail -n1 | cut -d/ -f2 || true
}

print_header() {
  echo "==> $*"
}

show_helm_annotations() {
  local sec="$1"
  print_header "Show sticky annotations (Helm)"
  kubectl -n "$NS" get secret "$sec" -o json \
  | jq -r --arg k "$BAD_SINCE_KEY" --arg hk "$HEALTHY_RUNS_KEY" '
      {
        secret: .metadata.name,
        bad_since: (.metadata.annotations[$k] // ""),
        healthy_runs: (.metadata.annotations[$hk] // "")
      }'
}

show_helm_age_one_line() {
  # One line summary with ages (hours/days)
  local sec="$1"
  kubectl -n "$NS" get secret "$sec" -o json \
  | jq -r --arg k "$BAD_SINCE_KEY" --arg hk "$HEALTHY_RUNS_KEY" '
      . as $s
      | ($s.metadata.annotations[$k] // "") as $iso
      | ($s.metadata.annotations[$hk] // "") as $hr
      | ($iso | fromdateiso8601? // 0) as $ts
      | "HELM  [" + $s.metadata.name + "] bad_since="
        + (if $iso=="" then "N/A" else $iso end)
        + " | age_h=" + (if $ts==0 then "N/A" else (((now - $ts)/3600)|floor|tostring) end)
        + " | age_d=" + (if $ts==0 then "N/A" else (((now - $ts)/86400)|floor|tostring) end)
        + " | healthy_runs=" + (if $hr=="" then "N/A" else $hr end)
    '
}

list_all_helm_secrets() {
  print_header "List all Helm Secrets (to see if revision rotates)"
  kubectl -n "$NS" get secret -l "owner=helm,name=${REL}" -o json \
  | jq -r '.items[] | [.metadata.name, .metadata.creationTimestamp] | @tsv' \
  | sort
}

show_nonhelm_annotations() {
  local kind="${NONHELM%%/*}"
  local name="${NONHELM#*/}"
  print_header "Show sticky annotations (non-Helm: ${kind}/${name})"
  kubectl -n "$NS" get "$kind" "$name" -o json \
  | jq -r --arg k "$BAD_SINCE_KEY" --arg hk "$HEALTHY_RUNS_KEY" '
      {
        resource: (.kind + "/" + .metadata.name),
        bad_since: (.metadata.annotations[$k] // ""),
        healthy_runs: (.metadata.annotations[$hk] // "")
      }'
}

show_nonhelm_age_one_line() {
  local kind="${NONHELM%%/*}"
  local name="${NONHELM#*/}"
  kubectl -n "$NS" get "$kind" "$name" -o json \
  | jq -r --arg k "$BAD_SINCE_KEY" --arg hk "$HEALTHY_RUNS_KEY" '
      . as $r
      | ($r.metadata.annotations[$k] // "") as $iso
      | ($r.metadata.annotations[$hk] // "") as $hr
      | ($iso | fromdateiso8601? // 0) as $ts
      | "NONHL [" + $r.kind + "/" + $r.metadata.name + "] bad_since="
        + (if $iso=="" then "N/A" else $iso end)
        + " | age_h=" + (if $ts==0 then "N/A" else (((now - $ts)/3600)|floor|tostring) end)
        + " | age_d=" + (if $ts==0 then "N/A" else (((now - $ts)/86400)|floor|tostring) end)
        + " | healthy_runs=" + (if $hr=="" then "N/A" else $hr end)
    '
}

rbac_check() {
  if [[ -z "${MGMT_NS}" || -z "${SA_NAME}" ]]; then
    return 0
  fi
  print_header "RBAC check for the Job ServiceAccount (impersonate)"
  local subj="system:serviceaccount:${MGMT_NS}:${SA_NAME}"
  for verb in get list patch update; do
    printf "%-28s %s\n" "can-i $verb secrets:" "$(kubectl auth can-i "$verb" secrets --as="$subj" -n "$NS")"
  done
  if [[ -n "$CFG_CM_NS" ]]; then
    for verb in get list patch update; do
      printf "%-28s %s\n" "cm $verb in $CFG_CM_NS:" "$(kubectl auth can-i "$verb" configmaps --as="$subj" -n "$CFG_CM_NS")"
    done
  fi
}

show_dry_run_from_cm() {
  if [[ -z "$CFG_CM" || -z "$CFG_CM_NS" ]]; then
    return 0
  fi
  print_header "Read DRY_RUN from ConfigMap ${CFG_CM} in ${CFG_CM_NS}"
  local val
  val="$(kubectl -n "$CFG_CM_NS" get configmap "$CFG_CM" -o jsonpath='{.data.DRY_RUN}' 2>/dev/null || true)"
  if [[ -z "${val:-}" ]]; then
    echo "DRY_RUN: <not found>"
  else
    echo "DRY_RUN: ${val}"
  fi
}

# -------- Main (once) --------
run_once() {
  print_header "Find latest Helm Secret of release ${REL} in ${NS}"
  local sec
  sec="$(get_latest_helm_secret_name)"
  if [[ -z "${sec:-}" ]]; then
    echo "No Helm Secret found for release ${REL} in ${NS}"
  else
    echo "Secret: ${sec}"
    show_helm_annotations "$sec"
  fi

  if [[ -n "${NONHELM}" ]]; then
    show_nonhelm_annotations
  fi

  if [[ -n "${sec:-}" ]]; then
    list_all_helm_secrets
  fi

  rbac_check
  show_dry_run_from_cm
}

# -------- Watch Mode --------
run_watch() {
  local i sec
  for ((i=1; i<=COUNT; i++)); do
    echo
    echo "[$(date -u +%Y-%m-%dT%H:%M:%SZ)] sample $i/$COUNT"
    sec="$(get_latest_helm_secret_name || true)"
    if [[ -n "${sec:-}" ]]; then
      show_helm_age_one_line "$sec"
    else
      echo "HELM: no secret found"
    fi
    if [[ -n "${NONHELM}" ]]; then
      if ! show_nonhelm_age_one_line; then
        echo "NONHL: resource ${NONHELM} not found"
      fi
    fi
    if [[ $i -lt $COUNT ]]; then
      sleep "$INTERVAL"
    fi
  done
}

# -------- Demo Runner --------
run_demo() {
  echo "== DEMO using DEMO_* variables at top of this file =="
  echo "REL=${DEMO_REL} NS=${DEMO_NS}"
  echo "NONHELM=${DEMO_NONHELM:-<empty>}"
  echo "MGMT_NS=${DEMO_MGMT_NS} SA=${DEMO_SA}"
  echo "CFG_CM=${DEMO_CFG_CM} CFG_CM_NS=${DEMO_CFG_CM_NS}"
  echo

  # 1) One-shot Helm check
  "$0" --rel "$DEMO_REL" --ns "$DEMO_NS" || true
  echo

  # 2) Helm + Non-Helm (only if DEMO_NONHELM set)
  if [[ -n "${DEMO_NONHELM}" ]]; then
    "$0" --rel "$DEMO_REL" --ns "$DEMO_NS" --nonhelm "$DEMO_NONHELM" || true
    echo
  fi

  # 3) RBAC check
  "$0" --rel "$DEMO_REL" --ns "$DEMO_NS" \
      --mgmt-ns "$DEMO_MGMT_NS" --sa "$DEMO_SA" || true
  echo

  # 4) DRY_RUN from ConfigMap
  "$0" --rel "$DEMO_REL" --ns "$DEMO_NS" \
      --cfg-cm "$DEMO_CFG_CM" --cfg-cm-ns "$DEMO_CFG_CM_NS" || true
  echo

  # 5) Watch mode (short demo: every 60s, 3 samples)
  "$0" --rel "$DEMO_REL" --ns "$DEMO_NS" --watch --interval 60 --count 3 || true
}

# -------- Execute --------
if [[ $PRINT_EXAMPLES -eq 1 ]]; then
  print_examples
  exit 0
fi

if [[ $RUN_DEMO -eq 1 ]]; then
  run_demo
  exit 0
fi

if [[ -z "$REL" || -z "$NS" ]]; then
  echo "ERROR: --rel and --ns are required."
  usage
  exit 1
fi

run_once
if [[ $WATCH_MODE -eq 1 ]]; then
  run_watch
fi
