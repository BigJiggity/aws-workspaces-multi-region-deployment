#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DEFAULT_CONFIG="$REPO_ROOT/config/deployment.env"

usage() {
  cat <<USAGE
Usage: ./scripts/configure-project.sh [options]

Options:
  --config PATH                Path to deployment.env (default: config/deployment.env)
  --org-slug VALUE             Override ORG_SLUG
  --environment VALUE          Override ENVIRONMENT
  --account-id VALUE           Override ACCOUNT_ID
  --primary-region VALUE       Override PRIMARY_REGION
  --regions CSV                Override DEPLOY_REGIONS (comma-separated)
  --name-prefix VALUE          Override NAME_PREFIX
  --project-name VALUE         Override PROJECT_NAME
  --owner VALUE                Override OWNER_TAG
  --department VALUE           Override DEPARTMENT_TAG
  --backend-bucket VALUE       Override BACKEND_BUCKET
  --lock-table VALUE           Override LOCK_TABLE
  --kms-alias VALUE            Override KMS_ALIAS
  --directory-name VALUE       Override DIRECTORY_NAME
  --directory-id VALUE         Override DIRECTORY_ID
  --pool-directory-id VALUE    Override POOL_DIRECTORY_ID
  --pool-vpc-id VALUE          Override POOL_VPC_ID
  --pool-subnet-ids CSV        Override POOL_SUBNET_IDS
  --saml-secret-name VALUE     Override SAML_XML_SECRET_NAME
  --prune-regions true|false   Delete non-selected WorkSpaces platform region dirs
  --help                       Show this help
USAGE
}

trim() {
  local input="$1"
  input="${input#${input%%[![:space:]]*}}"
  input="${input%${input##*[![:space:]]}}"
  printf '%s' "$input"
}

normalize_csv() {
  local csv="$1"
  local out=""
  local item
  IFS=',' read -r -a parts <<< "$csv"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    if [[ -z "$out" ]]; then
      out="$item"
    else
      out="$out,$item"
    fi
  done
  printf '%s' "$out"
}

csv_contains() {
  local csv="$1"
  local needle="$2"
  local item
  IFS=',' read -r -a parts <<< "$csv"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ "$item" == "$needle" ]] && return 0
  done
  return 1
}

hcl_string_list_from_csv() {
  local csv="$1"
  local out=""
  local item
  IFS=',' read -r -a parts <<< "$csv"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    out+="    \"$item\",\n"
  done
  printf '%b' "$out"
}

trusted_cidrs_hcl() {
  local csv="$1"
  local out=""
  local item
  local idx=0

  IFS=',' read -r -a parts <<< "$csv"
  for item in "${parts[@]}"; do
    item="$(trim "$item")"
    [[ -z "$item" ]] && continue
    out+="    {\n"
    out+="      source      = \"$item\"\n"
    out+="      description = \"Trusted CIDR\"\n"
    out+="    },\n"
    idx=$((idx + 1))
  done

  if [[ $idx -eq 0 ]]; then
    out+="    {\n"
    out+="      source      = \"10.0.0.0/8\"\n"
    out+="      description = \"Trusted CIDR\"\n"
    out+="    },\n"
  fi

  printf '%b' "$out"
}

replace_literal() {
  local from="$1"
  local to="$2"

  if [[ -z "$from" || "$from" == "$to" ]]; then
    return 0
  fi

  while IFS= read -r -d '' file; do
    FROM="$from" TO="$to" perl -0pi -e 's/\Q$ENV{FROM}\E/$ENV{TO}/g' "$file"
  done < <(
    find "$REPO_ROOT" -type f \
      \( -name '*.hcl' -o -name '*.tf' -o -name '*.md' -o -name '*.sh' -o -name '*.ps1' -o -name '*.txt' -o -name '*.wiki' -o -name '*.yaml' -o -name '*.yml' -o -name '*.json' -o -name '*.cfg' -o -name '*.xml' -o -name 'Jenkinsfile' \) \
      ! -path '*/.git/*' \
      ! -path '*/.terraform/*' \
      ! -path '*/.terragrunt-cache/*' \
      ! -name '*.zip' \
      -print0
  )
}

