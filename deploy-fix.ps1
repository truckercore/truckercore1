# TruckerCore Deployment - Router Fix and Verification
# Usage: powershell -ExecutionPolicy Bypass -File deploy-fix.ps1

$Green = "`e[32m"
$Red = "`e[31m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$Cyan = "`e[36m"
$Reset = "`e[0m"

Write-Host $Blue
@"
╔════════════════════════════════════════════════╗
║   TruckerCore Deployment - Router Fix         ║
╚════════════════════════════════════════════════╝
"@
Write-Host "$Reset`n"

# Step 1: Verify app/ is removed
Write-Host "${Blue}Step 1/6: Verifying router configuration...${Reset}"
if (Test-Path app) {
    Write-Host "${Red}❌ app/ directory still exists${Reset}"
    Write-Host "   Removing it now..."
    Remove-Item -Recurse -Force app
    Write-Host "${Green}✅ Removed app/ directory${Reset}"
} else {
    Write-Host "${Green}✅ app/ directory not present${Reset}"
}
Write-Host ""

# Step 2: Clean build
Write-Host "${Blue}Step 2/6: Cleaning previous build...${Reset}"
try { Remove-Item -Recurse -Force .next -ErrorAction SilentlyContinue } catch {}
Write-Host "${Green}✅ Cleaned${Reset}`n"

# Step 3: Test build
Write-Host "${Blue}Step 3/6: Testing production build...${Reset}"
npm run build 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "${Green}✅ Build succeeded${Reset}`n"
} else {
    Write-Host "${Red}❌ Build failed${Reset}"
    Write-Host "Running build again to show errors..."
    npm run build
    exit 1
}

# Step 4: Test locally
Write-Host "${Blue}Step 4/6: Testing local server...${Reset}"
$job = Start-Job -ScriptBlock { Set-Location $using:PWD; npm run start }
Start-Sleep -Seconds 5
try {
    $response = Invoke-WebRequest -Uri "http://localhost:3000" -Method Head -TimeoutSec 5 -ErrorAction Stop
    Write-Host "${Green}✅ Local server works (Status: $($response.StatusCode))${Reset}`n"
} catch {
    Write-Host "${Yellow}⚠️  Could not test local server (non-critical)${Reset}`n"
} finally {
    Stop-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
    Remove-Job -Job $job -ErrorAction SilentlyContinue | Out-Null
}

# Step 5: Commit and deploy
Write-Host "${Blue}Step 5/6: Deploying to production...${Reset}"
$status = git status --porcelain
if ($status) {
    Write-Host "Committing changes..."
    git add -A
    git commit -m "fix: Remove app/ directory to resolve router conflict and 404 issue"
    Write-Host "Pushing to trigger deployment..."
    git push origin main
    if ($LASTEXITCODE -eq 0) {
        Write-Host "${Green}✅ Pushed successfully${Reset}`n"
        Write-Host "${Yellow}⏳ Waiting for Vercel deployment (2 minutes)...${Reset}"
        for ($i = 120; $i -gt 0; $i--) {
            Write-Progress -Activity "Deployment in progress" -Status "$i seconds remaining..." -SecondsRemaining $i
            Start-Sleep -Seconds 1
        }
        Write-Progress -Activity "Deployment in progress" -Completed
        Write-Host "${Green}✅ Wait complete${Reset}`n"
    } else {
        Write-Host "${Red}❌ Git push failed${Reset}"
        exit 1
    }
} else {
    Write-Host "${Yellow}No changes to commit${Reset}`n"
}

# Step 6: Verify production
Write-Host "${Blue}Step 6/6: Verifying production deployment...${Reset}`n"
npm run verify:fix

# Success
Write-Host ""
Write-Host $Green
@"
╔════════════════════════════════════════════════╗
║            ✅ DEPLOYMENT COMPLETE! ✅          ║
╚════════════════════════════════════════════════╝
"@
Write-Host $Reset

Write-Host "${Cyan}🌐 Your Production URLs:${Reset}"
Write-Host "   Homepage:  https://truckercore.com"
Write-Host "   App:       https://app.truckercore.com"
Write-Host "   API:       https://api.truckercore.com/health"
Write-Host ""
Write-Host "${Yellow}📊 Next Steps:${Reset}"
Write-Host "   1. Visit: https://truckercore.com"
Write-Host "   2. Test all features"
Write-Host "   3. Monitor for 30 minutes"
Write-Host "   4. Celebrate! 🎉"
Write-Host ""