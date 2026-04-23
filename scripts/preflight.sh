#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/deployment.env"

usage() {
  cat <<USAGE
Usage: ./scripts/preflight.sh [--config PATH]
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  echo "Run ./scripts/configure-project.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$CONFIG_FILE"
set +a

command -v terraform >/dev/null || { echo "ERROR: terraform not found in PATH" >&2; exit 1; }
command -v terragrunt >/dev/null || { echo "ERROR: terragrunt not found in PATH" >&2; exit 1; }
command -v aws >/dev/null || { echo "ERROR: aws CLI not found in PATH" >&2; exit 1; }

echo "Preflight: tooling versions"
terraform version | head -n 1
terragrunt --version
aws --version

echo "Preflight: AWS identity"
aws sts get-caller-identity >/dev/null

echo "Preflight: backend resources"
aws s3api head-bucket --bucket "$BACKEND_BUCKET" --region "$PRIMARY_REGION" >/dev/null
aws dynamodb describe-table --table-name "$LOCK_TABLE" --region "$PRIMARY_REGION" >/dev/null
aws kms describe-key --key-id "$KMS_ALIAS" --region "$PRIMARY_REGION" >/dev/null

echo "Preflight: configured regions"
IFS=',' read -r -a regions <<< "$DEPLOY_REGIONS"
for region in "${regions[@]}"; do
  region="${region// /}"
  [[ -z "$region" ]] && continue
  live_unit="$REPO_ROOT/live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region"
  module_unit="$REPO_ROOT/modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region"
  [[ -d "$live_unit" ]] || { echo "ERROR: missing live region directory: $live_unit" >&2; exit 1; }
  [[ -d "$module_unit" ]] || { echo "ERROR: missing module region directory: $module_unit" >&2; exit 1; }
done

echo "Preflight: OK"