rename_account_scope_dirs() {
  local old_scope="$1"
  local new_scope="$2"
  local dir

  if [[ -z "$old_scope" || "$old_scope" == "$new_scope" ]]; then
    return 0
  fi

  while IFS= read -r -d '' dir; do
    local target
    target="$(dirname "$dir")/$new_scope"
    if [[ -d "$target" ]]; then
      rsync -a "$dir/" "$target/"
      rm -rf "$dir"
    else
      mv "$dir" "$target"
    fi
  done < <(find "$REPO_ROOT" -depth -type d -name "$old_scope" -print0)
}

write_global_hcl() {
  cat > "$REPO_ROOT/live/global.hcl" <<EOF_GLOBAL
# Global metadata shared by all deployment units.
# Updated by scripts/configure-project.sh.

locals {
  deployment_layer = "live"

  name_prefix = "$NAME_PREFIX"
  region      = "$PRIMARY_REGION"

  tags = {
    Project     = "$PROJECT_NAME"
    Environment = "$ENVIRONMENT"
    ManagedBy   = "terragrunt"
    Owner       = "$OWNER_TAG"
    Department  = "$DEPARTMENT_TAG"
    Application = "aws-workspaces-multi-region-deployment"
    CostCenter  = "$COST_CENTER"
    Region      = "$PRIMARY_REGION"
    DataClass   = "$DATA_CLASS"
    Criticality = "$CRITICALITY"
    Compliance  = "$COMPLIANCE"
  }
}
EOF_GLOBAL
}

write_backend_tfvars() {
  local backend_dir="$REPO_ROOT/backend/$PRIMARY_REGION"
  local template_dir

  if [[ ! -d "$backend_dir" ]]; then
    template_dir="$(find "$REPO_ROOT/backend" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
    if [[ -z "$template_dir" ]]; then
      echo "ERROR: no backend region template exists under $REPO_ROOT/backend" >&2
      exit 1
    fi
    cp -R "$template_dir" "$backend_dir"
  fi

  cat > "$backend_dir/terraform.tfvars" <<EOF_BACKEND
region              = "$PRIMARY_REGION"
name_prefix         = "$NAME_PREFIX"
state_bucket_name   = "$BACKEND_BUCKET"
dynamodb_table_name = "$LOCK_TABLE"
kms_alias           = "$KMS_ALIAS"

tags = {
  Project     = "$PROJECT_NAME"
  Environment = "$ENVIRONMENT"
  ManagedBy   = "terraform"
  Owner       = "$OWNER_TAG"
  Department  = "$DEPARTMENT_TAG"
  Application = "terraform-backend"
  CostCenter  = "$COST_CENTER"
  Region      = "$PRIMARY_REGION"
  DataClass   = "$DATA_CLASS"
  Criticality = "$CRITICALITY"
  Compliance  = "$COMPLIANCE"
}
EOF_BACKEND
}

write_workspaces_account_hcl() {
  local live_account_dir="$1"
  cat > "$live_account_dir/account.hcl" <<EOF_ACCOUNT
# Account-level configuration for AWS account $ACCOUNT_ID.

locals {
  account_id   = "$ACCOUNT_ID"
  account_name = "$PROJECT_NAME"
}
EOF_ACCOUNT
}

write_common_hcl() {
  local region="$1"
  local file="$2"
  local trusted_hcl
  trusted_hcl="$(trusted_cidrs_hcl "$TRUSTED_CIDRS")"

  cat > "$file" <<EOF_COMMON
# Common configuration shared across WorkSpaces units in this account/region.

locals {
  account_scope = "account-$ACCOUNT_ID"
  region        = "$region"

  directory_id      = "$DIRECTORY_ID"
  directory_name    = "$DIRECTORY_NAME"
  pool_directory_id = "$POOL_DIRECTORY_ID"

  workspaces_subnets = {
    "$WORKSPACES_SUBNET_1_CIDR" = { az = "$WORKSPACES_SUBNET_1_AZ", az_id = "$WORKSPACES_SUBNET_1_AZ_ID" }
    "$WORKSPACES_SUBNET_2_CIDR" = { az = "$WORKSPACES_SUBNET_2_AZ", az_id = "$WORKSPACES_SUBNET_2_AZ_ID" }
  }

  workspaces_running_mode      = "$WORKSPACES_RUNNING_MODE"
  workspaces_auto_stop_timeout = $WORKSPACES_AUTO_STOP_TIMEOUT
  workspaces_create_timeout    = "$WORKSPACES_CREATE_TIMEOUT"

  default_bundles = {
    standard = "$STANDARD_BUNDLE"
    soc      = "$SOC_BUNDLE"
    dev      = "$DEV_BUNDLE"
  }

  trusted_cidrs = [
$trusted_hcl  ]

  backend = {
    bucket         = "$BACKEND_BUCKET"
    dynamodb_table = "$LOCK_TABLE"
    region         = "$PRIMARY_REGION"
    kms_key_id     = "$KMS_ALIAS"
  }
}
EOF_COMMON
}

