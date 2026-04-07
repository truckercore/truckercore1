# Flush DNS cache on Windows
# Usage: .\scripts\dns\flush-cache-windows.ps1

$Green = "`e[32m"
$Blue = "`e[34m"
$Reset = "`e[0m"

Write-Host "${Blue}🔄 Flushing DNS cache...${Reset}"

# Clear DNS client cache
try {
  Clear-DnsClientCache
  Write-Host "${Green}✅ DNS client cache cleared${Reset}"
} catch {
  Write-Host "Failed to clear DNS cache: $($_.Exception.Message)"
}

Write-Host ""
Write-Host "${Blue}Current DNS cache entries (filtered for truckercore):${Reset}"
try {
  Get-DnsClientCache | Where-Object { $_.Entry -like '*truckercore*' } | Format-Table Entry, Data, TTL
} catch {
  Write-Host "No matching cache entries or insufficient permissions."
}

Write-Host ""
Write-Host "Re-run DNS check:"
Write-Host "  npm run dns:check:win"