#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
common_hcl="$repo_root/live/aws/aws-workspaces-platform/account-111122223333/us-east-1/common.hcl"

get_default_bundle() {
  local tier="$1"
  # Parse common.hcl directly to avoid terragrunt JSON flags and awk keyword conflicts.
  awk -v tier="$tier" '
    BEGIN { in_block=0 }
    /default_bundles[[:space:]]*=[[:space:]]*{/ { in_block=1; next }
    in_block && /^[[:space:]]*}/ { in_block=0 }
    in_block {
      # Match lines like: soc = "wsb-..."
      if ($0 ~ "^[[:space:]]*" tier "[[:space:]]*=") {
        # Strip inline comments and quotes.
        sub(/[[:space:]]*#.*/, "", $0)
        sub(/[[:space:]]*\/\/.*/, "", $0)
        gsub(/"/, "", $0)
        split($0, a, "=")
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[2])
        print a[2]
        exit
      }
    }
  ' "$common_hcl"
}

# -----------------------------------------------------------------------------
# Helper to remove an existing user entry safely (used for replace flow).
# -----------------------------------------------------------------------------

remove_user_entry() {
  local target_user="$1"
  local file="$2"
  awk -v target_user="$target_user" '
    BEGIN { in_ws=0; in_obj=0; buf=""; user_hit=0 }
    /^[[:space:]]*workspaces[[:space:]]*=[[:space:]]*\[/ { in_ws=1; print; next }
    {
      if (in_ws && $0 ~ /^[[:space:]]*\\]/) { in_ws=0; print; next }
      if (in_ws && $0 ~ /^[[:space:]]*{/) {
        in_obj=1; buf=$0 "\n"; user_hit=0; next
      }
      if (in_obj) {
        buf = buf $0 "\n"
        if ($0 ~ "user_name[[:space:]]*=[[:space:]]*\\\"" target_user "\\\"") { user_hit=1 }
        if ($0 ~ /^[[:space:]]*},?[[:space:]]*$/) {
          if (!user_hit) { printf "%s", buf }
          in_obj=0; buf=""; user_hit=0
        }
        next
      }
      print
    }
  ' "$file" > "$file.tmp" && mv "$file.tmp" "$file"
}

cleanup() {
  local msg="$1"
  echo "CLEANUP: $msg" >&2
  if [[ -f "$terragrunt_file" ]]; then
    remove_user_entry "$user_name" "$terragrunt_file"
  fi
}

select_tier() {
  printf "Select bundle tier:\n  1) standard\n  2) soc\n  3) dev\n"
  read -r -p "Enter choice (1-3): " tier_choice
  case "$tier_choice" in
    1) tier="standard";;
    2) tier="soc";;
    3) tier="dev";;
    *) echo "ERROR: invalid choice" >&2; exit 1;;
  esac
}

deploy_pool() {
  local pool_unit_dir="$repo_root/live/aws/aws-workspaces-platform/account-111122223333/us-east-1/${tier}-pool"
  if [[ ! -f "$pool_unit_dir/terragrunt.hcl" ]]; then
    echo "ERROR: pool terragrunt.hcl not found at $pool_unit_dir/terragrunt.hcl" >&2
    exit 1
  fi

  cd "$pool_unit_dir"
  terragrunt init
  terragrunt plan
  terragrunt apply
}

# -----------------------------------------------------------------------------
# Input collection
# -----------------------------------------------------------------------------
printf "Select deployment type:\n  1) personal workspace\n  2) workspace pool\n"
read -r -p "Enter choice (1-2): " deployment_choice
select_tier

if [[ "$deployment_choice" == "2" ]]; then
  echo "Deploying ${tier} workspace pool..."
  deploy_pool
  exit 0
fi

if [[ "$deployment_choice" != "1" ]]; then
  echo "ERROR: invalid deployment choice" >&2
  exit 1
fi

read -r -p "Enter AD username (e.g., ALAY): " user_name
if [[ -z "$user_name" ]]; then
  echo "ERROR: username is required" >&2
  exit 1
