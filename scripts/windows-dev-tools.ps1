# Windows Development Tools for TruckerCore
# Quick access to common tasks

param(
    [string]$Command = "menu"
)

$Blue = "`e[34m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Reset = "`e[0m"

function Show-Menu {
    Clear-Host
    Write-Host "${Blue}╔════════════════════════════════════════════════╗${Reset}"
    Write-Host "${Blue}║     TruckerCore Windows Dev Tools             ║${Reset}"
    Write-Host "${Blue}╚════════════════════════════════════════════════╝${Reset}"
    Write-Host ""
    Write-Host "Select an option:"
    Write-Host ""
    Write-Host "  ${Green}1${Reset} - Check DNS configuration"
    Write-Host "  ${Green}2${Reset} - Detailed DNS report"
    Write-Host "  ${Green}3${Reset} - Flush DNS cache"
    Write-Host "  ${Green}4${Reset} - Test local routes"
    Write-Host "  ${Green}5${Reset} - Check deployment status"
    Write-Host "  ${Green}6${Reset} - Open DNS guide"
    Write-Host "  ${Green}q${Reset} - Quit"
    Write-Host ""
}

function Invoke-Selection {
    param([string]$Choice)
    
    switch ($Choice) {
        '1' {
            Write-Host "${Blue}Running DNS check...${Reset}"
            powershell -ExecutionPolicy Bypass -File ./scripts/dns/check-windows.ps1
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        '2' {
            Write-Host "${Blue}Generating detailed DNS report...${Reset}"
            powershell -ExecutionPolicy Bypass -File ./scripts/dns/detailed-check-windows.ps1
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        '3' {
            Write-Host "${Blue}Flushing DNS cache...${Reset}"
            powershell -ExecutionPolicy Bypass -File ./scripts/dns/flush-cache-windows.ps1
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        '4' {
            Write-Host "${Blue}Testing local routes...${Reset}"
            Write-Host "${Yellow}Note: Make sure dev server is running (npm run dev)${Reset}"
            Read-Host "`nPress Enter to continue" | Out-Null
            bash ./scripts/test-local-routes.sh
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        '5' {
            Write-Host "${Blue}Checking deployment status...${Reset}"
            bash ./scripts/deployment-status.sh
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        '6' {
            Write-Host "${Blue}Opening DNS guide...${Reset}"
            node ./scripts/dns/open-guide.mjs
            Read-Host "`nPress Enter to continue" | Out-Null
        }
        'q' {
            Write-Host "${Green}Goodbye!${Reset}"
            exit
        }
        default {
            Write-Host "${Yellow}Invalid option. Please try again.${Reset}"
            Start-Sleep -Seconds 1
        }
    }
}

# Main loop
if ($Command -eq "menu") {
    do {
        Show-Menu
        $Selection = Read-Host "Enter your choice"
        Invoke-Selection -Choice $Selection
    } while ($Selection -ne 'q')
} else {
    # Direct command execution (map 1..6 or 'q')
    Invoke-Selection -Choice $Command
}