write_personal_unit() {
  local region="$1"
  local tier="$2"
  local file="$3"

  cat > "$file" <<EOF_PERSONAL
# Terragrunt deployment unit for: WorkSpaces $tier ($region)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "\${get_terragrunt_dir()}/../../../../../../modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID//$region"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = local.common_cfg.locals.backend.bucket
    key            = "workspaces/platform/$region/$tier.tfstate"
    region         = local.common_cfg.locals.backend.region
    dynamodb_table = local.common_cfg.locals.backend.dynamodb_table
    encrypt        = true
    kms_key_id     = local.common_cfg.locals.backend.kms_key_id
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

locals {
  global_cfg   = read_terragrunt_config(find_in_parent_folders("live/global.hcl"))
  provider_cfg = read_terragrunt_config(find_in_parent_folders("live/aws/provider.hcl"))
  stack_cfg    = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/stack.hcl"))
  common_cfg   = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/common.hcl"))

  unit_path     = "live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/$tier"
  source_path   = "modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region"
  account_scope = local.common_cfg.locals.account_scope
  region        = local.common_cfg.locals.region
}

inputs = {
  deployment_layer = local.global_cfg.locals.deployment_layer
  cloud_provider   = local.provider_cfg.locals.cloud_provider
  stack_name       = local.stack_cfg.locals.stack_name
  account_scope    = local.account_scope
  region           = local.region
  unit_path        = local.unit_path
  source_path      = local.source_path

  name_prefix = local.global_cfg.locals.name_prefix

  directory_id   = local.common_cfg.locals.directory_id
  directory_name = local.common_cfg.locals.directory_name

  workspaces_subnets = local.common_cfg.locals.workspaces_subnets

  workspaces = [
    # WORKSPACES_ENTRIES_END (do not remove; scripts insert above this line)
  ]

  workspaces_running_mode      = local.common_cfg.locals.workspaces_running_mode
  workspaces_auto_stop_timeout = local.common_cfg.locals.workspaces_auto_stop_timeout
  workspaces_create_timeout    = local.common_cfg.locals.workspaces_create_timeout

  trusted_cidrs = local.common_cfg.locals.trusted_cidrs

  tags = local.global_cfg.locals.tags
}
EOF_PERSONAL
}

write_pool_unit() {
  local region="$1"
  local tier="$2"
  local file="$3"
  local label="$4"
  local bundle_key="$5"
  local subnet_hcl
  local secret_arn
  local settings_group

  subnet_hcl="$(hcl_string_list_from_csv "$POOL_SUBNET_IDS")"
  secret_arn="arn:aws:secretsmanager:$region:$ACCOUNT_ID:secret:$SAML_XML_SECRET_NAME"
  settings_group="$NAME_PREFIX/$tier-pool-v1"

  cat > "$file" <<EOF_POOL
# Terragrunt deployment unit for: WorkSpaces $label pool ($region)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "\${get_terragrunt_dir()}/../../../../../../modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID//$region/workspaces-pool-soc"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = local.common_cfg.locals.backend.bucket
    key            = "workspaces/platform/$region/$tier-pool.tfstate"
    region         = local.common_cfg.locals.backend.region
    dynamodb_table = local.common_cfg.locals.backend.dynamodb_table
    encrypt        = true
    kms_key_id     = local.common_cfg.locals.backend.kms_key_id
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

locals {
  global_cfg   = read_terragrunt_config(find_in_parent_folders("live/global.hcl"))
  provider_cfg = read_terragrunt_config(find_in_parent_folders("live/aws/provider.hcl"))
  stack_cfg    = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/stack.hcl"))
  common_cfg   = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/common.hcl"))

  unit_path     = "live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/$tier-pool"
  source_path   = "modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/workspaces-pool-soc"
  account_scope = local.common_cfg.locals.account_scope
  region        = local.common_cfg.locals.region
}

inputs = {
  deployment_layer = local.global_cfg.locals.deployment_layer
  cloud_provider   = local.provider_cfg.locals.cloud_provider
  stack_name       = local.stack_cfg.locals.stack_name
  account_scope    = local.account_scope
  region           = local.region
  unit_path        = local.unit_path
  source_path      = local.source_path

  name_prefix      = local.global_cfg.locals.name_prefix
  pool_name        = "$NAME_PREFIX-$tier-pool-v1"
  pool_description = "$label WorkSpaces pool"

  vpc_id = "$POOL_VPC_ID"
  subnet_ids = [
$subnet_hcl  ]

  pool_directory_id   = local.common_cfg.locals.pool_directory_id
  saml_xml_secret_arn = "$secret_arn"

  bundle_id = local.common_cfg.locals.default_bundles.$bundle_key

  desired_user_sessions = 2
  min_user_sessions     = 2
  max_user_sessions     = 10

  max_user_duration_minutes       = 480
  disconnect_timeout_minutes      = 60
  idle_disconnect_timeout_minutes = 30

  application_settings_status = "ENABLED"
  application_settings_group  = "$settings_group"

  running_mode = local.common_cfg.locals.workspaces_running_mode

  tags = merge(local.global_cfg.locals.tags, {
    Application   = "workspaces-pool"
    Purpose       = "$label Pool Sessions"
    WorkspaceType = "$label"
  })
}
EOF_POOL
}

