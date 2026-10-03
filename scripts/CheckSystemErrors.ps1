# ============================================================
#  CheckSystemErrors.ps1
#  Quet va phan tich cac loi he thong Windows
#  Phat hien nguyen nhan may tinh tu dong tat/khoi dong lai
#  Encoding: UTF-8 with BOM (saved by script)
# ============================================================

param(
    [string]$ReportPath = "reports\SystemReport.html",
    [string]$LogPath    = "logs\SystemLog.txt"
)

# Force UTF-8 output
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8

# =========================================================
# CAC EVENT ID QUAN TRONG
# =========================================================
$DaysBack  = 7
$StartTime = (Get-Date).AddDays(-$DaysBack)

Write-Host ""
Write-Host "  [*] Bat dau quet Event Log..." -ForegroundColor Cyan

# =========================================================
# HAM TIEN ICH
# =========================================================
function Write-Step {
    param([string]$Message, [string]$Status = "INFO")
    $colors = @{ INFO="Cyan"; OK="Green"; WARN="Yellow"; ERROR="Red" }
    $icons  = @{ INFO="[*]"; OK="[+]"; WARN="[!]"; ERROR="[X]" }
    Write-Host ("  " + $icons[$Status] + " " + $Message) -ForegroundColor $colors[$Status]
}

function Get-EventSafe {
    param([string]$LogName, [hashtable]$Filter)
    try {
        $Filter["LogName"] = $LogName
        return @(Get-WinEvent -FilterHashtable $Filter -ErrorAction Stop)
    } catch {
        return @()
    }
}

function Escape-Html {
    param([string]$Text)
    return $Text `
        -replace '&','&amp;' `
        -replace '<','&lt;' `
        -replace '>','&gt;' `
        -replace '"','&quot;'
}

# =========================================================
# 1. THONG TIN HE THONG
# =========================================================
Write-Step "Thu thap thong tin he thong..."

$ComputerName = $env:COMPUTERNAME
$OSInfo       = Get-CimInstance Win32_OperatingSystem
$CPU          = (Get-CimInstance Win32_Processor | Select-Object -First 1).Name
$RAM_GB       = [math]::Round($OSInfo.TotalVisibleMemorySize / 1MB, 2)
$OSVersion    = "$($OSInfo.Caption) (Build $($OSInfo.BuildNumber))"
$LastBoot     = $OSInfo.LastBootUpTime
$Uptime       = (Get-Date) - $LastBoot
$UptimeStr    = ("{0}d {1}h {2}m" -f $Uptime.Days, $Uptime.Hours, $Uptime.Minutes)

$Drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null } |
    Select-Object Name,
        @{N="Total_GB"; E={[math]::Round(($_.Used + $_.Free)/1GB, 1)}},
        @{N="Free_GB";  E={[math]::Round($_.Free/1GB, 1)}},
        @{N="Used_Pct"; E={[math]::Round($_.Used/($_.Used+$_.Free)*100, 1)}}

Write-Step "He thong: $ComputerName | OS: $OSVersion" "OK"
Write-Step ("Boot cuoi: " + $LastBoot.ToString('dd/MM/yyyy HH:mm:ss') + " (Uptime: $UptimeStr)") "OK"

# =========================================================
# 2. SU KIEN TAT MAY
# =========================================================
Write-Step "Tim su kien tat/khoi dong bat thuong..."

$UnexpectedShutdowns = Get-EventSafe "System" @{
    ProviderName = "Microsoft-Windows-Kernel-Power"
    Id           = 41
    StartTime    = $StartTime
}
$DirtyShutdowns = Get-EventSafe "System" @{
    ProviderName = "EventLog"
    Id           = 6008
    StartTime    = $StartTime
}
$CleanShutdowns = Get-EventSafe "System" @{
    ProviderName = "EventLog"
    Id           = 6006
    StartTime    = $StartTime
}
$SystemStarts = Get-EventSafe "System" @{
    ProviderName = "EventLog"
    Id           = 6005
    StartTime    = $StartTime
}
$AppShutdowns = Get-EventSafe "System" @{
    ProviderName = "USER32"
    Id           = 1074
    StartTime    = $StartTime
}

$warnColor = if ($UnexpectedShutdowns.Count -gt 0) { "WARN" } else { "OK" }
Write-Step ("Tat bat thuong (ID 41) : " + $UnexpectedShutdowns.Count + " su kien") $warnColor
$warnColor2 = if ($DirtyShutdowns.Count -gt 0) { "WARN" } else { "OK" }
Write-Step ("Dirty shutdown (ID 6008): " + $DirtyShutdowns.Count + " su kien") $warnColor2
Write-Step ("Tat binh thuong (ID 6006): " + $CleanShutdowns.Count + " su kien") "OK"

# =========================================================
# 3. BSOD / MINIDUMP
# =========================================================
Write-Step "Tim crash dump (BSOD)..."

$CrashDumpPath = "$env:SystemRoot\Minidump"
$MinidumpFiles = @()
if (Test-Path $CrashDumpPath) {
    $MinidumpFiles = @(Get-ChildItem $CrashDumpPath -Filter "*.dmp" -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -gt $StartTime } |
        Sort-Object LastWriteTime -Descending)
}

$BSODEvents = Get-EventSafe "System" @{
    ProviderName = "Microsoft-Windows-WER-SystemErrorReporting"
    Id           = 1001
    StartTime    = $StartTime
}

