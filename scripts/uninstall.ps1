# scripts/uninstall.ps1
$ErrorActionPreference = "Stop"

$AppName = $env:APP_NAME
$SpecificFile = $env:SPECIFIC_FILE

if ([string]::IsNullOrWhiteSpace($AppName)) {
    Write-Host "❌ Lỗi: Cần cung cấp tên app để gỡ." -ForegroundColor Red
    exit
}

$Target = "windows-amd64"
$BaseUrl = "https://yellowbox.itblognote.com/bin"
$ManifestUrl = "$BaseUrl/manifest.json"

try {
    $Manifest = Invoke-RestMethod -Uri $ManifestUrl
} catch { exit }

$Tool = $Manifest.tools | Where-Object { $_.name -eq $AppName }
if ($null -eq $Tool) { exit }

$Files = $Tool.platforms."$Target"
if ($null -eq $Files) { exit }

if (-not [string]::IsNullOrWhiteSpace($SpecificFile)) {
    if ($Files -contains $SpecificFile) { $Files = @($SpecificFile) }
}

$InstallDir = "$env:USERPROFILE\.local\bin"
Write-Host "🧹 Đang gỡ cài đặt $AppName..." -ForegroundColor Cyan
$RemovedCount = 0

foreach ($File in $Files) {
    $DestPath = Join-Path $InstallDir $File
    if (Test-Path -Path $DestPath) {
        Remove-Item -Path $DestPath -Force
        Write-Host "   🗑️ Đã xóa: $File"
        $RemovedCount++
    }
}

if ($RemovedCount -eq 0) {
    Write-Host "⚠️ Không tìm thấy file nào để xóa." -ForegroundColor Yellow
} else {
    Write-Host "✅ Gỡ cài đặt hoàn tất!" -ForegroundColor Green
}

[Environment]::SetEnvironmentVariable("APP_NAME", $null, "Process")
[Environment]::SetEnvironmentVariable("SPECIFIC_FILE", $null, "Process")