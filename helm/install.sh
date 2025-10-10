#!/usr/bin/env bash
#
# helm/install.sh — One-liner installer for Greybox Helm repo
# Usage examples:
#   ./install.sh --chart oblivion-sentinel --release obs --namespace devops
#   ./install.sh --chart oblivion-sentinel --version 0.1.0 --values ./myvalues.yaml
#   ./install.sh --list                     # show charts in repo
#   ./install.sh --chart x --upgrade        # upgrade --install
#   REPO_URL=https://greybox.itblognote.com/helm/repo ./install.sh --chart x
#
set -euo pipefail

# -------- Defaults (edit if you fork) --------
REPO_NAME_DEFAULT="greybox"
REPO_URL_DEFAULT="${REPO_URL:-https://greybox.itblognote.com/helm/repo}"
NAMESPACE_DEFAULT="devops"
RELEASE_DEFAULT=""        # if empty -> fallback to chart name
CHART_DEFAULT=""          # must be provided or selected
VERSION_DEFAULT=""        # empty -> pick latest found by 'helm search repo'
CREATE_NAMESPACE_DEFAULT="true"
ATOMIC_DEFAULT="true"
TIMEOUT_DEFAULT="5m"

# -------- Pretty output --------
bold()  { printf "\033[1m%s\033[0m\n" "$*"; }
info()  { printf "🔹 %s\n" "$*"; }
ok()    { printf "✅ %s\n" "$*"; }
warn()  { printf "⚠️  %s\n" "$*"; }
err()   { printf "❌ %s\n" "$*" >&2; }

# -------- Check dependencies --------
need() {
  command -v "$1" >/dev/null 2>&1 || { err "Missing dependency: $1"; exit 1; }
}
need helm

# -------- Args parsing --------
REPO_NAME="$REPO_NAME_DEFAULT"
REPO_URL="$REPO_URL_DEFAULT"
NAMESPACE="$NAMESPACE_DEFAULT"
RELEASE="$RELEASE_DEFAULT"
CHART="$CHART_DEFAULT"
VERSION="$VERSION_DEFAULT"
DRY_RUN="false"
DO_UPGRADE="false"
CREATE_NAMESPACE="$CREATE_NAMESPACE_DEFAULT"
ATOMIC="$ATOMIC_DEFAULT"
TIMEOUT="$TIMEOUT_DEFAULT"
DEBUG="false"
VALUES_FILES=()
SET_ARGS=()
LIST_ONLY="false"

usage() {
  cat <<'EOF'
Usage:
  install.sh --chart <name> [options]

Options:
  --chart, -c <name>          Chart name trong repo (bắt buộc nếu không dùng --list)
  --release, -r <name>        Release name (mặc định = chart name)
  --namespace, -n <ns>        Namespace (mặc định: devops)
  --version, -v <semver>      Version cụ thể (mặc định: lấy bản mới nhất)
  --values, -f <file>         values.yaml (có thể lặp lại nhiều lần)
  --set <k=v>                 Giá trị set nhanh (có thể lặp lại nhiều lần)
  --repo-url <url>            Helm repo URL (mặc định: https://greybox.itblognote.com/helm/repo)
  --repo-name <name>          Helm repo name local (mặc định: greybox)

  --upgrade                   Dùng 'helm upgrade --install' thay vì 'helm install'
  --dry-run                   Thử lệnh mà không áp dụng
  --no-create-namespace       Không tạo namespace nếu chưa có
  --no-atomic                 Tắt cờ --atomic
  --timeout <dur>             Timeout (mặc định: 5m)
  --debug                     Bật debug cho Helm
  --list                      Liệt kê charts/versions có trong repo rồi thoát
  --help, -h                  In hướng dẫn

Ví dụ:
  install.sh --chart oblivion-sentinel --namespace devops
  install.sh -c oblivion-sentinel -v 0.1.0 -f ./values.yaml -f ./values.prod.yaml
  install.sh -c oblivion-sentinel --set image.tag=1.2.3 --upgrade
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --chart|-c) CHART="$2"; shift 2;;
    --release|-r) RELEASE="$2"; shift 2;;
    --namespace|-n) NAMESPACE="$2"; shift 2;;
    --version|-v) VERSION="$2"; shift 2;;
    --values|-f) VALUES_FILES+=("$2"); shift 2;;
    --set) SET_ARGS+=("$2"); shift 2;;
    --repo-url) REPO_URL="$2"; shift 2;;
    --repo-name) REPO_NAME="$2"; shift 2;;
    --upgrade) DO_UPGRADE="true"; shift;;
    --dry-run) DRY_RUN="true"; shift;;
    --no-create-namespace) CREATE_NAMESPACE="false"; shift;;
    --no-atomic) ATOMIC="false"; shift;;
    --timeout) TIMEOUT="$2"; shift 2;;
    --debug) DEBUG="true"; shift;;
    --list) LIST_ONLY="true"; shift;;
    --help|-h) usage; exit 0;;
    *) err "Unknown option: $1"; usage; exit 1;;
  esac