write_installs_bucket_unit() {
  local region="$1"
  local file="$2"

  cat > "$file" <<EOF_BUCKET
# Terragrunt deployment unit for: installs-bucket ($region)

include "root" {
  path = find_in_parent_folders("root.hcl")
}

terraform {
  source = "\${get_terragrunt_dir()}/../../../../../../modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID//$region/installs-bucket"
}

remote_state {
  backend = "s3"

  config = {
    bucket         = local.common_cfg.locals.backend.bucket
    key            = "workspaces/platform/$region/installs-bucket.tfstate"
    region         = local.common_cfg.locals.backend.region
    dynamodb_table = local.common_cfg.locals.backend.dynamodb_table
    encrypt        = true
    kms_key_id     = local.common_cfg.locals.backend.kms_key_id
  }

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
}

locals {
  global_cfg   = read_terragrunt_config(find_in_parent_folders("live/global.hcl"))
  provider_cfg = read_terragrunt_config(find_in_parent_folders("live/aws/provider.hcl"))
  stack_cfg    = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/stack.hcl"))
  common_cfg   = read_terragrunt_config(find_in_parent_folders("live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/common.hcl"))

  unit_path     = "live/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/installs-bucket"
  source_path   = "modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID/$region/installs-bucket"
  account_scope = local.common_cfg.locals.account_scope
  region        = local.common_cfg.locals.region
}

inputs = {
  deployment_layer = local.global_cfg.locals.deployment_layer
  cloud_provider   = local.provider_cfg.locals.cloud_provider
  stack_name       = local.stack_cfg.locals.stack_name
  account_scope    = local.account_scope
  region           = local.region
  unit_path        = local.unit_path
  source_path      = local.source_path

  name_prefix = local.global_cfg.locals.name_prefix
  tags        = local.global_cfg.locals.tags
}
EOF_BUCKET
}

