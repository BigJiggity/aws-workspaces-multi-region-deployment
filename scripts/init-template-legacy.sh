#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

usage() {
  cat <<USAGE
Usage: ./init-template.sh [options]

Re-parameterizes this repository for a target organization/account.

Options:
  --org-slug VALUE          Organization slug (example: acme)
  --account-id VALUE        AWS account ID (12 digits)
  --region VALUE            AWS region (default: discovered current region)
  --environment VALUE       Environment label (default: pilot)
  --stack-name VALUE        Stack folder/name (default: aws-workspaces-platform)
  --name-prefix VALUE       Resource prefix override
  --project VALUE           Tag/project name override
  --owner VALUE             Tag owner override
  --department VALUE        Tag department override
  --directory-name VALUE    Directory domain name
  --directory-id VALUE      WorkSpaces directory ID (d-...)
  --pool-directory-id VALUE WorkSpaces pools directory ID (wsd-...)
  --backend-bucket VALUE    Terraform state bucket name
  --lock-table VALUE        Terraform lock table name
  --kms-alias VALUE         KMS alias for state encryption
  --standard-bundle VALUE   Standard bundle ID (wsb-...)
  --soc-bundle VALUE        SOC bundle ID (wsb-...)
  --dev-bundle VALUE        Dev bundle ID (wsb-...)
  --vpc-id VALUE            VPC ID used by pool units
  --subnet-a VALUE          First subnet ID used by pool units
  --subnet-b VALUE          Second subnet ID used by pool units
  --help                    Show this help
USAGE
}

if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
  usage
  exit 0
fi

get_hcl_string() {
  local key="$1"
  local file="$2"
  sed -nE "s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$file" | head -n1
}

get_block_value() {
  local key="$1"
  local file="$2"
  sed -nE "/default_bundles[[:space:]]*=\s*\{/,/^[[:space:]]*\}/ s/^[[:space:]]*${key}[[:space:]]*=[[:space:]]*\"([^\"]+)\".*/\1/p" "$file" | head -n1
}

