param(
  [string]$ServerHost = "10.139.76.17",
  [string]$User = "root",
  [int]$Port = 22,
  [string]$RemoteDir = "/root/my-project-deploy",
  [string]$KeyPath = "$env:USERPROFILE\.ssh\my-project-deploy",
  [string]$KnownHostsPath = "$env:USERPROFILE\.ssh\known_hosts",
  [switch]$DryRun,
  [switch]$SkipRebuild
)

$ErrorActionPreference = "Stop"

function Get-RclonePath {
  $cmd = Get-Command rclone -ErrorAction SilentlyContinue
  if ($cmd) {
    return $cmd.Source
  }

  $wingetRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
  $match = Get-ChildItem $wingetRoot -Recurse -Filter rclone.exe -ErrorAction SilentlyContinue |
    Select-Object -First 1 -ExpandProperty FullName

  if ($match) {
    return $match
  }

  throw "rclone.exe not found. Install Rclone first."
}

function Get-SshPath {
  $cmd = Get-Command ssh -ErrorAction Stop
  return $cmd.Source
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$excludeFile = Join-Path $repoRoot ".deployignore"

if (-not (Test-Path $excludeFile)) {
  throw ".deployignore not found at $excludeFile"
}

if (-not (Test-Path $KeyPath)) {
  throw "SSH private key not found at $KeyPath"
}

if (-not (Test-Path $KnownHostsPath)) {
  throw "known_hosts not found at $KnownHostsPath"
}

$rclone = Get-RclonePath
$ssh = Get-SshPath
$remoteTarget = ":sftp:$RemoteDir"

$syncArgs = @(
  "sync",
  $repoRoot,
  $remoteTarget,
  "--sftp-host", $ServerHost,
  "--sftp-user", $User,
  "--sftp-port", $Port,
  "--sftp-key-file", $KeyPath,
  "--sftp-known-hosts-file", $KnownHostsPath,
  "--exclude-from", $excludeFile,
  "--create-empty-src-dirs",
  "--transfers", "8",
  "--checkers", "16",
  "--stats-one-line",
  "--stats", "2s"
)

if ($DryRun) {
  $syncArgs += "--dry-run"
}

Write-Host "Syncing $repoRoot -> $User@${ServerHost}:$RemoteDir" -ForegroundColor Cyan
& $rclone @syncArgs
if ($LASTEXITCODE -ne 0) {
  throw "rclone sync failed with exit code $LASTEXITCODE"
}

if ($DryRun) {
  Write-Host "Dry run complete. Remote rebuild skipped." -ForegroundColor Yellow
  exit 0
}

$remoteCommand = "set -e; mkdir -p '$RemoteDir'; cd '$RemoteDir'; rm -f deploy-package.tar.gz; docker compose up -d --build --remove-orphans; docker compose ps"

if ($SkipRebuild) {
  Write-Host "Sync complete. Remote rebuild skipped." -ForegroundColor Yellow
  exit 0
}

Write-Host "Rebuilding containers on $ServerHost" -ForegroundColor Cyan
& $ssh `
  -i $KeyPath `
  -o BatchMode=yes `
  -o StrictHostKeyChecking=yes `
  -p $Port `
  "$User@$ServerHost" `
  $remoteCommand

if ($LASTEXITCODE -ne 0) {
  throw "Remote docker compose failed with exit code $LASTEXITCODE"
}

Write-Host "Deploy finished." -ForegroundColor Green
