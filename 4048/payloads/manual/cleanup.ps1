param()
$exfilPath = Join-Path $env:USERPROFILE 'bops4048\exfil'
$removed = @()
$skipped = @()
if (-not (Test-Path -LiteralPath $exfilPath)) {
    Write-Host "nothing to clean: $exfilPath does not exist"
    exit 0
}
$patterns = @('part*.dat', 'stage-*.flag')
foreach ($pattern in $patterns) {
    Get-ChildItem -LiteralPath $exfilPath -Filter $pattern -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
            $removed += $_.FullName
        } catch {
            $skipped += ("$($_.FullName) ($($_.Exception.Message))")
        }
    }
}
if ($removed.Count -gt 0) {
    Write-Host "removed $($removed.Count) artifact(s):"
    $removed | ForEach-Object { Write-Host "  - $_" }
} else {
    Write-Host "no artifacts to remove (already clean)"
}
if ($skipped.Count -gt 0) {
    Write-Host "skipped $($skipped.Count) artifact(s):"
    $skipped | ForEach-Object { Write-Host "  ! $_" }
}
exit 0
