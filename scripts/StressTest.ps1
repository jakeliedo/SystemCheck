param (
    [string]$ReportPath,
    [string]$LogPath
)

Write-Host "=========================================" -ForegroundColor Cyan
Write-Host " STRESS TEST CPU VA RAM" -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "Canh bao: Test nay se vat kiet CPU va RAM." -ForegroundColor Yellow
Write-Host "May co the bi do hoac tat ngum neu nguon (PSU) yeu hoac tan nhiet kem!" -ForegroundColor Yellow
Write-Host "Khuyen cao dong tat ca cac ung dung khac truoc khi tiep tuc." -ForegroundColor Yellow
Write-Host ""
$durationInput = Read-Host "Nhap thoi gian test (giay) [Mac dinh: 60]"
if ([string]::IsNullOrWhiteSpace($durationInput)) {
    $DurationSeconds = 60
} else {
    $DurationSeconds = [int]$durationInput
}

Write-Host ""
Write-Host "Dang chuan bi stress test CPU va RAM trong $DurationSeconds giay..." -ForegroundColor Cyan

# Start CPU stress
$cpuJobs = @()
$logicalCores = (Get-CimInstance Win32_ComputerSystem).NumberOfLogicalProcessors
if (!$logicalCores) { $logicalCores = [Environment]::ProcessorCount }

Write-Host "[*] Phat hien $logicalCores CPU threads. Bat dau stress CPU..."
for ($i = 0; $i -lt $logicalCores; $i++) {
    $job = Start-Job -ScriptBlock {
        $run = $true
        # Busy wait to max out CPU
        while ($run) {
            $math = [math]::Sqrt(9999999.99)
        }
    }
    $cpuJobs += $job
}

# Start RAM stress
Write-Host "[*] Bat dau stress RAM (tao object lon lien tuc de dung day RAM)..."
$ramJobs = Start-Job -ScriptBlock {
    $arrays = @()
    $run = $true
    while ($run) {
        try {
            # Allocate ~100MB chunks
            $arrays += New-Object byte[] (100 * 1024 * 1024)
            Start-Sleep -Milliseconds 200
        } catch {
            # Out of memory, just sleep
            Start-Sleep -Seconds 1
        }
    }
}

Write-Host ""
Write-Host "=========================================" -ForegroundColor Red
Write-Host " DANG CHAY STRESS TEST - AN CTRL+C DE DUNG" -ForegroundColor Red
Write-Host "=========================================" -ForegroundColor Red
$sw = [Diagnostics.Stopwatch]::StartNew()
while ($sw.Elapsed.TotalSeconds -lt $DurationSeconds) {
    Start-Sleep -Seconds 1
    $rem = [math]::Max(0, $DurationSeconds - $sw.Elapsed.TotalSeconds)
    Write-Progress -Activity "Stress Test Dang Chay" -Status "$([math]::Round($rem)) giay con lai" -PercentComplete (($sw.Elapsed.TotalSeconds / $DurationSeconds) * 100)
}
Write-Progress -Activity "Stress Test Dang Chay" -Completed

Write-Host "Dang dung stress test va giai phong tai nguyen..." -ForegroundColor Cyan
$cpuJobs | Stop-Job
$cpuJobs | Remove-Job
Stop-Job $ramJobs
Remove-Job $ramJobs

[GC]::Collect()

Write-Host "Stress test hoan thanh an toan!" -ForegroundColor Green

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Stress Test Report</title>
<style>
    body { font-family: Arial, sans-serif; background: #121212; color: #e0e0e0; margin: 20px; line-height: 1.6; }
    h1 { color: #ff5555; }
    .card { background: #1e1e1e; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 5px solid #ff5555; }
    .success { border-left: 5px solid #50fa7b; }
    strong { color: #fff; }
</style>
</head>
<body>
    <h1>Báo Cáo Stress Test</h1>
    <div class="card success">
        <h3>✅ Hoàn thành kiểm tra</h3>
        <p>Hệ thống đã vượt qua bài test stress <strong>$DurationSeconds giây</strong> (vắt kiệt CPU & RAM) mà không bị tắt nguồn hay màn hình xanh.</p>
        <p><strong>Số luồng CPU đã test:</strong> $logicalCores</p>
    </div>
    <div class="card">
        <h3>💡 Phân tích kết quả</h3>
        <p>Nếu máy tính của bạn thường xuyên bị sập/tắt ngang khi chơi game hoặc render, nhưng lại <strong>VƯỢT QUA</strong> bài test này, nguyên nhân có thể do lỗi <strong>GPU (card đồ họa)</strong> hoặc Driver thay vì CPU/RAM/Nguồn.</p>
        <p>Nếu máy tính từng bị sập TRONG LÚC đang chạy test này: Khả năng rất cao <strong>Bộ nguồn (PSU)</strong> của bạn đã bị yếu, quá tải hoặc <strong>CPU bị quá nhiệt</strong> cục bộ dẫn đến tự ngắt để bảo vệ hệ thống.</p>
    </div>
</body>
</html>
"@

if ($ReportPath) {
    $html | Out-File -FilePath $ReportPath -Encoding utf8
}
if ($LogPath) {
    "Stress test hoan thanh an toan sau $DurationSeconds giay." | Out-File -FilePath $LogPath -Encoding utf8
}
