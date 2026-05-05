param()
try {
    $exfilPath = Join-Path $env:USERPROFILE 'bops4048\exfil'
    $expected = [ordered]@{
        '01' = @{ flag='stage-01.flag'; carrier='neo-6447686c63.bin'; writer='powershell.exe'; partFile='part1.dat' }
        '02' = @{ flag='stage-02.flag'; carrier='trinity-6d56706332.bin'; writer='azcopy.exe';     partFile='part2.dat' }
        '03' = @{ flag='stage-03.flag'; carrier='tank-3576633342.bin'; writer='az.cmd';         partFile='part3.dat' }
        '04' = @{ flag='stage-04.flag'; carrier='morpheus-766232343d.bin'; writer='az.cmd';         partFile='part4.dat' }
    }
    $failures = @()
    $passes = @()
    foreach ($k in $expected.Keys) {
        $e = $expected[$k]
        $flagPath = Join-Path $exfilPath $e.flag
        $partPath = Join-Path $exfilPath $e.partFile
        if (-not (Test-Path -LiteralPath $flagPath)) {
            $failures += "stage $k did not complete: missing $flagPath"
            continue
        }
        $content = Get-Content -LiteralPath $flagPath -Raw
        if ($content -notmatch [regex]::Escape('carrier=' + $e.carrier)) {
            $failures += "stage $k flag has wrong carrier: expected '$($e.carrier)' in $flagPath"
            continue
        }
        if ($content -notmatch [regex]::Escape('writer=' + $e.writer)) {
            $failures += "stage $k flag has wrong writer: expected '$($e.writer)' in $flagPath"
            continue
        }
        if (-not (Test-Path -LiteralPath $partPath)) {
            $failures += "stage $k input artifact missing: $partPath"
            continue
        }
        $passes += "stage $k OK ($($e.carrier), $($e.writer))"
    }
    Write-Host ''
    foreach ($p in $passes) { Write-Host "  PASS: $p" -ForegroundColor Green }
    if ($failures.Count -gt 0) {
        Write-Host ''
        Write-Host "FAIL: $($failures.Count) issue(s):" -ForegroundColor Red
        foreach ($f in $failures) { Write-Host "  - $f" -ForegroundColor Red }
        exit 1
    }
    Write-Host ''
    Write-Host "PASS: all 4 stages emitted end-of-run flags with correct carriers + input artifacts." -ForegroundColor Green
    exit 0
}
catch {
    Write-Host "FAIL: Validator error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