$dumpStatus = if (($MinidumpFiles.Count + $BSODEvents.Count) -gt 0) { "ERROR" } else { "OK" }
Write-Step ("Minidump files : " + $MinidumpFiles.Count) $dumpStatus
Write-Step ("BSOD Events    : " + $BSODEvents.Count)    $dumpStatus

# =========================================================
# 4. LOI O CUNG
# =========================================================
Write-Step "Kiem tra loi o cung (Disk I/O)..."

$DiskErrors = Get-EventSafe "System" @{
    ProviderName = "disk"
    StartTime    = $StartTime
} | Where-Object { $_.Id -in @(7,9,11,15,51) }

$NTFSErrors = Get-EventSafe "System" @{
    ProviderName = "Ntfs"
    StartTime    = $StartTime
} | Where-Object { $_.Id -in @(55,50,137,140) }

$diskStatus  = if ($DiskErrors.Count -gt 0) { "ERROR" } else { "OK" }
$ntfsStatus  = if ($NTFSErrors.Count -gt 0) { "WARN" } else { "OK" }
Write-Step ("Loi Disk I/O: " + $DiskErrors.Count + " su kien") $diskStatus
Write-Step ("Loi NTFS    : " + $NTFSErrors.Count + " su kien") $ntfsStatus

# =========================================================
# 5. SU KIEN CRITICAL VA ERROR TREN SYSTEM LOG
# =========================================================
Write-Step "Thu thap loi Critical/Error tu System log..."

$SystemCritical = Get-EventSafe "System" @{
    Level     = @(1,2)
    StartTime = $StartTime
} | Sort-Object TimeCreated -Descending | Select-Object -First 50

$critStatus = if ($SystemCritical.Count -gt 0) { "WARN" } else { "OK" }
Write-Step ("Loi System Critical/Error: " + $SystemCritical.Count + " su kien") $critStatus

# =========================================================
# 6. NHIET DO
# =========================================================
Write-Step "Kiem tra nhiet do..."
$ThermalZones = @()
try {
    $ThermalZones = @(Get-CimInstance -Namespace "root/wmi" -ClassName "MSAcpi_ThermalZoneTemperature" -ErrorAction Stop |
        Select-Object InstanceName,
            @{N="TempC"; E={[math]::Round($_.CurrentTemperature / 10 - 273.15, 1)}})
} catch { }

# =========================================================
# 7. NGUON DIEN
# =========================================================
Write-Step "Kiem tra su kien nguon dien..."

$PowerEvents = Get-EventSafe "System" @{
    ProviderName = "Microsoft-Windows-Kernel-Power"
    StartTime    = $StartTime
} | Where-Object { $_.Id -in @(41,42,107,109) } | Sort-Object TimeCreated -Descending | Select-Object -First 20

$PowerPlan = & powercfg /getactivescheme 2>$null | Out-String
$PowerPlanName = if ($PowerPlan -match "\((.+)\)") { $Matches[1] } else { "Khong xac dinh" }

# Sleep settings
$SleepAfterMin = "Khong ro"
try {
    $rawSleep = & powercfg /query SCHEME_CURRENT SUB_SLEEP STANDBYIDLE 2>$null | Out-String
    if ($rawSleep -match "Current AC Power Setting Index:\s+0x([0-9a-fA-F]+)") {
        $SleepAfterMin = ([int]("0x" + $Matches[1])) / 60
        $SleepAfterMin = if ($SleepAfterMin -eq 0) { "Tat" } else { "$SleepAfterMin phut" }
    }
} catch {}

# =========================================================
# 8. DICH VU BI CRASH
# =========================================================
Write-Step "Kiem tra dich vu bi crash..."

$ServiceCrash = Get-EventSafe "System" @{
    ProviderName = "Service Control Manager"
    StartTime    = $StartTime
} | Where-Object { $_.Id -in @(7031,7034) } | Sort-Object TimeCreated -Descending | Select-Object -First 20

$svcCrashStatus = if ($ServiceCrash.Count -gt 0) { "WARN" } else { "OK" }
Write-Step ("Dich vu crash: " + $ServiceCrash.Count + " su kien") $svcCrashStatus

# =========================================================
# 9. WINDOWS UPDATE
# =========================================================
Write-Step "Kiem tra Windows Update..."

$WURestarts = Get-EventSafe "System" @{
    ProviderName = "Microsoft-Windows-WindowsUpdateClient"
    StartTime    = $StartTime
} | Where-Object { $_.Id -in @(19,20,24,25,31,34) }

# =========================================================
# 10. PHAN TICH NGUYEN NHAN
# =========================================================
Write-Step "Phan tich nguyen nhan..." "INFO"

$Diagnosis = [System.Collections.Generic.List[hashtable]]::new()
$Severity  = "OK"

if ($UnexpectedShutdowns.Count -gt 0) {
    $Severity = "CRITICAL"
    $Diagnosis.Add(@{
        Title   = "[NGUY HIEM] Mat dien hoac He thong treo (Kernel-Power ID 41)"
        Detail  = "He thong da tat $($UnexpectedShutdowns.Count) lan ma khong qua quy trinh tat may dung. Co the do mat dien, CPU/GPU qua nhiet, loi phan cung, hoac nguon khong du cong."
        Advice  = "Kiem tra: nguon dien (PSU), nhiet do CPU/GPU bang HWiNFO64, RAM bang MemTest86, ket noi day dien trong case."
        Color   = "#ff4444"
        IconHex = "26A1"
    })
}