configure_workspaces_platform_stack() {
  local live_account_dir="$REPO_ROOT/live/aws/aws-workspaces-platform/account-$ACCOUNT_ID"
  local module_account_dir="$REPO_ROOT/modules/source/aws/aws-workspaces-platform/account-$ACCOUNT_ID"
  local template_live_region
  local template_module_region
  local region

  [[ -d "$live_account_dir" ]] || { echo "ERROR: missing $live_account_dir" >&2; exit 1; }
  [[ -d "$module_account_dir" ]] || { echo "ERROR: missing $module_account_dir" >&2; exit 1; }

  write_workspaces_account_hcl "$live_account_dir"

  template_live_region="$(find "$live_account_dir" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  template_module_region="$(find "$module_account_dir" -mindepth 1 -maxdepth 1 -type d | head -n1 || true)"
  [[ -n "$template_live_region" && -n "$template_module_region" ]] || { echo "ERROR: could not identify stack templates" >&2; exit 1; }

  template_live_region="$(basename "$template_live_region")"
  template_module_region="$(basename "$template_module_region")"

  IFS=',' read -r -a regions <<< "$DEPLOY_REGIONS"
  for region in "${regions[@]}"; do
    region="$(trim "$region")"
    [[ -z "$region" ]] && continue

    [[ -d "$live_account_dir/$region" ]] || cp -R "$live_account_dir/$template_live_region" "$live_account_dir/$region"
    [[ -d "$module_account_dir/$region" ]] || cp -R "$module_account_dir/$template_module_region" "$module_account_dir/$region"

    write_common_hcl "$region" "$live_account_dir/$region/common.hcl"

    mkdir -p "$live_account_dir/$region/standard" "$live_account_dir/$region/soc" "$live_account_dir/$region/dev"
    mkdir -p "$live_account_dir/$region/standard-pool" "$live_account_dir/$region/soc-pool" "$live_account_dir/$region/dev-pool"
    mkdir -p "$live_account_dir/$region/installs-bucket"

    write_personal_unit "$region" "standard" "$live_account_dir/$region/standard/terragrunt.hcl"
    write_personal_unit "$region" "soc" "$live_account_dir/$region/soc/terragrunt.hcl"
    write_personal_unit "$region" "dev" "$live_account_dir/$region/dev/terragrunt.hcl"

    write_pool_unit "$region" "standard" "$live_account_dir/$region/standard-pool/terragrunt.hcl" "Standard" "standard"
    write_pool_unit "$region" "soc" "$live_account_dir/$region/soc-pool/terragrunt.hcl" "SOC" "soc"
    write_pool_unit "$region" "dev" "$live_account_dir/$region/dev-pool/terragrunt.hcl" "Dev" "dev"

    write_installs_bucket_unit "$region" "$live_account_dir/$region/installs-bucket/terragrunt.hcl"
  done

  if [[ "${PRUNE_REGIONS,,}" == "true" ]]; then
    while IFS= read -r -d '' d; do
      region="$(basename "$d")"
      if ! csv_contains "$DEPLOY_REGIONS" "$region"; then
        rm -rf "$d"
      fi
    done < <(find "$live_account_dir" -mindepth 1 -maxdepth 1 -type d -print0)

    while IFS= read -r -d '' d; do
      region="$(basename "$d")"
      if ! csv_contains "$DEPLOY_REGIONS" "$region"; then
        rm -rf "$d"
      fi
    done < <(find "$module_account_dir" -mindepth 1 -maxdepth 1 -type d -print0)
  fi
}

write_config_file() {
  mkdir -p "$(dirname "$CONFIG_FILE")"
  cat > "$CONFIG_FILE" <<EOF_CFG
ORG_SLUG=$ORG_SLUG
ENVIRONMENT=$ENVIRONMENT
ACCOUNT_ID=$ACCOUNT_ID
PRIMARY_REGION=$PRIMARY_REGION
DEPLOY_REGIONS=$DEPLOY_REGIONS
NAME_PREFIX=$NAME_PREFIX
PROJECT_NAME=$PROJECT_NAME
OWNER_TAG=$OWNER_TAG
DEPARTMENT_TAG=$DEPARTMENT_TAG
COST_CENTER=$COST_CENTER
DATA_CLASS=$DATA_CLASS
CRITICALITY=$CRITICALITY
COMPLIANCE=$COMPLIANCE
BACKEND_BUCKET=$BACKEND_BUCKET
LOCK_TABLE=$LOCK_TABLE
KMS_ALIAS=$KMS_ALIAS
DIRECTORY_NAME=$DIRECTORY_NAME
DIRECTORY_ID=$DIRECTORY_ID
POOL_DIRECTORY_ID=$POOL_DIRECTORY_ID
WORKSPACES_SUBNET_1_CIDR=$WORKSPACES_SUBNET_1_CIDR
WORKSPACES_SUBNET_1_AZ=$WORKSPACES_SUBNET_1_AZ
WORKSPACES_SUBNET_1_AZ_ID=$WORKSPACES_SUBNET_1_AZ_ID
WORKSPACES_SUBNET_2_CIDR=$WORKSPACES_SUBNET_2_CIDR
WORKSPACES_SUBNET_2_AZ=$WORKSPACES_SUBNET_2_AZ
WORKSPACES_SUBNET_2_AZ_ID=$WORKSPACES_SUBNET_2_AZ_ID
TRUSTED_CIDRS=$TRUSTED_CIDRS
WORKSPACES_RUNNING_MODE=$WORKSPACES_RUNNING_MODE
WORKSPACES_AUTO_STOP_TIMEOUT=$WORKSPACES_AUTO_STOP_TIMEOUT
WORKSPACES_CREATE_TIMEOUT=$WORKSPACES_CREATE_TIMEOUT
STANDARD_BUNDLE=$STANDARD_BUNDLE
SOC_BUNDLE=$SOC_BUNDLE
DEV_BUNDLE=$DEV_BUNDLE
POOL_VPC_ID=$POOL_VPC_ID
POOL_SUBNET_IDS=$POOL_SUBNET_IDS
SAML_XML_SECRET_NAME=$SAML_XML_SECRET_NAME
PRUNE_REGIONS=$PRUNE_REGIONS
EOF_CFG
}

