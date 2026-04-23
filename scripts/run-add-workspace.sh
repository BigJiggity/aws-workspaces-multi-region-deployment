#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/deployment.env"

usage() {
  cat <<USAGE
Usage: ./scripts/run-add-workspace.sh [options]

Options:
  --config PATH      Path to deployment.env (default: config/deployment.env)
  --region REGION    Target region (default: PRIMARY_REGION from config)
  --help             Show help
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --region) REGION_OVERRIDE="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "ERROR: config file not found: $CONFIG_FILE" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$CONFIG_FILE"
set +a

TARGET_REGION="${REGION_OVERRIDE:-$PRIMARY_REGION}"
BASE_DIR="$REPO_ROOT/live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$TARGET_REGION"

if [[ ! -d "$BASE_DIR" ]]; then
  echo "ERROR: region directory not found: $BASE_DIR" >&2
  exit 1
fi

printf "Select deployment type:\n  1) personal workspace\n  2) workspace pool\n"
read -r -p "Enter choice (1-2): " deployment_choice

printf "Select bundle tier:\n  1) standard\n  2) soc\n  3) dev\n"
read -r -p "Enter choice (1-3): " tier_choice

case "$tier_choice" in
  1) tier="standard" ;;
  2) tier="soc" ;;
  3) tier="dev" ;;
  *) echo "ERROR: invalid tier" >&2; exit 1 ;;
esac

if [[ "$deployment_choice" == "2" ]]; then
  unit_dir="$BASE_DIR/${tier}-pool"
  [[ -f "$unit_dir/terragrunt.hcl" ]] || { echo "ERROR: missing $unit_dir/terragrunt.hcl" >&2; exit 1; }
  cd "$unit_dir"
  terragrunt init
  terragrunt plan
  terragrunt apply
  exit 0
fi

if [[ "$deployment_choice" != "1" ]]; then
  echo "ERROR: invalid deployment choice" >&2
  exit 1
fi

read -r -p "Enter AD username (e.g., jdoe): " user_name
[[ -n "$user_name" ]] || { echo "ERROR: username is required" >&2; exit 1; }

case "$tier" in
  standard) bundle_id="$STANDARD_BUNDLE" ;;
  soc) bundle_id="$SOC_BUNDLE" ;;
  dev) bundle_id="$DEV_BUNDLE" ;;
esac

if [[ -z "$bundle_id" ]]; then
  read -r -p "Enter bundle ID for $tier: " bundle_id
  [[ -n "$bundle_id" ]] || { echo "ERROR: bundle ID is required" >&2; exit 1; }
fi

unit_dir="$BASE_DIR/$tier"
terragrunt_file="$unit_dir/terragrunt.hcl"
[[ -f "$terragrunt_file" ]] || { echo "ERROR: missing $terragrunt_file" >&2; exit 1; }

if grep -Fq "user_name   = \"${user_name}\"" "$terragrunt_file"; then
  echo "ERROR: user '$user_name' already exists in $terragrunt_file" >&2
  exit 1
fi

name_suffix="${tier}-${bundle_id}"

awk -v name_suffix="$name_suffix" -v user_name="$user_name" -v bundle_id="$bundle_id" '
  /WORKSPACES_ENTRIES_END/ {
    print "    {"
    print "      name_suffix = \"" name_suffix "\""
    print "      user_name   = \"" user_name "\""
    print "      bundle_id   = \"" bundle_id "\""
    print "    },"
    print
    next
  }
  { print }
' "$terragrunt_file" > "$terragrunt_file.tmp"

mv "$terragrunt_file.tmp" "$terragrunt_file"

cd "$unit_dir"
terragrunt init
terragrunt plan
terragrunt apply
