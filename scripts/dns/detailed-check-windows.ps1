# Detailed DNS report for Windows
# Usage: .\scripts\dns\detailed-check-windows.ps1

$Blue = "`e[34m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Red = "`e[31m"
$Reset = "`e[0m"

Write-Host "${Blue}╔════════════════════════════════════════════════╗${Reset}"
Write-Host "${Blue}║   TruckerCore DNS Detailed Report (Windows)   ║${Reset}"
Write-Host "${Blue}╚════════════════════════════════════════════════╝${Reset}"
Write-Host ""

# Check each domain
$Domains = @(
    'truckercore.com',
    'www.truckercore.com',
    'app.truckercore.com',
    'api.truckercore.com',
    'downloads.truckercore.com'
)

foreach ($Domain in $Domains) {
    Write-Host "${Blue}━━━ $Domain ━━━${Reset}"
    
    # Get all DNS records
    try {
        $Results = Resolve-DnsName -Name $Domain -ErrorAction Stop
    } catch {
        $Results = $null
    }
    
    if ($Results) {
        foreach ($Record in $Results) {
            $Type = $Record.Type
            
            if ($Type -eq 1) { # A record
                Write-Host "  ${Green}✓ A Record:${Reset} $($Record.IPAddress)"
            }
            elseif ($Type -eq 5) { # CNAME record
                Write-Host "  ${Green}✓ CNAME:${Reset} $($Record.NameHost)"
            }
            elseif ($Type -eq 2) { # NS record
                Write-Host "  ${Yellow}Nameserver:${Reset} $($Record.NameHost)"
            }
        }
    } else {
        Write-Host "  ${Red}❌ No DNS records found${Reset}"
    }
    
    # Check response time
    try {
        $Start = Get-Date
        $null = Resolve-DnsName -Name $Domain -Type A -ErrorAction Stop
        $Duration = ((Get-Date) - $Start).TotalMilliseconds
        Write-Host "  ${Blue}Response time:${Reset} $([math]::Round($Duration, 0))ms"
    } catch {
        Write-Host "  ${Yellow}Response time:${Reset} N/A"
    }
    
    Write-Host ""
}

# Check nameservers for root domain
Write-Host "${Blue}━━━ Nameservers ━━━${Reset}"
try {
    $NS = Resolve-DnsName -Name 'truckercore.com' -Type NS -ErrorAction Stop
} catch {
    $NS = $null
}

if ($NS) {
    foreach ($Server in $NS) {
        if ($Server.NameHost -like '*vercel*') {
            Write-Host "  ${Green}✓ $($Server.NameHost) (Vercel managed)${Reset}"
        } else {
            Write-Host "  $($Server.NameHost)"
        }
    }
} else {
    Write-Host "  ${Red}❌ Could not retrieve nameservers${Reset}"
}

Write-Host ""
Write-Host "══════════════════════════════════════════════════"
Write-Host ""
Write-Host "For quick check, run:"
Write-Host "  npm run dns:check:win"