get_pool_subnet() {
  local file="$1"
  local index="$2"
  awk -v idx="$index" '
    BEGIN { in_block=0; count=0 }
    /^[[:space:]]*subnet_ids[[:space:]]*=[[:space:]]*\[/ { in_block=1; next }
    in_block && /^[[:space:]]*]/ { in_block=0; next }
    in_block {
      if ($0 ~ /"/) {
        line = $0
        sub(/^[^"]*"/, "", line)
        sub(/".*$/, "", line)
        count++
        if (count == idx) {
          print line
          exit
        }
      }
    }
  ' "$file"
}

prompt_with_default() {
  local var_name="$1"
  local prompt="$2"
  local default_value="$3"
  local reply
  read -r -p "${prompt} [${default_value}]: " reply
  if [[ -z "$reply" ]]; then
    reply="$default_value"
  fi
  printf -v "$var_name" '%s' "$reply"
}

stack_dir="$(find "$repo_root/live/aws" -mindepth 1 -maxdepth 1 -type d -name 'aws-workspaces-*' | head -n1)"
if [[ -z "$stack_dir" ]]; then
  echo "ERROR: unable to discover stack directory under $repo_root/live/aws" >&2
  exit 1
fi

current_stack_name="$(basename "$stack_dir")"
account_dir="$(find "$stack_dir" -mindepth 1 -maxdepth 1 -type d -name 'account-*' | head -n1)"
if [[ -z "$account_dir" ]]; then
  echo "ERROR: unable to discover account directory under $stack_dir" >&2
  exit 1
fi

region_dir="$(find "$account_dir" -mindepth 1 -maxdepth 1 -type d | head -n1)"
if [[ -z "$region_dir" ]]; then
  echo "ERROR: unable to discover region directory under $account_dir" >&2
  exit 1
fi

current_account_scope="$(basename "$account_dir")"
current_account_id="${current_account_scope#account-}"
current_region="$(basename "$region_dir")"

current_common_hcl="$region_dir/common.hcl"
current_root_hcl="$repo_root/root.hcl"
current_account_hcl="$account_dir/account.hcl"

if [[ ! -f "$current_common_hcl" || ! -f "$current_root_hcl" || ! -f "$current_account_hcl" ]]; then
  echo "ERROR: expected config files are missing (root.hcl/account.hcl/common.hcl)." >&2
  exit 1
fi

current_name_prefix="$(get_hcl_string name_prefix "$current_root_hcl")"
current_project="$(get_hcl_string Project "$current_root_hcl")"
current_owner="$(get_hcl_string Owner "$current_root_hcl")"
current_department="$(get_hcl_string Department "$current_root_hcl")"
current_directory_name="$(get_hcl_string directory_name "$current_common_hcl")"
current_directory_name_upper="$(printf '%s' "$current_directory_name" | tr '[:lower:]' '[:upper:]')"
current_directory_id="$(get_hcl_string directory_id "$current_common_hcl")"
current_pool_directory_id="$(get_hcl_string pool_directory_id "$current_common_hcl")"
current_backend_bucket="$(get_hcl_string bucket "$current_common_hcl")"
current_lock_table="$(get_hcl_string dynamodb_table "$current_common_hcl")"
current_kms_alias="$(get_hcl_string kms_key_id "$current_common_hcl")"
current_standard_bundle="$(get_block_value standard "$current_common_hcl")"
current_soc_bundle="$(get_block_value soc "$current_common_hcl")"
current_dev_bundle="$(get_block_value dev "$current_common_hcl")"
current_account_name="$(get_hcl_string account_name "$current_account_hcl")"
current_standard_pool_tg="$region_dir/standard-pool/terragrunt.hcl"
current_vpc_id=""
current_subnet_a=""
current_subnet_b=""
if [[ -f "$current_standard_pool_tg" ]]; then
  current_vpc_id="$(get_hcl_string vpc_id "$current_standard_pool_tg")"
  current_subnet_a="$(get_pool_subnet "$current_standard_pool_tg" 1)"
  current_subnet_b="$(get_pool_subnet "$current_standard_pool_tg" 2)"
fi

org_slug=""
account_id="$current_account_id"
region="$current_region"
environment="pilot"
stack_name="$current_stack_name"
name_prefix=""
project_name=""
owner="$current_owner"
department="$current_department"
directory_name="$current_directory_name"
directory_id="$current_directory_id"
pool_directory_id="$current_pool_directory_id"
backend_bucket="$current_backend_bucket"
lock_table="$current_lock_table"
kms_alias="$current_kms_alias"
standard_bundle="$current_standard_bundle"
soc_bundle="$current_soc_bundle"
dev_bundle="$current_dev_bundle"
vpc_id="$current_vpc_id"
subnet_a="$current_subnet_a"
subnet_b="$current_subnet_b"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --org-slug) org_slug="$2"; shift 2 ;;
    --account-id) account_id="$2"; shift 2 ;;
    --region) region="$2"; shift 2 ;;
    --environment) environment="$2"; shift 2 ;;
    --stack-name) stack_name="$2"; shift 2 ;;
    --name-prefix) name_prefix="$2"; shift 2 ;;
    --project) project_name="$2"; shift 2 ;;
    --owner) owner="$2"; shift 2 ;;
    --department) department="$2"; shift 2 ;;
    --directory-name) directory_name="$2"; shift 2 ;;
    --directory-id) directory_id="$2"; shift 2 ;;
    --pool-directory-id) pool_directory_id="$2"; shift 2 ;;
    --backend-bucket) backend_bucket="$2"; shift 2 ;;
    --lock-table) lock_table="$2"; shift 2 ;;
    --kms-alias) kms_alias="$2"; shift 2 ;;
    --standard-bundle) standard_bundle="$2"; shift 2 ;;
    --soc-bundle) soc_bundle="$2"; shift 2 ;;
    --dev-bundle) dev_bundle="$2"; shift 2 ;;
    --vpc-id) vpc_id="$2"; shift 2 ;;
    --subnet-a) subnet_a="$2"; shift 2 ;;
    --subnet-b) subnet_b="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$org_slug" ]]; then
  prompt_with_default org_slug "Organization slug" "workspaces"
fi

if [[ -z "$name_prefix" ]]; then
  name_prefix="${org_slug}-workspaces-platform-${environment}"
fi
if [[ -z "$project_name" ]]; then
  project_name="${org_slug}-workspaces-platform"
fi
if [[ -z "$owner" ]]; then
  owner="${org_slug}-platform"
fi
if [[ -z "$department" ]]; then
  department="${org_slug^^}"
fi
if [[ -z "$directory_name" ]]; then
  directory_name="${org_slug}.local"
fi
if [[ -z "$backend_bucket" ]]; then
  backend_bucket="${org_slug}-workspaces-platform-terraform-state"
fi
if [[ -z "$lock_table" ]]; then
  lock_table="${name_prefix}-terraform-locks"
fi
if [[ -z "$kms_alias" ]]; then
  kms_alias="alias/${name_prefix}-terraform-state-01"
fi

directory_name_upper="$(printf '%s' "$directory_name" | tr '[:lower:]' '[:upper:]')"

