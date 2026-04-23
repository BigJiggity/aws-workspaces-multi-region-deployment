$ErrorActionPreference = "Stop"
$region = "us-east-1"

$userName = Read-Host "Enter AD username to clean up (e.g., ALAY)"
if ([string]::IsNullOrWhiteSpace($userName)) {
  Write-Error "username is required"
}

Write-Host "Listing WorkSpaces for user '$userName' in $region..."
try {
  aws workspaces describe-workspaces --region $region --query "Workspaces[?UserName=='$userName']" --output table
} catch { }

$wsIds = aws workspaces describe-workspaces --region $region --query "Workspaces[?UserName=='$userName' && State=='ERROR'].WorkspaceId" --output text
if (-not $wsIds) {
  Write-Host "No errored WorkSpaces found for user '$userName'."
  exit 0
}

Write-Host "Terminating errored WorkSpaces for user '$userName': $wsIds"
$wsIds -split '\s+' | ForEach-Object {
  $req = @(@{ WorkspaceId = $_ }) | ConvertTo-Json -Compress
  aws workspaces terminate-workspaces --region $region --terminate-workspace-requests $req
}

Write-Host "Cleanup complete."
