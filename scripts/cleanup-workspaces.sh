#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="$REPO_ROOT/config/deployment.env"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --region) REGION_OVERRIDE="$2"; shift 2 ;;
    --help|-h)
      echo "Usage: ./scripts/cleanup-workspaces.sh [--config PATH] [--region REGION]"
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
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

region="${REGION_OVERRIDE:-$PRIMARY_REGION}"

read -r -p "Enter AD username to clean up (e.g., jdoe): " user_name
if [[ -z "$user_name" ]]; then
  echo "ERROR: username is required" >&2
  exit 1
fi

echo "Listing WorkSpaces for user '${user_name}' in ${region}..."
aws workspaces describe-workspaces --region "$region" --query "Workspaces[?UserName=='${user_name}']" --output table || true

ws_ids=$(aws workspaces describe-workspaces --region "$region" --query "Workspaces[?UserName=='${user_name}' && State=='ERROR'].WorkspaceId" --output text || true)
if [[ -z "${ws_ids}" ]]; then
  echo "No errored WorkSpaces found for user '${user_name}'."
  exit 0
fi

echo "Terminating errored WorkSpaces for user '${user_name}': ${ws_ids}"
for ws_id in ${ws_ids}; do
  req_json=$(printf '[{"WorkspaceId":"%s"}]' "$ws_id")
  aws workspaces terminate-workspaces --region "$region" --terminate-workspace-requests "$req_json"
done

echo "Cleanup complete."
