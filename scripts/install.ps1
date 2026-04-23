# scripts/install.ps1
$ErrorActionPreference = "Stop"

$AppName = $env:APP_NAME
$SpecificFile = $env:SPECIFIC_FILE

if ([string]::IsNullOrWhiteSpace($AppName)) {
    Write-Host "❌ Error: App name is required." -ForegroundColor Red
    Write-Host "Usage: `$env:APP_NAME='<app_name>'; irm https://yellowbox.itblognote.com/scripts/install.ps1 | iex" -ForegroundColor Yellow
    exit
}

$Target = "windows-amd64" # Default to Windows 64-bit
$BaseUrl = "https://yellowbox.itblognote.com/bin"
$ManifestUrl = "$BaseUrl/manifest.json"

Write-Host "🔍 Fetching manifest info..." -ForegroundColor Cyan
try {
    $Manifest = Invoke-RestMethod -Uri $ManifestUrl
} catch {
    Write-Host "❌ Error: Failed to download manifest.json" -ForegroundColor Red
    exit
}

# Find tool in manifest
$Tool = $Manifest.tools | Where-Object { $_.name -eq $AppName }
if ($null -eq $Tool) {
    Write-Host "❌ Tool '$AppName' not found in the repository." -ForegroundColor Red
    exit
}

$Files = $Tool.platforms."$Target"
if ($null -eq $Files -or $Files.Count -eq 0) {
    Write-Host "❌ Tool '$AppName' does not support the $Target platform yet." -ForegroundColor Red
    exit
}

# Filter specific file if requested
if (-not [string]::IsNullOrWhiteSpace($SpecificFile)) {
    if ($Files -contains $SpecificFile) {
        $Files = @($SpecificFile)
    } else {
        Write-Host "❌ File '$SpecificFile' not found in the tool suite." -ForegroundColor Red
        exit
    }
}

# Create local installation directory
$InstallDir = "$env:USERPROFILE\.local\bin"
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

Write-Host "📦 Installing '$AppName' to $InstallDir..." -ForegroundColor Cyan

foreach ($File in $Files) {
    $DownloadUrl = "$BaseUrl/$AppName/$Target/$File"
    $DestPath = Join-Path $InstallDir $File
    Write-Host "⏬ Downloading $File..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestPath
}

Write-Host "✅ Installation complete!" -ForegroundColor Green

# Check if the directory is already in PATH
$Paths = [Environment]::GetEnvironmentVariable("PATH", "User") -split ";"
if ($Paths -notcontains $InstallDir) {
    Write-Host "`n⚠️ IMPORTANT NOTE:" -ForegroundColor Yellow
    Write-Host "The directory $InstallDir is not in your PATH environment variable."
    Write-Host "Please open Start Menu -> 'Edit the system environment variables' -> Add $InstallDir to your PATH to run the command from anywhere." -ForegroundColor White
}

# Clear environment variables after installation to clean up
[Environment]::SetEnvironmentVariable("APP_NAME", $null, "Process")
[Environment]::SetEnvironmentVariable("SPECIFIC_FILE", $null, "Process")