Param(
  [string[]]$Domains = @('truckercore.com','www.truckercore.com','app.truckercore.com','api.truckercore.com','downloads.truckercore.com')
)

# Colors
$Green = "`e[32m"; $Red = "`e[31m"; $Yellow = "`e[33m"; $Blue = "`e[34m"; $Reset = "`e[0m"

Write-Host ("{0}╔════════════════════════════════════════════════╗{1}" -f $Blue,$Reset)
Write-Host ("{0}║     TruckerCore DNS Verification (Windows)    ║{1}" -f $Blue,$Reset)
Write-Host ("{0}╚════════════════════════════════════════════════╝{1}`n" -f $Blue,$Reset)

# Expected configuration
$Expected = @{
  'truckercore.com' = @{ type='A'; targets=@('76.76.21.21'); description='Root domain → Vercel' }
  'www.truckercore.com' = @{ type='CNAME'; targets=@('cname.vercel-dns.com.','cname.vercel-dns.com'); description='WWW subdomain → Vercel' }
  'app.truckercore.com' = @{ type='CNAME'; targets=@('cname.vercel-dns.com.','cname.vercel-dns.com'); description='App subdomain → Vercel' }
  'api.truckercore.com' = @{ type='CNAME'; pattern='\.functions\.supabase\.co\.?$'; description='API subdomain → Supabase Edge Functions' }
  'downloads.truckercore.com' = @{ type='CNAME'; pattern='\.supabase\.co\.?$'; description='Downloads subdomain → Supabase Storage' }
}

$errors = @()

function Get-DnsRecordValue {
  param(
    [string]$Domain,
    [string]$Type
  )
  try {
    $rec = Resolve-DnsName -Name $Domain -Type $Type -ErrorAction Stop | Select-Object -First 1
    if ($null -eq $rec) { return $null }
    if ($Type -eq 'A') { return $rec.IPAddress }
    if ($Type -eq 'CNAME') { return $rec.CName }
    return $null
  } catch {
    return $null
  }
}

foreach ($domain in $Domains) {
  $exp = $Expected[$domain]
  if (-not $exp) {
    Write-Host "$domain"; Write-Host "  Not in expected config"; Write-Host ""; continue
  }

  $value = Get-DnsRecordValue -Domain $domain -Type $exp.type

  Write-Host $domain
  if ($exp.description) { Write-Host "  $($exp.description)" }

  if (-not $value) {
    Write-Host ("  {0}No {1} record found{2}" -f $Red,$exp.type,$Reset)
    if ($exp.targets -and $exp.targets.Count -gt 0) {
      Write-Host ("  {0}Expected: {1}{2}" -f $Yellow,$exp.targets[0],$Reset)
    } elseif ($exp.pattern) {
      Write-Host ("  {0}Expected: Target matching pattern {1}{2}" -f $Yellow,$exp.pattern,$Reset)
    }
    Write-Host ""
    $errors += $domain
    continue
  }

  $ok = $false
  if ($exp.targets) {
    $ok = $exp.targets -contains $value
  } elseif ($exp.pattern) {
    $ok = [bool]([regex]::IsMatch($value, $exp.pattern))
  }

  if ($ok) {
    Write-Host ("  {0}✅ {1}{2}" -f $Green,$value,$Reset)
  } else {
    Write-Host ("  {0}❌ Wrong target: {1}{2}" -f $Red,$value,$Reset)
    if ($exp.targets -and $exp.targets.Count -gt 0) {
      Write-Host ("  {0}Expected: {1}{2}" -f $Yellow,$exp.targets[0],$Reset)
    } elseif ($exp.pattern) {
      Write-Host ("  {0}Expected: Target matching pattern {1}{2}" -f $Yellow,$exp.pattern,$Reset)
    }
    $errors += $domain
  }
  Write-Host ""
}

Write-Host ('═' * 50)
if ($errors.Count -eq 0) {
  Write-Host ("{0}✅ All DNS records configured correctly!{1}" -f $Green,$Reset)
  Write-Host ""
  Write-Host "Next steps:"
  Write-Host "  1. npm run deploy"
  Write-Host "  2. npm run check:production"
  exit 0
} else {
  Write-Host ("{0}❌ {1} DNS record(s) need attention{2}" -f $Red,$errors.Count,$Reset)
  Write-Host ""
  Write-Host "To fix these issues:"
  Write-Host "  1. npm run dns:guide"
  Write-Host "  2. Update DNS records in your provider"
  Write-Host "  3. Wait 5-10 minutes for propagation"
  Write-Host "  4. Re-run: npm run dns:check:win"
  exit 1
}