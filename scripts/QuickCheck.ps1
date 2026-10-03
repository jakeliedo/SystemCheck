param([int]$DaysBack = 7)
$start = (Get-Date).AddDays(-$DaysBack)
Write-Host ""
Write-Host "  [HE THONG]" -ForegroundColor Cyan
$os = Get-CimInstance Win32_OperatingSystem
Write-Host "  May tinh : $env:COMPUTERNAME"
Write-Host "  OS       : $($os.Caption)"
Write-Host "  Boot cuoi: $($os.LastBootUpTime.ToString('dd/MM/yyyy HH:mm:ss'))"
$up = (Get-Date) - $os.LastBootUpTime
Write-Host "  Uptime   : $($up.Days)d $($up.Hours)h $($up.Minutes)m"
Write-Host ""
Write-Host "  [TAT MAY - $DaysBack ngay]" -ForegroundColor Cyan
try { $e41   = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='Microsoft-Windows-Kernel-Power';Id=41;StartTime=$start} -EA Stop).Count } catch { $e41=0 }
try { $e6008 = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='EventLog';Id=6008;StartTime=$start} -EA Stop).Count } catch { $e6008=0 }
try { $e6006 = @(Get-WinEvent -FilterHashtable @{LogName='System';ProviderName='EventLog';Id=6006;StartTime=$start} -EA Stop).Count } catch { $e6006=0 }
if ($e41   -gt 0) { Write-Host "  TAT DOT NGOT (ID 41) : $e41 LAN! <- NGUYEN NHAN CHINH" -ForegroundColor Red }
else              { Write-Host "  Tat dot ngot (ID 41) : Khong co" -ForegroundColor Green }
if ($e6008 -gt 0) { Write-Host "  DIRTY SHUTDOWN(6008) : $e6008 LAN!" -ForegroundColor Yellow }
else              { Write-Host "  Dirty Shutdown (6008): Khong co" -ForegroundColor Green }
Write-Host "  Tat binh thuong(6006): $e6006 lan" -ForegroundColor Gray
Write-Host ""
Write-Host "  [BSOD]" -ForegroundColor Cyan
$dp = 0
if (Test-Path "$env:SystemRoot\Minidump") {
    $dp = @(Get-ChildItem "$env:SystemRoot\Minidump" -Filter "*.dmp" -EA SilentlyContinue | Where-Object { $_.LastWriteTime -gt $start }).Count
}
if ($dp -gt 0) { Write-Host "  MINIDUMP: $dp FILE! <- CO BSOD" -ForegroundColor Red }
else           { Write-Host "  Minidump : Khong co" -ForegroundColor Green }
Write-Host ""
Write-Host "  [O DIA]" -ForegroundColor Cyan
Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } | ForEach-Object {
    $pct  = [math]::Round($_.Used/($_.Used+$_.Free)*100,1)
    $free = [math]::Round($_.Free/1GB,1)
    $col  = if($pct-gt 90){"Red"}elseif($pct-gt 75){"Yellow"}else{"Green"}
    Write-Host "  O $($_.Name): $free GB trong  ($pct% da dung)" -ForegroundColor $col
}
Write-Host ""
if ($e41-gt 0 -or $dp-gt 0) {
    Write-Host "  KET LUAN: CO VAN DE! Chay SystemCheck.bat de xem bao cao HTML." -ForegroundColor Red
} else {
    Write-Host "  KET LUAN: Khong phat hien van de ro rang." -ForegroundColor Green
}
Write-Host ""