fi

# Personal workspace deployments need a concrete bundle ID.
bundle_id="$(get_default_bundle "$tier" || true)"
if [[ -z "$bundle_id" ]]; then
  read -r -p "Enter bundle ID for $tier: " bundle_id
  if [[ -z "$bundle_id" ]]; then
    echo "ERROR: bundle ID is required" >&2
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# File update (insert WorkSpaces entry in the selected tier)
# -----------------------------------------------------------------------------
unit_dir="$repo_root/live/aws/aws-workspaces-platform/account-111122223333/us-east-1/$tier"
terragrunt_file="$unit_dir/terragrunt.hcl"

if [[ ! -f "$terragrunt_file" ]]; then
  echo "ERROR: terragrunt.hcl not found at $terragrunt_file" >&2
  exit 1
fi

name_suffix="${tier}-${bundle_id}"

if grep -Fq "user_name   = \"${user_name}\"" "$terragrunt_file"; then
  read -r -p "User '${user_name}' already exists in ${tier} tier. Remove and replace? (y/n): " replace_choice
  if [[ "$replace_choice" != "y" ]]; then
    echo "ERROR: user '${user_name}' already exists in ${tier} tier." >&2
    exit 1
  fi
  # Remove existing entries for this user before adding a new one.
  remove_user_entry "$user_name" "$terragrunt_file"
fi

# Insert the new workspace entry above the marker.
awk -v name_suffix="$name_suffix" -v user_name="$user_name" -v bundle_id="$bundle_id" '
  BEGIN { in_ws=0; inserted=0 }
  /^[[:space:]]*workspaces[[:space:]]*=[[:space:]]*\[/ { in_ws=1 }
  /WORKSPACES_ENTRIES_END/ {
    print "    {"
    print "      name_suffix = \"" name_suffix "\""
    print "      user_name   = \"" user_name "\""
    print "      bundle_id   = \"" bundle_id "\""
    print "    },"
    print
    inserted=1
    next
  }
  {
    if (in_ws && $0 ~ /^[[:space:]]*]$/ && inserted==0) {
      print "    {"
      print "      name_suffix = \"" name_suffix "\""
      print "      user_name   = \"" user_name "\""
      print "      bundle_id   = \"" bundle_id "\""
      print "    },"
      print "    # WORKSPACES_ENTRIES_END"
      inserted=1
    }
    print
    if (in_ws && $0 ~ /^[[:space:]]*]$/) { in_ws=0 }
  }
  END { if (inserted==0) exit 2 }
' "$terragrunt_file" > "$terragrunt_file.tmp" || {
  echo "ERROR: failed to insert workspace entry. Ensure a workspaces list exists in terragrunt.hcl." >&2
  exit 1
}

mv "$terragrunt_file.tmp" "$terragrunt_file"

# -----------------------------------------------------------------------------
# Execute Terragrunt and handle errors with cleanup + diagnostics.
# -----------------------------------------------------------------------------
cd "$unit_dir"
terragrunt init || { cleanup "init failed"; exit 1; }
terragrunt plan || { cleanup "plan failed"; exit 1; }
if ! terragrunt apply; then
  cleanup "apply failed"
  echo "DIAGNOSTICS: fetching WorkSpaces status for user '${user_name}'..." >&2
  aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='${user_name}']" --output json || true
  # Attempt to terminate errored WorkSpaces for this user to allow clean retries.
  ws_ids=$(aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='${user_name}' && State=='ERROR'].WorkspaceId" --output text || true)
  if [[ -n "${ws_ids}" ]]; then
    echo "CLEANUP: terminating errored WorkSpaces for user '${user_name}': ${ws_ids}" >&2
    for ws_id in ${ws_ids}; do
      req_json=$(printf '[{"WorkspaceId":"%s"}]' "$ws_id")
      aws workspaces terminate-workspaces --region us-east-1 --terminate-workspace-requests "$req_json" || true
    done
  fi
  exit 1
fi
