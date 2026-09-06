param (
    [string]$Message = "chore: automated deployment sync"
)

Write-Host "=============================================" -ForegroundColor Cyan
Write-Host " 🚀 GIGA RIDE AUTO-DEPLOYMENT PIPELINE" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan

# 1. Commit and push to Git
Write-Host "`n[1/3] Committing and pushing changes to GitHub..." -ForegroundColor Yellow
git add .
$status = git status --porcelain
if ($status) {
    git commit -m "$Message"
}
git push origin main
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Git push failed. Aborting deployment." -ForegroundColor Red
    exit 1
}
Write-Host "✓ GitHub repository updated." -ForegroundColor Green

# 2. Remote VPS deployment over SSH
Write-Host "`n[2/3] Deploying on VPS (69.62.127.50)..." -ForegroundColor Yellow
$remoteCommands = "cd /var/www/giga && git pull origin main && cp -f nginx/engine.getgigaride.com.conf /etc/nginx/sites-available/engine.getgigaride.com && ln -sf /etc/nginx/sites-available/engine.getgigaride.com /etc/nginx/sites-enabled/ && nginx -t && systemctl reload nginx && cd backend && npm run build && pm2 reload all"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 root@69.62.127.50 "$remoteCommands"

if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Remote build & PM2 reload succeeded on VPS." -ForegroundColor Green
} else {
    Write-Host "⚠️ Direct SSH execution returned exit code $LASTEXITCODE. Please verify authorized_keys on VPS." -ForegroundColor Yellow
}

# 3. Health check verification
Write-Host "`n[3/3] Verifying live health..." -ForegroundColor Yellow
try {
    $ipHealth = Invoke-RestMethod -Uri "http://69.62.127.50/health" -TimeoutSec 5
    Write-Host "✓ VPS IP Health Check: $($ipHealth.status) ($($ipHealth.platform))" -ForegroundColor Green
} catch {
    Write-Host "⚠️ Could not reach http://69.62.127.50/health: $_" -ForegroundColor Yellow
}

try {
    $domainHealth = Invoke-RestMethod -Uri "https://engine.getgigaride.com/health" -TimeoutSec 5
    Write-Host "✓ Domain Health Check (engine.getgigaride.com): $($domainHealth.status)" -ForegroundColor Green
} catch {
    Write-Host "ℹ️ Domain https://engine.getgigaride.com/health awaiting DNS propagation / SSL." -ForegroundColor Cyan
}

Write-Host "`n=============================================" -ForegroundColor Cyan
Write-Host " 🎉 DEPLOYMENT COMPLETED" -ForegroundColor Cyan
Write-Host "=============================================" -ForegroundColor Cyan
