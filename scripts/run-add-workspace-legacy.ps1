param()
$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$commonHcl = Join-Path $repoRoot "live\aws\aws-workspaces-platform\account-111122223333\us-east-1\common.hcl"

# -----------------------------------------------------------------------------
# Helper to remove any newly added entry on failure (keeps file clean).
# -----------------------------------------------------------------------------
function Cleanup-On-Failure {
  param(
    [string]$Message,
    [string]$UnitDir,
    [string]$TerragruntFile,
    [string]$UserName,
    [string]$BundleId
  )
  Write-Warning "CLEANUP: $Message"

  if (Test-Path $TerragruntFile) {
    $contents = Get-Content $TerragruntFile -Raw
    # Remove any entry that matches the user/bundle.
    $pattern = "(?ms)\\s*\\{\\s*name_suffix\\s*=\\s*\\\"[^\\\"]+\\\"\\s*user_name\\s*=\\s*\\\"$UserName\\\"\\s*bundle_id\\s*=\\s*\\\"$BundleId\\\"\\s*\\},?\\s*"
    $contents = $contents -replace $pattern, ""
    Set-Content -Path $TerragruntFile -Value $contents
  }
}

Write-Host "Select deployment type:" -ForegroundColor Cyan
Write-Host "  1) personal workspace"
Write-Host "  2) workspace pool"
$deploymentChoice = Read-Host "Enter choice (1-2)"

Write-Host "Select bundle tier:" -ForegroundColor Cyan
Write-Host "  1) standard"
Write-Host "  2) soc"
Write-Host "  3) dev"
$tierChoice = Read-Host "Enter choice (1-3)"

switch ($tierChoice) {
  '1' { $tier = 'standard' }
  '2' { $tier = 'soc' }
  '3' { $tier = 'dev' }
  Default { Write-Error "invalid choice"; exit 1 }
}

if ($deploymentChoice -eq '2') {
  $poolUnitDir = Join-Path $repoRoot "live\aws\aws-workspaces-platform\account-111122223333\us-east-1\$tier-pool"
  $poolTerragrunt = Join-Path $poolUnitDir "terragrunt.hcl"
  if (-not (Test-Path $poolTerragrunt)) {
    Write-Error "pool terragrunt.hcl not found at $poolTerragrunt"
    exit 1
  }
  Push-Location $poolUnitDir
  terragrunt init
  terragrunt plan
  terragrunt apply
  Pop-Location
  exit 0
}

if ($deploymentChoice -ne '1') {
  Write-Error "invalid deployment choice"
  exit 1
}

# -----------------------------------------------------------------------------
# Input collection for personal workspace deployment
# -----------------------------------------------------------------------------
$userName = Read-Host "Enter AD username (e.g., ALAY)"
if ([string]::IsNullOrWhiteSpace($userName)) {
  Write-Error "username is required"
  exit 1
}

# Personal workspace deployments need a concrete bundle ID.
if (Test-Path $commonHcl) {
  $lines = Get-Content $commonHcl
  $inBlock = $false
  foreach ($line in $lines) {
    if ($line -match 'default_bundles\s*=\s*{') { $inBlock = $true; continue }
    if ($inBlock -and $line -match '^\s*}') { $inBlock = $false; continue }
    if ($inBlock -and $line -match "^\s*$tier\s*=\s*\"([^\"]*)\"") {
      $bundleId = $Matches[1]
      # Strip inline comments if present.
      $bundleId = ($bundleId -split '\s*#')[0]
      $bundleId = ($bundleId -split '\s*//')[0]
      $bundleId = $bundleId.Trim()
      break
    }
  }
}

if ([string]::IsNullOrWhiteSpace($bundleId)) {
  $bundleId = Read-Host "Enter bundle ID for $tier"
  if ([string]::IsNullOrWhiteSpace($bundleId)) {
    Write-Error "bundle ID is required"
    exit 1
  }
}

# -----------------------------------------------------------------------------
# File update (insert WorkSpaces entry in the selected tier)
# -----------------------------------------------------------------------------
$unitDir = Join-Path $repoRoot "live\aws\aws-workspaces-platform\account-111122223333\us-east-1\$tier"
$terragruntFile = Join-Path $unitDir "terragrunt.hcl"

if (-not (Test-Path $terragruntFile)) {
  Write-Error "terragrunt.hcl not found at $terragruntFile"
  exit 1
}

if ((Get-Content $terragruntFile -Raw) -match "user_name\s+=\s+\"$userName\"") {
  $replace = Read-Host "User '$userName' already exists in $tier tier. Remove and replace? (y/n)"
  if ($replace -ne 'y') {
    Write-Error "user '$userName' already exists in $tier tier."
    exit 1
  }
  # Remove existing entries for this user before adding a new one.
  $contents = Get-Content $terragruntFile -Raw
  $contents = $contents -replace "(?ms)\\s*\\{\\s*[^}]*user_name\\s*=\\s*\\\"$UserName\\\"[^}]*\\},?\\s*", ""
  Set-Content -Path $terragruntFile -Value $contents
}

$nameSuffix = "$tier-$bundleId"
$entry = @"
    {
      name_suffix = \"$nameSuffix\"
      user_name   = \"$userName\"
      bundle_id   = \"$bundleId\"
    },
"@

$contents = Get-Content $terragruntFile -Raw
if ($contents -notmatch 'WORKSPACES_ENTRIES_END') {
  # Insert marker before closing bracket if missing.
  $contents = $contents -replace '\n\s*\]\s*\n', "`n    # WORKSPACES_ENTRIES_END`n  ]`n"
}

$updated = $contents -replace '([\s\S]*?)WORKSPACES_ENTRIES_END', "`$1$entry    # WORKSPACES_ENTRIES_END"
Set-Content -Path $terragruntFile -Value $updated

# -----------------------------------------------------------------------------
# Execute Terragrunt and handle errors with cleanup + diagnostics.
# -----------------------------------------------------------------------------
Push-Location $unitDir
try {
  terragrunt init
} catch {
  Cleanup-On-Failure -Message "init failed" -UnitDir $unitDir -TerragruntFile $terragruntFile -UserName $userName -BundleId $bundleId
  throw
}

try {
  terragrunt plan
} catch {
  Cleanup-On-Failure -Message "plan failed" -UnitDir $unitDir -TerragruntFile $terragruntFile -UserName $userName -BundleId $bundleId
  throw
}

try {
  terragrunt apply
} catch {
  Cleanup-On-Failure -Message "apply failed" -UnitDir $unitDir -TerragruntFile $terragruntFile -UserName $userName -BundleId $bundleId
  Write-Host "DIAGNOSTICS: fetching WorkSpaces status for user '$userName'..." -ForegroundColor Yellow
  try {
    aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='$userName']" --output json
  } catch { }

  try {
    $wsIds = aws workspaces describe-workspaces --region us-east-1 --query "Workspaces[?UserName=='$userName' && State=='ERROR'].WorkspaceId" --output text
    if ($wsIds) {
      Write-Warning "CLEANUP: terminating errored WorkSpaces for user '$userName': $wsIds"
      $wsIds -split '\s+' | ForEach-Object {
        $req = @(@{ WorkspaceId = $_ }) | ConvertTo-Json -Compress
        aws workspaces terminate-workspaces --region us-east-1 --terminate-workspace-requests $req
      }
    }
  } catch { }
  throw
}
Pop-Location
