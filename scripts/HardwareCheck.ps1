param (
    [string]$ReportPath,
    [string]$LogPath
)

Write-Host "Dang thu thap thong tin phan cung toi da..." -ForegroundColor Cyan

$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
$ram = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property Capacity -Sum
$ramGB = [math]::Round($ram.Sum / 1GB, 2)
$gpu = Get-CimInstance Win32_VideoController | Select-Object -First 1

$html = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Hardware Check Report</title>
<style>
    body { font-family: Arial, sans-serif; background: #121212; color: #e0e0e0; margin: 20px; line-height: 1.6; }
    h1 { color: #bd93f9; }
    .card { background: #1e1e1e; padding: 15px; border-radius: 8px; margin-bottom: 15px; border-left: 5px solid #bd93f9; }
</style>
</head>
<body>
    <h1>Báo Cáo Phần Cứng (Chỉ Đọc)</h1>
    <div class="card">
        <h3>Thông số cơ bản</h3>
        <ul>
            <li><strong>CPU:</strong> $($cpu.Name)</li>
            <li><strong>RAM:</strong> $ramGB GB</li>
            <li><strong>GPU:</strong> $($gpu.Name)</li>
        </ul>
        <p>Ghi chú: Đây là chức năng đọc thông tin phần cứng. Để kiểm tra độ ổn định, vui lòng chọn tính năng Stress Test CPU/RAM.</p>
    </div>
</body>
</html>
"@

if ($ReportPath) {
    $html | Out-File -FilePath $ReportPath -Encoding utf8
}
if ($LogPath) {
    "Thu thap phan cung hoan thanh." | Out-File -FilePath $LogPath -Encoding utf8
}
Write-Host "Hoan thanh thu thap thong tin!" -ForegroundColor Green
