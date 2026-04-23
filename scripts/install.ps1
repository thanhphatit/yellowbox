# scripts/install.ps1
$ErrorActionPreference = "Stop"

$AppName = $env:APP_NAME
$SpecificFile = $env:SPECIFIC_FILE

if ([string]::IsNullOrWhiteSpace($AppName)) {
    Write-Host "❌ Lỗi: Cần cung cấp tên app." -ForegroundColor Red
    Write-Host "Cách dùng: `$env:APP_NAME='<tên_app>'; irm https://yellowbox.itblognote.com/scripts/install.ps1 | iex" -ForegroundColor Yellow
    exit
}

$Target = "windows-amd64" # Mặc định cho Windows 64-bit
$BaseUrl = "https://yellowbox.itblognote.com/bin"
$ManifestUrl = "$BaseUrl/manifest.json"

Write-Host "🔍 Đang tải thông tin manifest..." -ForegroundColor Cyan
try {
    $Manifest = Invoke-RestMethod -Uri $ManifestUrl
} catch {
    Write-Host "❌ Lỗi: Không thể tải manifest.json" -ForegroundColor Red
    exit
}

# Tìm tool trong manifest
$Tool = $Manifest.tools | Where-Object { $_.name -eq $AppName }
if ($null -eq $Tool) {
    Write-Host "❌ Không tìm thấy tool '$AppName' trong repository." -ForegroundColor Red
    exit
}

$Files = $Tool.platforms."$Target"
if ($null -eq $Files -or $Files.Count -eq 0) {
    Write-Host "❌ Tool '$AppName' chưa hỗ trợ nền tảng $Target." -ForegroundColor Red
    exit
}

# Lọc file lẻ nếu có yêu cầu
if (-not [string]::IsNullOrWhiteSpace($SpecificFile)) {
    if ($Files -contains $SpecificFile) {
        $Files = @($SpecificFile)
    } else {
        Write-Host "❌ Không tìm thấy file '$SpecificFile' trong bộ công cụ." -ForegroundColor Red
        exit
    }
}

# Tạo thư mục cài đặt nội bộ
$InstallDir = "$env:USERPROFILE\.local\bin"
if (-not (Test-Path -Path $InstallDir)) {
    New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
}

Write-Host "📦 Đang cài đặt '$AppName' vào $InstallDir..." -ForegroundColor Cyan

foreach ($File in $Files) {
    $DownloadUrl = "$BaseUrl/$AppName/$Target/$File"
    $DestPath = Join-Path $InstallDir $File
    Write-Host "⏬ Đang tải $File..."
    Invoke-WebRequest -Uri $DownloadUrl -OutFile $DestPath
}

Write-Host "✅ Hoàn tất cài đặt!" -ForegroundColor Green

# Kiểm tra xem thư mục đã có trong PATH chưa
$Paths = [Environment]::GetEnvironmentVariable("PATH", "User") -split ";"
if ($Paths -notcontains $InstallDir) {
    Write-Host "`n⚠️ LƯU Ý QUAN TRỌNG:" -ForegroundColor Yellow
    Write-Host "Thư mục $InstallDir chưa có trong biến môi trường PATH."
    Write-Host "Vui lòng mở Start Menu -> 'Edit the system environment variables' -> Thêm $InstallDir vào PATH để có thể chạy lệnh từ bất cứ đâu." -ForegroundColor White
}

# Xóa biến môi trường sau khi cài xong để dọn dẹp
[Environment]::SetEnvironmentVariable("APP_NAME", $null, "Process")
[Environment]::SetEnvironmentVariable("SPECIFIC_FILE", $null, "Process")