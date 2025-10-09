# TruckerCore DNS Verification Script for Windows
# Usage: .\scripts\dns\check-windows.ps1

# ANSI color codes for PowerShell
$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Reset = "`e[0m"

# Expected DNS configurations
$ExpectedConfig = @{
    'truckercore.com' = @{
        Type = 'A'
        Target = '76.76.21.21'
        Description = 'Root domain -> Vercel'
    }
    'www.truckercore.com' = @{
        Type = 'CNAME'
        Pattern = '^(cname\.vercel-dns\.com|[a-f0-9]+\.vercel-dns-\d+\.com)\.?$'
        Description = 'WWW subdomain -> Vercel'
    }
    'app.truckercore.com' = @{
        Type = 'CNAME'
        Pattern = '^(cname\.vercel-dns\.com|[a-f0-9]+\.vercel-dns-\d+\.com)\.?$'
        Description = 'App subdomain -> Vercel'
    }
    'api.truckercore.com' = @{
        Type = 'CNAME'
        Pattern = '^[a-z0-9]+\.functions\.supabase\.co\.?$'
        Description = 'API subdomain -> Supabase Edge Functions'
        Expected = 'viqrwlzdtosxjzjvtxnr.functions.supabase.co'
    }
    'downloads.truckercore.com' = @{
        Type = 'CNAME'
        Pattern = '^[a-z0-9]+\.supabase\.co\.?$'
        Description = 'Downloads subdomain -> Supabase Storage'
        Expected = 'viqrwlzdtosxjzjvtxnr.supabase.co'
    }
}

function Check-DNS {
    param(
        [string]$Domain
    )
    
    $Config = $ExpectedConfig[$Domain]
    if (-not $Config) {
        return @{
            Domain = $Domain
            Status = 'unknown'
            Message = 'Not in expected config'
        }
    }

    try {
        if ($Config.Type -eq 'A') {
            # Check A record
            $Result = Resolve-DnsName -Name $Domain -Type A -ErrorAction SilentlyContinue
            
            if (-not $Result) {
                return @{
                    Domain = $Domain
                    Status = 'error'
                    Message = 'No A record found'
                    Expected = $Config.Target
                    Description = $Config.Description
                }
            }

            $IP = $Result[0].IPAddress
            if ($IP -eq $Config.Target) {
                return @{
                    Domain = $Domain
                    Status = 'success'
                    Message = "[OK] $IP"
                    Description = $Config.Description
                }
            } else {
                return @{
                    Domain = $Domain
                    Status = 'error'
                    Message = "[ERR] Wrong IP: $IP"
                    Expected = $Config.Target
                    Description = $Config.Description
                }
            }
        }
        elseif ($Config.Type -eq 'CNAME') {
            # Check CNAME record
            $Result = Resolve-DnsName -Name $Domain -Type CNAME -ErrorAction SilentlyContinue
            
            if (-not $Result) {
                return @{
                    Domain = $Domain
                    Status = 'error'
                    Message = 'No CNAME record found'
                    Expected = $Config.Expected
                    Description = $Config.Description
                }
            }

            $CNAME = $Result[0].NameHost
            
            # Check pattern match
            if ($Config.Pattern) {
                if ($CNAME -match $Config.Pattern) {
                    return @{
                        Domain = $Domain
                        Status = 'success'
                        Message = "[OK] $CNAME"
                        Description = $Config.Description
                    }
                } else {
                    return @{
                        Domain = $Domain
                        Status = 'error'
                        Message = "[ERR] Wrong target: $CNAME"
                        Expected = $Config.Expected
                        Description = $Config.Description
                    }
                }
            }
        }
    }
    catch {
        return @{
            Domain = $Domain
            Status = 'error'
            Message = "Error: $($_.Exception.Message)"
        }
    }
}

# Main script
Write-Host "==== TruckerCore DNS Verification (Windows) ===="
Write-Host ""

$AllGood = $true
$Errors = @()

foreach ($Domain in $ExpectedConfig.Keys) {
    $Result = Check-DNS -Domain $Domain
    
    $StatusColor = if ($Result.Status -eq 'success') { $Green } else { $Red }
    
    Write-Host $Result.Domain
    Write-Host "  $($Result.Description)"
    Write-Host "  ${StatusColor}$($Result.Message)${Reset}"
    
    if ($Result.Expected -and $Result.Status -ne 'success') {
        Write-Host "  ${Yellow}Expected: $($Result.Expected)${Reset}"
    }
    
    Write-Host ""
    
    if ($Result.Status -ne 'success') {
        $AllGood = $false
        $Errors += $Result
    }
}

# Summary
Write-Host "----------------------------------------"

if ($AllGood) {
    Write-Host "All DNS records configured correctly!"
    Write-Host ""
    Write-Host "Next steps:"
    Write-Host "  1. npm run deploy"
    Write-Host "  2. npm run check:production"
    Write-Host ""
    Write-Host "Your domains:"
    Write-Host "  https://truckercore.com"
    Write-Host "  https://www.truckercore.com"
    Write-Host "  https://app.truckercore.com"
    Write-Host "  https://api.truckercore.com/health"
    exit 0
} else {
    Write-Host "ERROR: $($Errors.Count) DNS record(s) need attention"
    Write-Host ""
    Write-Host "To fix these issues:"
    Write-Host "  1. npm run dns:guide"
    Write-Host "  2. Update DNS records in your provider"
    Write-Host "  3. Wait 5-10 minutes for propagation"
    Write-Host "  4. npm run dns:check:win (re-run this check)"
    exit 1
}