if ($DirtyShutdowns.Count -gt 0) {
    if ($Severity -eq "OK") { $Severity = "WARNING" }
    $Diagnosis.Add(@{
        Title   = "[CANH BAO] Tat may khong sach (Dirty Shutdown ID 6008)"
        Detail  = "Windows ghi nhan $($DirtyShutdowns.Count) lan tat khong qua trinh. Dieu nay xay ra sau ID 41, mat dien, hoac treo cung."
        Advice  = "Chay: sfc /scannow va chkdsk C: /f de kiem tra file system."
        Color   = "#ff8800"
        IconHex = "1F4A5"
    })
}

if ($MinidumpFiles.Count -gt 0 -or $BSODEvents.Count -gt 0) {
    $Severity = "CRITICAL"
    $Diagnosis.Add(@{
        Title   = "[NGUY HIEM] Man hinh xanh chet - BSOD / Kernel Crash"
        Detail  = "Phat hien $($MinidumpFiles.Count) file minidump va $($BSODEvents.Count) BSOD event. BSOD cho biet loi kernel cap do nghiem trong (loi RAM, driver, phan cung)."
        Advice  = "Phan tich minidump tai: $CrashDumpPath. Dung WhoCrashed hoac WinDbg de xem chi tiet. Cap nhat driver GPU."
        Color   = "#0044ff"
        IconHex = "1F534"
    })
}

if ($DiskErrors.Count -gt 0 -or $NTFSErrors.Count -gt 0) {
    if ($Severity -eq "OK") { $Severity = "WARNING" }
    $Diagnosis.Add(@{
        Title   = "[CANH BAO] Loi o cung - Disk I/O Error"
        Detail  = "Phat hien $($DiskErrors.Count) loi Disk I/O va $($NTFSErrors.Count) loi NTFS. O cung co the dang hu hong hoac cap noi bi long."
        Advice  = "Chay: chkdsk /f /r (yeu cau khoi dong lai). Dung CrystalDiskInfo de xem S.M.A.R.T status."
        Color   = "#ff4444"
        IconHex = "1F4BE"
    })
}

if ($WURestarts.Count -gt 0) {
    if ($Severity -eq "OK") { $Severity = "INFO" }
    $Diagnosis.Add(@{
        Title   = "[THONG TIN] Windows Update tu dong khoi dong lai"
        Detail  = "Windows Update da thuc hien $($WURestarts.Count) hanh dong. Co the da tu dong khoi dong lai may vao luc ban dang xem phim."
        Advice  = "Vao Settings > Windows Update > Advanced Options > tat 'Restart this device as soon as possible'."
        Color   = "#0099ff"
        IconHex = "1F504"
    })
}

if ($Diagnosis.Count -eq 0) {
    $Diagnosis.Add(@{
        Title   = "[TOT] Khong tim thay nguyen nhan ro rang"
        Detail  = "Trong $DaysBack ngay gan nhat khong phat hien loi nghiem trong trong Event Log. Co the su co xay ra truoc khung thoi gian quet, hoac do nguon dien nhat thoi."
        Advice  = "Nen cai dat UPS de bao ve nguon dien, theo doi nhiet do voi HWiNFO64, va tat Windows Update auto-restart."
        Color   = "#00aa44"
        IconHex = "2705"
    })
}

$sevStatus = if ($Severity -eq "CRITICAL") { "ERROR" } elseif ($Severity -eq "WARNING") { "WARN" } else { "OK" }
Write-Step ("Muc do: $Severity") $sevStatus

# =========================================================
# 11. TIMELINE
# =========================================================
$AllEvents = [System.Collections.Generic.List[PSCustomObject]]::new()

foreach ($e in $UnexpectedShutdowns) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="UNEXPECTED_SHUTDOWN"; Msg="Tat dot ngot (ID 41)"; Color="#ff4444"; Level="CRITICAL" })
}
foreach ($e in $DirtyShutdowns) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="DIRTY_SHUTDOWN"; Msg="Dirty Shutdown (ID 6008)"; Color="#ff8800"; Level="ERROR" })
}
foreach ($e in $CleanShutdowns) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="CLEAN_SHUTDOWN"; Msg="Tat binh thuong (ID 6006)"; Color="#00aa44"; Level="OK" })
}
foreach ($e in $SystemStarts) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="SYSTEM_START"; Msg="He thong khoi dong (ID 6005)"; Color="#0099ff"; Level="INFO" })
}
foreach ($e in $AppShutdowns) {
    $msg = "Tat boi ung dung (ID 1074)"
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="APP_SHUTDOWN"; Msg=$msg; Color="#9944ff"; Level="WARN" })
}
foreach ($e in $BSODEvents) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="BSOD"; Msg="BSOD Crash (ID 1001)"; Color="#0044ff"; Level="CRITICAL" })
}
foreach ($e in $WURestarts) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="WINDOWS_UPDATE"; Msg="Windows Update (ID $($e.Id))"; Color="#00aaff"; Level="INFO" })
}
foreach ($e in $DiskErrors) {
    $AllEvents.Add([PSCustomObject]@{ Time=$e.TimeCreated; Type="DISK_ERROR"; Msg="Loi o cung (ID $($e.Id))"; Color="#ff4444"; Level="ERROR" })
}