if [[ ! "$account_id" =~ ^[0-9]{12}$ ]]; then
  echo "ERROR: account-id must be a 12-digit AWS account ID." >&2
  exit 1
fi

collect_files() {
  find "$repo_root" -type f \
    \( -name '*.hcl' -o -name '*.tf' -o -name '*.sh' -o -name '*.ps1' -o -name '*.md' -o -name '*.wiki' -o -name '*.txt' -o -name '*.mof' -o -name '*.json' -o -name 'Jenkinsfile' \) \
    ! -path '*/.git/*' \
    ! -path '*/.terraform/*' \
    ! -name '*.zip' \
    ! -path "$repo_root/init-template.sh"
}

replace_literal() {
  local from="$1"
  local to="$2"
  if [[ -z "$from" || "$from" == "$to" ]]; then
    return 0
  fi

  while IFS= read -r file; do
    FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
  done < <(collect_files)
}

echo "Applying template initialization values..."

replace_literal "$current_stack_name" "$stack_name"
replace_literal "$current_account_scope" "account-${account_id}"
replace_literal "$current_account_id" "$account_id"
replace_literal "$current_region" "$region"
replace_literal "$current_name_prefix" "$name_prefix"
replace_literal "$current_project" "$project_name"
replace_literal "$current_account_name" "$project_name"
replace_literal "$current_owner" "$owner"
replace_literal "$current_department" "$department"
replace_literal "$current_directory_name" "$directory_name"
replace_literal "$current_directory_name_upper" "$directory_name_upper"
replace_literal "$current_directory_id" "$directory_id"
replace_literal "$current_pool_directory_id" "$pool_directory_id"
replace_literal "$current_backend_bucket" "$backend_bucket"
replace_literal "$current_lock_table" "$lock_table"
replace_literal "$current_kms_alias" "$kms_alias"
replace_literal "$current_standard_bundle" "$standard_bundle"
replace_literal "$current_soc_bundle" "$soc_bundle"
replace_literal "$current_dev_bundle" "$dev_bundle"
replace_literal "$current_vpc_id" "$vpc_id"
replace_literal "$current_subnet_a" "$subnet_a"
replace_literal "$current_subnet_b" "$subnet_b"

current_stack_dir_live="$repo_root/live/aws/$current_stack_name"
current_stack_dir_module="$repo_root/modules/source/aws/$current_stack_name"
new_stack_dir_live="$repo_root/live/aws/$stack_name"
new_stack_dir_module="$repo_root/modules/source/aws/$stack_name"

if [[ "$current_stack_name" != "$stack_name" ]]; then
  [[ -d "$current_stack_dir_live" ]] && mv "$current_stack_dir_live" "$new_stack_dir_live"
  [[ -d "$current_stack_dir_module" ]] && mv "$current_stack_dir_module" "$new_stack_dir_module"
fi

if [[ "$current_stack_name" == "$stack_name" ]]; then
  new_stack_dir_live="$current_stack_dir_live"
  new_stack_dir_module="$current_stack_dir_module"
fi

current_account_dir_live="$new_stack_dir_live/$current_account_scope"
current_account_dir_module="$new_stack_dir_module/$current_account_scope"
new_account_scope="account-${account_id}"
new_account_dir_live="$new_stack_dir_live/$new_account_scope"
new_account_dir_module="$new_stack_dir_module/$new_account_scope"

if [[ "$current_account_scope" != "$new_account_scope" ]]; then
  [[ -d "$current_account_dir_live" ]] && mv "$current_account_dir_live" "$new_account_dir_live"
  [[ -d "$current_account_dir_module" ]] && mv "$current_account_dir_module" "$new_account_dir_module"
fi

if [[ "$current_account_scope" == "$new_account_scope" ]]; then
  new_account_dir_live="$current_account_dir_live"
  new_account_dir_module="$current_account_dir_module"
fi

current_region_dir_live="$new_account_dir_live/$current_region"
current_region_dir_module="$new_account_dir_module/$current_region"
new_region_dir_live="$new_account_dir_live/$region"
new_region_dir_module="$new_account_dir_module/$region"

if [[ "$current_region" != "$region" ]]; then
  [[ -d "$current_region_dir_live" ]] && mv "$current_region_dir_live" "$new_region_dir_live"
  [[ -d "$current_region_dir_module" ]] && mv "$current_region_dir_module" "$new_region_dir_module"
fi

echo "Initialization complete."
echo "  Stack:        $stack_name"
echo "  Account ID:   $account_id"
echo "  Region:       $region"
echo "  Name Prefix:  $name_prefix"
echo "  Project Tag:  $project_name"
echo "  Directory:    $directory_name"
