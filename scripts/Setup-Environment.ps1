<#
.SYNOPSIS
    Sets up environment variables for TruckerCore deployment
.DESCRIPTION
    Interactive script to configure required environment variables
.PARAMETER Save
    Save to .env file in project root
#>

param(
    [switch]$Save
)

Write-Host "TruckerCore Environment Setup`n" -ForegroundColor Cyan

# Prompt for variables
$vars = @{
    "SUPABASE_URL" = "Supabase project URL (https://xxx.supabase.co)"
    "SUPABASE_SERVICE_ROLE_KEY" = "Supabase service role key (starts with eyJ...)"
    "SUPABASE_ANON_KEY" = "Supabase anon key (optional, starts with eyJ...)"
}

$config = @{}

foreach ($key in $vars.Keys) {
    $current = [Environment]::GetEnvironmentVariable($key)
    $prompt = $vars[$key]
    
    if ($current) {
        $masked = if ($current.Length -gt 20) { $current.Substring(0, 20) + "..." } else { $current }
        Write-Host "$key (current: $masked)"
        $input = Read-Host "  Press Enter to keep, or paste new value"
        if ([string]::IsNullOrWhiteSpace($input)) {
            $config[$key] = $current
        }
        else {
            $config[$key] = $input.Trim()
        }
    }
    else {
        Write-Host "$key ($prompt)"
        $input = Read-Host "  Value"
        $config[$key] = $input.Trim()
    }
}

# Set for current session
foreach ($key in $config.Keys) {
    [Environment]::SetEnvironmentVariable($key, $config[$key], "Process")
    Write-Host "✓ Set $key for current session" -ForegroundColor Green
}

# Save to .env file
if ($Save) {
    $envPath = ".env"
    $lines = @()
    
    if (Test-Path $envPath) {
        $lines = Get-Content $envPath
    }
    
    foreach ($key in $config.Keys) {
        $value = $config[$key]
        $pattern = "^$key="
        
        if ($lines -match $pattern) {
            $lines = $lines -replace $pattern, "$key=$value"
        }
        else {
            $lines += "$key=$value"
        }
    }
    
    Set-Content -Path $envPath -Value $lines
    Write-Host "✓ Saved to $envPath" -ForegroundColor Green
}

Write-Host "`nEnvironment setup complete!" -ForegroundColor Green
Write-Host "Run deployment: npm run deploy:safety-suite:win"