$Timeline = $AllEvents | Sort-Object Time -Descending | Select-Object -First 100

# =========================================================
# 12. XUAT TXT LOG
# =========================================================
Write-Step "Xuat file log van ban..."

$sb = [System.Text.StringBuilder]::new()
$null = $sb.AppendLine("=========================================================")
$null = $sb.AppendLine("  BAO CAO LOI HE THONG - SYSTEM ERROR REPORT")
$null = $sb.AppendLine("  Ngay quet: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')")
$null = $sb.AppendLine("  May tinh : $ComputerName")
$null = $sb.AppendLine("=========================================================")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("HE THONG:")
$null = $sb.AppendLine("  OS       : $OSVersion")
$null = $sb.AppendLine("  CPU      : $CPU")
$null = $sb.AppendLine("  RAM      : $RAM_GB GB")
$null = $sb.AppendLine("  Boot     : " + $LastBoot.ToString('dd/MM/yyyy HH:mm:ss'))
$null = $sb.AppendLine("  Uptime   : $UptimeStr")
$null = $sb.AppendLine("  Power    : $PowerPlanName (Sleep: $SleepAfterMin)")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("TOM TAT:")
$null = $sb.AppendLine("  Tat bat thuong (ID 41)   : " + $UnexpectedShutdowns.Count)
$null = $sb.AppendLine("  Dirty Shutdown (ID 6008)  : " + $DirtyShutdowns.Count)
$null = $sb.AppendLine("  BSOD / Crash dump         : " + ($MinidumpFiles.Count + $BSODEvents.Count))
$null = $sb.AppendLine("  Loi o cung                : " + ($DiskErrors.Count + $NTFSErrors.Count))
$null = $sb.AppendLine("  Windows Update restart    : " + $WURestarts.Count)
$null = $sb.AppendLine("  Dich vu crash             : " + $ServiceCrash.Count)
$null = $sb.AppendLine("  Muc do can trong          : $Severity")
$null = $sb.AppendLine("")
$null = $sb.AppendLine("CHAN DOAN:")

foreach ($d in $Diagnosis) {
    $null = $sb.AppendLine("  $($d.Title)")
    $null = $sb.AppendLine("  $($d.Detail)")
    $null = $sb.AppendLine("  => Khuyen nghi: $($d.Advice)")
    $null = $sb.AppendLine("")
}

$null = $sb.AppendLine("TIMELINE SU KIEN:")
foreach ($ev in $Timeline) {
    $line = ("  [" + $ev.Level.PadRight(8) + "] " + $ev.Time.ToString('dd/MM/yy HH:mm:ss') + " | " + $ev.Type.PadRight(18) + " | " + $ev.Msg)
    $null = $sb.AppendLine($line)
}

$null = $sb.AppendLine("")
$null = $sb.AppendLine("LOI HE THONG - CRITICAL/ERROR (Top 30):")
foreach ($ev in ($SystemCritical | Select-Object -First 30)) {
    $msg = ($ev.Message -replace '\r|\n',' ')
    if ($msg.Length -gt 120) { $msg = $msg.Substring(0,120) }
    $line = ("  [" + $ev.LevelDisplayName.PadRight(8) + "] " + $ev.TimeCreated.ToString('dd/MM/yy HH:mm:ss') + " ID:" + $ev.Id.ToString().PadRight(6) + " " + $msg)
    $null = $sb.AppendLine($line)
}

[System.IO.File]::WriteAllText($LogPath, $sb.ToString(), [System.Text.Encoding]::UTF8)
Write-Step "Log da luu: $LogPath" "OK"

# =========================================================
# 13. TAO HTML REPORT
# =========================================================
Write-Step "Tao bao cao HTML..."

# --- Build HTML blocks ---

# Timeline table rows
$TimelineHTML = [System.Text.StringBuilder]::new()
foreach ($ev in $Timeline) {
    $badgeClass = switch ($ev.Level) {
        "CRITICAL" { "badge-critical" }
        "ERROR"    { "badge-error" }
        "WARN"     { "badge-warn" }
        "OK"       { "badge-ok" }
        default    { "badge-info" }
    }
    $rowClass = $ev.Level.ToLower()
    $msgSafe  = Escape-Html $ev.Msg
    $null = $TimelineHTML.AppendLine("<tr class='tl-row $rowClass'>")
    $null = $TimelineHTML.AppendLine("<td>" + $ev.Time.ToString('dd/MM/yyyy HH:mm:ss') + "</td>")
    $null = $TimelineHTML.AppendLine("<td><span class='badge $badgeClass'>" + $ev.Level + "</span></td>")
    $null = $TimelineHTML.AppendLine("<td><code>" + (Escape-Html $ev.Type) + "</code></td>")
    $null = $TimelineHTML.AppendLine("<td>" + $msgSafe + "</td></tr>")
}

# Diagnosis cards
$DiagHTML = [System.Text.StringBuilder]::new()
foreach ($d in $Diagnosis) {
    $null = $DiagHTML.AppendLine("<div class='diag-card' style='border-left:4px solid $($d.Color)'>")
    $null = $DiagHTML.AppendLine("<div class='diag-title' style='color:$($d.Color)'>" + (Escape-Html $d.Title) + "</div>")
    $null = $DiagHTML.AppendLine("<div class='diag-detail'>" + (Escape-Html $d.Detail) + "</div>")
    $null = $DiagHTML.AppendLine("<div class='diag-advice'><strong>Khuyen nghi:</strong> " + (Escape-Html $d.Advice) + "</div>")
    $null = $DiagHTML.AppendLine("</div>")
}

