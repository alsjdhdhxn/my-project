param(
  [string]$JdbcUrl = "jdbc:oracle:thin:@//192.168.11.5:1521/orcl",
  [string]$Username = "cmx",
  [string]$Password = "cmx",
  [string]$OutputDir = (Join-Path (Split-Path (Get-Location).Path -Parent) "sql20260523")
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$serverDir = Join-Path $repoRoot "cost-server"
$tmpDir = Join-Path $repoRoot ".codex-tmp\oracle-export"
New-Item -ItemType Directory -Force -Path $tmpDir | Out-Null
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$classpathFile = Join-Path $tmpDir "classpath.txt"
Push-Location $serverDir
try {
  & .\mvnw.cmd -q dependency:build-classpath "-Dmdep.outputFile=$classpathFile"
  if ($LASTEXITCODE -ne 0) { throw "mvn dependency:build-classpath failed with exit code $LASTEXITCODE" }
}
finally {
  Pop-Location
}

$classpath = Get-Content -Raw -Path $classpathFile
$sourceFile = Join-Path $repoRoot "scripts\OracleSqlExporter.java"
javac -encoding UTF-8 -cp $classpath -d $tmpDir $sourceFile
if ($LASTEXITCODE -ne 0) { throw "javac failed with exit code $LASTEXITCODE" }
java -cp "$tmpDir;$classpath" OracleSqlExporter $JdbcUrl $Username $Password $OutputDir
if ($LASTEXITCODE -ne 0) { throw "OracleSqlExporter failed with exit code $LASTEXITCODE" }

Write-Host "Export completed: $OutputDir"