CONFIG_FILE="$DEFAULT_CONFIG"

OVR_ORG_SLUG=""
OVR_ENVIRONMENT=""
OVR_ACCOUNT_ID=""
OVR_PRIMARY_REGION=""
OVR_DEPLOY_REGIONS=""
OVR_NAME_PREFIX=""
OVR_PROJECT_NAME=""
OVR_OWNER_TAG=""
OVR_DEPARTMENT_TAG=""
OVR_BACKEND_BUCKET=""
OVR_LOCK_TABLE=""
OVR_KMS_ALIAS=""
OVR_DIRECTORY_NAME=""
OVR_DIRECTORY_ID=""
OVR_POOL_DIRECTORY_ID=""
OVR_POOL_VPC_ID=""
OVR_POOL_SUBNET_IDS=""
OVR_SAML_SECRET_NAME=""
OVR_PRUNE_REGIONS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --config) CONFIG_FILE="$2"; shift 2 ;;
    --org-slug) OVR_ORG_SLUG="$2"; shift 2 ;;
    --environment) OVR_ENVIRONMENT="$2"; shift 2 ;;
    --account-id) OVR_ACCOUNT_ID="$2"; shift 2 ;;
    --primary-region) OVR_PRIMARY_REGION="$2"; shift 2 ;;
    --regions) OVR_DEPLOY_REGIONS="$2"; shift 2 ;;
    --name-prefix) OVR_NAME_PREFIX="$2"; shift 2 ;;
    --project-name) OVR_PROJECT_NAME="$2"; shift 2 ;;
    --owner) OVR_OWNER_TAG="$2"; shift 2 ;;
    --department) OVR_DEPARTMENT_TAG="$2"; shift 2 ;;
    --backend-bucket) OVR_BACKEND_BUCKET="$2"; shift 2 ;;
    --lock-table) OVR_LOCK_TABLE="$2"; shift 2 ;;
    --kms-alias) OVR_KMS_ALIAS="$2"; shift 2 ;;
    --directory-name) OVR_DIRECTORY_NAME="$2"; shift 2 ;;
    --directory-id) OVR_DIRECTORY_ID="$2"; shift 2 ;;
    --pool-directory-id) OVR_POOL_DIRECTORY_ID="$2"; shift 2 ;;
    --pool-vpc-id) OVR_POOL_VPC_ID="$2"; shift 2 ;;
    --pool-subnet-ids) OVR_POOL_SUBNET_IDS="$2"; shift 2 ;;
    --saml-secret-name) OVR_SAML_SECRET_NAME="$2"; shift 2 ;;
    --prune-regions) OVR_PRUNE_REGIONS="$2"; shift 2 ;;
    --help|-h) usage; exit 0 ;;
    *) echo "ERROR: unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

if [[ ! -f "$CONFIG_FILE" ]]; then
  if [[ -f "$REPO_ROOT/config/deployment.env.example" ]]; then
    cp "$REPO_ROOT/config/deployment.env.example" "$CONFIG_FILE"
    echo "INFO: created $CONFIG_FILE from template"
  else
    echo "ERROR: config file not found: $CONFIG_FILE" >&2
    exit 1
  fi
fi

# shellcheck disable=SC1090
set -a
source "$CONFIG_FILE"
set +a