# Disk bars
$DiskHTML = [System.Text.StringBuilder]::new()
foreach ($d in $Drives) {
    $barColor = if ($d.Used_Pct -gt 90) { "#f85149" } elseif ($d.Used_Pct -gt 75) { "#f0883e" } else { "#3fb950" }
    $null = $DiskHTML.AppendLine("<div class='disk-row'>")
    $null = $DiskHTML.AppendLine("<span class='disk-lbl'>$($d.Name):</span>")
    $null = $DiskHTML.AppendLine("<div class='disk-bg'><div class='disk-fill' style='width:$($d.Used_Pct)%;background:$barColor'></div></div>")
    $null = $DiskHTML.AppendLine("<span class='disk-info'>$($d.Free_GB) GB / $($d.Total_GB) GB ($($d.Used_Pct)%)</span>")
    $null = $DiskHTML.AppendLine("</div>")
}

# Thermal info
$ThermalHTML = [System.Text.StringBuilder]::new()
if ($ThermalZones.Count -gt 0) {
    foreach ($t in $ThermalZones) {
        $tc    = $t.TempC
        $tcolor = if ($tc -gt 90) { "#f85149" } elseif ($tc -gt 75) { "#f0883e" } else { "#3fb950" }
        $null = $ThermalHTML.AppendLine("<div class='temp-row'><span>" + (Escape-Html $t.InstanceName) + "</span><strong style='color:$tcolor'>" + $tc + "C</strong></div>")
    }
} else {
    $null = $ThermalHTML.AppendLine("<div class='temp-row'><span>Khong lay duoc nhiet do (can WMI sensor / HWiNFO64)</span></div>")
}

# Minidump rows
$DumpHTML = [System.Text.StringBuilder]::new()
if ($MinidumpFiles.Count -gt 0) {
    foreach ($f in $MinidumpFiles) {
        $null = $DumpHTML.AppendLine("<tr><td>" + $f.Name + "</td><td>" + $f.LastWriteTime.ToString('dd/MM/yy HH:mm:ss') + "</td><td>" + [math]::Round($f.Length/1KB,1) + " KB</td></tr>")
    }
} else {
    $null = $DumpHTML.AppendLine("<tr><td colspan='3' class='no-issue'>Khong co minidump - Tot!</td></tr>")
}

# System critical rows
$SysCritHTML = [System.Text.StringBuilder]::new()
if ($SystemCritical.Count -gt 0) {
    foreach ($ev in ($SystemCritical | Select-Object -First 30)) {
        $msg = ($ev.Message -replace '\r|\n',' ')
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0,200) + "..." }
        $msg = Escape-Html $msg
        $rowCls = if ($ev.Level -le 1) { "lv-crit" } else { "lv-err" }
        $null = $SysCritHTML.AppendLine("<tr class='$rowCls'>")
        $null = $SysCritHTML.AppendLine("<td>" + $ev.TimeCreated.ToString('dd/MM/yy HH:mm:ss') + "</td>")
        $null = $SysCritHTML.AppendLine("<td>" + (Escape-Html $ev.LevelDisplayName) + "</td>")
        $null = $SysCritHTML.AppendLine("<td>" + $ev.Id + "</td>")
        $null = $SysCritHTML.AppendLine("<td>" + (Escape-Html $ev.ProviderName) + "</td>")
        $null = $SysCritHTML.AppendLine("<td class='msg'>" + $msg + "</td></tr>")
    }
} else {
    $null = $SysCritHTML.AppendLine("<tr><td colspan='5' class='no-issue'>Khong co loi nghiem trong</td></tr>")
}

# Service crash rows
$SvcHTML = [System.Text.StringBuilder]::new()
if ($ServiceCrash.Count -gt 0) {
    foreach ($ev in $ServiceCrash) {
        $msg = ($ev.Message -replace '\r|\n',' ')
        if ($msg.Length -gt 200) { $msg = $msg.Substring(0,200) + "..." }
        $msg = Escape-Html $msg
        $null = $SvcHTML.AppendLine("<tr><td>" + $ev.TimeCreated.ToString('dd/MM/yy HH:mm:ss') + "</td><td>" + $ev.Id + "</td><td class='msg'>" + $msg + "</td></tr>")
    }
} else {
    $null = $SvcHTML.AppendLine("<tr><td colspan='3' class='no-issue'>Khong co dich vu bi crash</td></tr>")
}

# Summary stats
$unexpCnt  = $UnexpectedShutdowns.Count
$dirtyCnt  = $DirtyShutdowns.Count
$bsodCnt   = $MinidumpFiles.Count + $BSODEvents.Count
$diskCnt   = $DiskErrors.Count + $NTFSErrors.Count
$svcCnt    = $ServiceCrash.Count
$wuCnt     = $WURestarts.Count

$sevColor = switch ($Severity) {
    "CRITICAL" { "#f85149" }
    "WARNING"  { "#f0883e" }
    "INFO"     { "#79c0ff" }
    default    { "#3fb950" }
}
$sevLabel = switch ($Severity) {
    "CRITICAL" { "DO NGUY HIEM - CAN KIEM TRA NGAY!" }
    "WARNING"  { "CANH BAO - Nen kiem tra them" }
    "INFO"     { "THONG TIN - Co the lien quan" }
    default    { "BINH THUONG - He thong on dinh" }
}

