param()
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Format all Terragrunt files under the repo root.
# Terragrunt v0.56+ uses `terragrunt hcl fmt` for formatting.
terragrunt hcl fmt --working-dir $repoRoot