[[ -n "$OVR_ORG_SLUG" ]] && ORG_SLUG="$OVR_ORG_SLUG"
[[ -n "$OVR_ENVIRONMENT" ]] && ENVIRONMENT="$OVR_ENVIRONMENT"
[[ -n "$OVR_ACCOUNT_ID" ]] && ACCOUNT_ID="$OVR_ACCOUNT_ID"
[[ -n "$OVR_PRIMARY_REGION" ]] && PRIMARY_REGION="$OVR_PRIMARY_REGION"
[[ -n "$OVR_DEPLOY_REGIONS" ]] && DEPLOY_REGIONS="$OVR_DEPLOY_REGIONS"
[[ -n "$OVR_NAME_PREFIX" ]] && NAME_PREFIX="$OVR_NAME_PREFIX"
[[ -n "$OVR_PROJECT_NAME" ]] && PROJECT_NAME="$OVR_PROJECT_NAME"
[[ -n "$OVR_OWNER_TAG" ]] && OWNER_TAG="$OVR_OWNER_TAG"
[[ -n "$OVR_DEPARTMENT_TAG" ]] && DEPARTMENT_TAG="$OVR_DEPARTMENT_TAG"
[[ -n "$OVR_BACKEND_BUCKET" ]] && BACKEND_BUCKET="$OVR_BACKEND_BUCKET"
[[ -n "$OVR_LOCK_TABLE" ]] && LOCK_TABLE="$OVR_LOCK_TABLE"
[[ -n "$OVR_KMS_ALIAS" ]] && KMS_ALIAS="$OVR_KMS_ALIAS"
[[ -n "$OVR_DIRECTORY_NAME" ]] && DIRECTORY_NAME="$OVR_DIRECTORY_NAME"
[[ -n "$OVR_DIRECTORY_ID" ]] && DIRECTORY_ID="$OVR_DIRECTORY_ID"
[[ -n "$OVR_POOL_DIRECTORY_ID" ]] && POOL_DIRECTORY_ID="$OVR_POOL_DIRECTORY_ID"
[[ -n "$OVR_POOL_VPC_ID" ]] && POOL_VPC_ID="$OVR_POOL_VPC_ID"
[[ -n "$OVR_POOL_SUBNET_IDS" ]] && POOL_SUBNET_IDS="$OVR_POOL_SUBNET_IDS"
[[ -n "$OVR_SAML_SECRET_NAME" ]] && SAML_XML_SECRET_NAME="$OVR_SAML_SECRET_NAME"
[[ -n "$OVR_PRUNE_REGIONS" ]] && PRUNE_REGIONS="$OVR_PRUNE_REGIONS"

DEPLOY_REGIONS="$(normalize_csv "$DEPLOY_REGIONS")"
[[ -z "$DEPLOY_REGIONS" ]] && DEPLOY_REGIONS="$PRIMARY_REGION"

if ! csv_contains "$DEPLOY_REGIONS" "$PRIMARY_REGION"; then
  DEPLOY_REGIONS="$(normalize_csv "$DEPLOY_REGIONS,$PRIMARY_REGION")"
fi

if [[ ! "$ACCOUNT_ID" =~ ^[0-9]{12}$ ]]; then
  echo "ERROR: ACCOUNT_ID must be a 12-digit number." >&2
  exit 1
fi

[[ -n "${NAME_PREFIX:-}" ]] || NAME_PREFIX="$ORG_SLUG-workspaces-platform-$ENVIRONMENT"
[[ -n "${PROJECT_NAME:-}" ]] || PROJECT_NAME="$ORG_SLUG-workspaces-platform"
[[ -n "${BACKEND_BUCKET:-}" ]] || BACKEND_BUCKET="$ORG_SLUG-workspaces-terraform-state"
[[ -n "${LOCK_TABLE:-}" ]] || LOCK_TABLE="$NAME_PREFIX-terraform-locks"
[[ -n "${KMS_ALIAS:-}" ]] || KMS_ALIAS="alias/$NAME_PREFIX-terraform-state-01"

old_scope="$(find "$REPO_ROOT/live/aws" -mindepth 2 -maxdepth 2 -type d -name 'account-*' | head -n1 | xargs basename 2>/dev/null || true)"
old_account_id="${old_scope#account-}"
new_scope="account-$ACCOUNT_ID"

if [[ -n "$old_scope" && "$old_scope" != "$new_scope" ]]; then
  replace_literal "$old_scope" "$new_scope"
  replace_literal "$old_account_id" "$ACCOUNT_ID"
  rename_account_scope_dirs "$old_scope" "$new_scope"
fi

write_global_hcl
write_backend_tfvars
configure_workspaces_platform_stack
write_config_file

echo "Configuration complete."
echo "  Account:        $ACCOUNT_ID"
echo "  Primary region: $PRIMARY_REGION"
echo "  Regions:        $DEPLOY_REGIONS"
echo "  Name prefix:    $NAME_PREFIX"
echo "  Backend bucket: $BACKEND_BUCKET"