$statClass = @{
    unexp = if ($unexpCnt -gt 0) { "stat-crit" } else { "stat-ok" }
    dirty = if ($dirtyCnt -gt 0) { "stat-warn" } else { "stat-ok" }
    bsod  = if ($bsodCnt -gt 0)  { "stat-crit" } else { "stat-ok" }
    disk  = if ($diskCnt -gt 0)  { "stat-warn" } else { "stat-ok" }
}

$ReportDate = Get-Date -Format 'dd/MM/yyyy HH:mm:ss'

$HTML = @"
<!DOCTYPE html>
<html lang="vi">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1.0">
<title>Bao Cao Loi He Thong - $ComputerName</title>
<style>
:root{--bg:#0d1117;--bg2:#161b22;--bg3:#21262d;--bd:#30363d;--txt:#c9d1d9;--txt2:#8b949e;--acc:#58a6ff;--grn:#3fb950;--red:#f85149;--orn:#f0883e;--pur:#bc8cff;--blu:#79c0ff;}
*{margin:0;padding:0;box-sizing:border-box;}
body{font-family:'Segoe UI',system-ui,sans-serif;background:var(--bg);color:var(--txt);line-height:1.6;font-size:14px;}
.hdr{background:linear-gradient(135deg,#0d1117,#162a4a,#0d1117);border-bottom:1px solid var(--bd);padding:28px 36px;}
.hdr h1{font-size:1.8rem;font-weight:700;color:#fff;}
.hdr h1 span{color:var(--acc);}
.hdr .sub{color:var(--txt2);margin-top:4px;}
.meta-row{display:flex;gap:12px;flex-wrap:wrap;margin-top:14px;}
.meta-chip{background:rgba(255,255,255,0.05);border:1px solid var(--bd);border-radius:8px;padding:6px 12px;font-size:0.82rem;}
.meta-chip b{color:var(--acc);}
.sev-badge{display:inline-block;margin-top:14px;padding:8px 18px;border-radius:100px;font-weight:700;border:2px solid $sevColor;color:$sevColor;background:rgba(255,255,255,0.03);}
.wrap{max-width:1300px;margin:0 auto;padding:24px 16px;}
.g4{display:grid;grid-template-columns:repeat(4,1fr);gap:16px;margin-bottom:20px;}
.g2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:20px;}
.card{background:var(--bg2);border:1px solid var(--bd);border-radius:10px;padding:18px;}
.card h3{color:var(--acc);font-size:0.95rem;margin-bottom:14px;}
.stat{text-align:center;padding:20px 10px;}
.stat-num{font-size:2.6rem;font-weight:700;line-height:1.1;}
.stat-lbl{color:var(--txt2);font-size:0.78rem;margin-top:4px;}
.stat-ok{color:#3fb950;}.stat-warn{color:#f0883e;}.stat-crit{color:#f85149;}.stat-info{color:#79c0ff;}
.sec-hdr{font-size:1.1rem;font-weight:700;color:var(--acc);margin:24px 0 12px;padding-bottom:6px;border-bottom:1px solid var(--bd);}
table{width:100%;border-collapse:collapse;font-size:0.82rem;}
th{background:var(--bg3);color:var(--acc);padding:9px 12px;text-align:left;border-bottom:1px solid var(--bd);}
td{padding:7px 12px;border-bottom:1px solid rgba(48,54,61,0.5);vertical-align:top;}
tr:hover td{background:rgba(255,255,255,0.02);}
.tl-row.critical td{border-left:3px solid #f85149;}
.tl-row.error td{border-left:3px solid #f0883e;}
.tl-row.warn td{border-left:3px solid #d29922;}
.tl-row.ok td{border-left:3px solid #3fb950;}
.tl-row.info td{border-left:3px solid #58a6ff;}
.lv-crit td{background:rgba(248,81,73,0.06);}
.lv-err td{background:rgba(240,136,62,0.06);}
.badge{padding:2px 7px;border-radius:4px;font-size:0.72rem;font-weight:700;}
.badge-critical{background:#f85149;color:#000;}
.badge-error{background:#f0883e;color:#000;}
.badge-warn{background:#d29922;color:#000;}
.badge-ok{background:#238636;color:#fff;}
.badge-info{background:#1f6feb;color:#fff;}
.diag-card{background:var(--bg2);border:1px solid var(--bd);border-radius:10px;padding:18px;margin-bottom:14px;}
.diag-title{font-weight:700;font-size:1rem;margin-bottom:8px;}
.diag-detail{color:var(--txt2);margin-bottom:10px;}
.diag-advice{background:rgba(88,166,255,0.07);border-radius:6px;padding:8px 12px;color:var(--blu);font-size:0.88rem;}
.disk-row{display:flex;align-items:center;gap:10px;margin-bottom:8px;}
.disk-lbl{font-weight:700;font-size:1rem;min-width:22px;}
.disk-bg{flex:1;height:7px;background:var(--bg3);border-radius:4px;overflow:hidden;}
.disk-fill{height:100%;border-radius:4px;}
.disk-info{font-size:0.8rem;color:var(--txt2);min-width:180px;}
.temp-row{display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px solid var(--bd);font-size:0.88rem;}
.msg{max-width:380px;word-break:break-all;font-size:0.78rem;color:var(--txt2);}
.no-issue{text-align:center;color:#3fb950;padding:14px;}
.cmd-table td:first-child{font-family:monospace;color:var(--pur);font-size:0.82rem;}
.footer{text-align:center;padding:24px;color:var(--txt2);font-size:0.78rem;border-top:1px solid var(--bd);margin-top:32px;}
@media(max-width:700px){.g4,.g2{grid-template-columns:1fr;}}
</style>
</head>
<body>

<div class="hdr">
  <h1>System Error Checker - <span>Bao Cao Loi He Thong</span></h1>
  <div class="sub">Phan tich nguyen nhan may tinh tu dong tat / khoi dong lai bat thuong</div>
  <div class="meta-row">
    <div class="meta-chip"><b>May tinh:</b> $ComputerName</div>
    <div class="meta-chip"><b>Ngay quet:</b> $ReportDate</div>
    <div class="meta-chip"><b>Pham vi:</b> $DaysBack ngay gan nhat</div>
    <div class="meta-chip"><b>Boot cuoi:</b> $($LastBoot.ToString('dd/MM/yyyy HH:mm:ss'))</div>
    <div class="meta-chip"><b>Uptime:</b> $UptimeStr</div>
  </div>
  <div class="sev-badge">Muc do: $Severity - $sevLabel</div>
</div>

<div class="wrap">

  <!-- STAT CARDS -->
  <div class="g4">
    <div class="card stat">
      <div class="stat-num $($statClass.unexp)">$unexpCnt</div>
      <div class="stat-lbl">Tat Dot Ngot (ID 41)</div>
    </div>
    <div class="card stat">
      <div class="stat-num $($statClass.dirty)">$dirtyCnt</div>
      <div class="stat-lbl">Dirty Shutdown (6008)</div>
    </div>
    <div class="card stat">
      <div class="stat-num $($statClass.bsod)">$bsodCnt</div>
      <div class="stat-lbl">BSOD / Crash Dump</div>
    </div>
    <div class="card stat">
      <div class="stat-num $($statClass.disk)">$diskCnt</div>
      <div class="stat-lbl">Loi O Cung (Disk)</div>
    </div>
  </div>

  <!-- CHAN DOAN -->
  <div class="sec-hdr">Chan Doan Nguyen Nhan</div>
  $($DiagHTML.ToString())

  <!-- THONG TIN HE THONG + O DIA -->
  <div class="g2">
    <div class="card">
      <h3>Thong Tin He Thong</h3>
      <table>
        <tr><td><b>Ten may</b></td><td>$ComputerName</td></tr>
        <tr><td><b>He dieu hanh</b></td><td>$OSVersion</td></tr>
        <tr><td><b>CPU</b></td><td>$(Escape-Html $CPU)</td></tr>
        <tr><td><b>RAM</b></td><td>$RAM_GB GB</td></tr>
        <tr><td><b>Boot cuoi</b></td><td>$($LastBoot.ToString('dd/MM/yyyy HH:mm:ss'))</td></tr>
        <tr><td><b>Uptime</b></td><td>$UptimeStr</td></tr>
        <tr><td><b>Power Plan</b></td><td>$(Escape-Html $PowerPlanName)</td></tr>
        <tr><td><b>Sleep sau</b></td><td>$SleepAfterMin</td></tr>
        <tr><td><b>Tat sach</b></td><td style="color:#3fb950">$($CleanShutdowns.Count) lan</td></tr>
        <tr><td><b>Khoi dong</b></td><td style="color:#58a6ff">$($SystemStarts.Count) lan</td></tr>
        <tr><td><b>WU Restart</b></td><td>$wuCnt lan</td></tr>
        <tr><td><b>Dich vu crash</b></td><td $(if($svcCnt -gt 0){"style='color:#f0883e'"})>$svcCnt su kien</td></tr>
      </table>
    </div>
    <div class="card">
      <h3>Tinh Trang O Dia</h3>
      $($DiskHTML.ToString())
      <h3 style="margin-top:16px">Nhiet Do He Thong</h3>
      $($ThermalHTML.ToString())
    </div>
  </div>

  <!-- CRASH DUMP -->
  <div class="sec-hdr">Crash Dump Files (BSOD Minidump)</div>
  <div class="card" style="padding:0;overflow:hidden">
    <table>
      <tr><th>Ten file</th><th>Thoi gian</th><th>Kich thuoc</th></tr>
      $($DumpHTML.ToString())
    </table>
    $(if($MinidumpFiles.Count -gt 0){"<div style='padding:12px;color:#f85149'>Phan tich minidump: Mo WhoCrashed hoac WinDbg, tro vao $CrashDumpPath</div>"})
  </div>

  <!-- TIMELINE -->
  <div class="sec-hdr">Timeline Su Kien ($($Timeline.Count) su kien gan nhat)</div>
  <div class="card" style="padding:0;overflow:hidden">
    <div style="overflow-x:auto">
      <table>
        <tr><th>Thoi Gian</th><th>Muc Do</th><th>Loai Su Kien</th><th>Thong Tin</th></tr>
        $($TimelineHTML.ToString())
      </table>
    </div>
  </div>

  <!-- SYSTEM CRITICAL -->
  <div class="sec-hdr">Loi He Thong Critical/Error (Top 30 gan nhat)</div>
  <div class="card" style="padding:0;overflow:hidden">
    <div style="overflow-x:auto">
      <table>
        <tr><th>Thoi Gian</th><th>Muc</th><th>ID</th><th>Nguon</th><th>Thong Diep</th></tr>
        $($SysCritHTML.ToString())
      </table>
    </div>
  </div>

  <!-- SERVICE CRASH -->
  <div class="sec-hdr">Dich Vu Bi Crash ($svcCnt su kien)</div>
  <div class="card" style="padding:0;overflow:hidden">
    <table>
      <tr><th>Thoi Gian</th><th>Event ID</th><th>Thong Tin</th></tr>
      $($SvcHTML.ToString())
    </table>
  </div>

  <!-- HUONG DAN KHAC PHUC -->
  <div class="sec-hdr">Huong Dan Kiem Tra Va Khac Phuc</div>
  <div class="g2">
    <div class="card">
      <h3>Lenh Kiem Tra (chay cmd voi quyen Admin)</h3>
      <table class="cmd-table">
        <tr><td>sfc /scannow</td><td>Kiem tra file he thong</td></tr>
        <tr><td>chkdsk C: /f /r</td><td>Kiem tra o dia C:</td></tr>
        <tr><td>DISM /Online /Cleanup-Image /RestoreHealth</td><td>Sua anh Windows</td></tr>
        <tr><td>powercfg /energy</td><td>Bao cao nguon dien</td></tr>
        <tr><td>powercfg /sleepstudy</td><td>Bao cao sleep/wake</td></tr>
        <tr><td>mdsched.exe</td><td>Kiem tra RAM (can reboot)</td></tr>
        <tr><td>eventvwr.msc</td><td>Mo Event Viewer</td></tr>
      </table>
    </div>
    <div class="card">
      <h3>Phan Mem Ho Tro Tuyen Dung</h3>
      <table>
        <tr><td><b>WhoCrashed</b></td><td>Phan tich BSOD de hieu</td></tr>
        <tr><td><b>CrystalDiskInfo</b></td><td>S.M.A.R.T o cung</td></tr>
        <tr><td><b>HWiNFO64</b></td><td>Nhiet do, dien ap real-time</td></tr>
        <tr><td><b>MemTest86</b></td><td>Kiem tra RAM toan dien</td></tr>
        <tr><td><b>WinDbg Preview</b></td><td>Phan tich crash dump sau</td></tr>
        <tr><td><b>UPS / AVR</b></td><td>Bao ve nguon dien mat on dinh</td></tr>
        <tr><td><b>GPU-Z</b></td><td>Theo doi GPU, VRAM</td></tr>
      </table>
    </div>
  </div>

</div>

<div class="footer">
  <div>Bao cao duoc tao boi <b>SystemCheck v2.0</b> - AntiGravity System Monitor</div>
  <div style="margin-top:3px">$ReportDate | $ComputerName | Windows Event Log Analysis (Pham vi: $DaysBack ngay)</div>
</div>

</body>
</html>
"@

# Save HTML with UTF-8 BOM so browser reads correctly
$utf8bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($ReportPath, $HTML, $utf8bom)
Write-Step "Bao cao HTML da luu: $ReportPath" "OK"

# =========================================================
# 14. TOM TAT CONSOLE
# =========================================================
Write-Host ""
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host "  TOM TAT KET QUA" -ForegroundColor White
Write-Host "  ================================================" -ForegroundColor DarkGray
Write-Host ("  May tinh  : $ComputerName") -ForegroundColor Gray
Write-Host ("  Boot cuoi : " + $LastBoot.ToString('dd/MM/yyyy HH:mm:ss')) -ForegroundColor Gray
Write-Host ""

$items = @(
    @{ Label="Tat dot ngot (ID 41)  "; Val=$unexpCnt; Bad=$true }
    @{ Label="Dirty Shutdown (ID 6008)"; Val=$dirtyCnt; Bad=$true }
    @{ Label="BSOD / Minidump       "; Val=$bsodCnt;  Bad=$true }
    @{ Label="Loi o cung            "; Val=$diskCnt;  Bad=$true }
    @{ Label="WU auto-restart       "; Val=$wuCnt;    Bad=$false }
    @{ Label="Dich vu crash         "; Val=$svcCnt;   Bad=$false }
)
foreach ($item in $items) {
    Write-Host ("  " + $item.Label + ": ") -ForegroundColor Gray -NoNewline
    if ($item.Val -gt 0 -and $item.Bad) {
        Write-Host ("$($item.Val) LAN!") -ForegroundColor Red
    } elseif ($item.Val -gt 0) {
        Write-Host ("$($item.Val)") -ForegroundColor Yellow
    } else {
        Write-Host "Khong co [OK]" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host ("  CHAN DOAN: $Severity") -ForegroundColor $(
    switch($Severity){"CRITICAL"{"Red"}"WARNING"{"Yellow"}default{"Green"}}
)
Write-Host ""
foreach ($d in $Diagnosis) {
    $c = switch ($d.Color) {
        "#ff4444" { "Red" }
        "#ff8800" { "Yellow" }
        "#00aa44" { "Green" }
        default   { "Cyan" }
    }
    Write-Host ("  >> " + $d.Title) -ForegroundColor $c
}
Write-Host ""