done

# -------- Ensure repo configured --------
bold "Configuring Helm repo"
info "Repo name: $REPO_NAME"
info "Repo url : $REPO_URL"

if ! helm repo list | awk '{print $1}' | grep -qx "$REPO_NAME"; then
  helm repo add "$REPO_NAME" "$REPO_URL" >/dev/null
else
  info "Repo '$REPO_NAME' already exists"
fi
helm repo update >/dev/null
ok "Repo ready"

# -------- List mode --------
if [[ "$LIST_ONLY" == "true" ]]; then
  bold "Charts in $REPO_NAME:"
  helm search repo "${REPO_NAME}/" --versions || true
  exit 0
fi

# -------- Validate chart --------
if [[ -z "$CHART" ]]; then
  err "Missing --chart. Dùng --list để xem charts có sẵn."
  usage
  exit 1
fi

# Deduce release if empty
if [[ -z "$RELEASE" ]]; then
  RELEASE="$CHART"
fi

# -------- Resolve version if not specified --------
if [[ -z "$VERSION" ]]; then
  # pick latest version from helm search
  info "Resolving latest version for ${REPO_NAME}/${CHART}"
  # helm search repo returns lines like: REPO/CHART  VERSION ...
  VERSION="$(helm search repo "${REPO_NAME}/${CHART}" --versions \
    | awk 'NR==2 {print $2}')" || true
  if [[ -z "$VERSION" ]]; then
    err "Không tìm được version cho ${REPO_NAME}/${CHART}. Kiểm tra chart name hoặc repo URL."
    exit 1
  fi
  ok "Latest version detected: $VERSION"
fi

# -------- Build helm command --------
CMD=(helm install "$RELEASE" "${REPO_NAME}/${CHART}" --version "$VERSION" -n "$NAMESPACE" --timeout "$TIMEOUT")
[[ "$CREATE_NAMESPACE" == "true" ]] && CMD+=(--create-namespace)
[[ "$ATOMIC" == "true" ]] && CMD+=(--atomic)
[[ "$DEBUG" == "true" ]] && CMD+=(--debug)
[[ "$DRY_RUN" == "true" ]] && CMD+=(--dry-run)

if [[ "$DO_UPGRADE" == "true" ]]; then
  CMD=(helm upgrade --install "$RELEASE" "${REPO_NAME}/${CHART}" --version "$VERSION" -n "$NAMESPACE" --timeout "$TIMEOUT")
  [[ "$ATOMIC" == "true" ]] && CMD+=(--atomic)
  [[ "$DEBUG" == "true" ]] && CMD+=(--debug)
  [[ "$DRY_RUN" == "true" ]] && CMD+=(--dry-run)
fi

# append values files
for vf in "${VALUES_FILES[@]}"; do
  CMD+=(-f "$vf")
done

# append --set
for kv in "${SET_ARGS[@]}"; do
  CMD+=(--set "$kv")
done

bold "Executing:"
printf '  %q ' "${CMD[@]}"; printf '\n'
"${CMD[@]}"

ok "Done."
