# Quick Fix Script for Empty Repository
# Run this to create the initial commit

Write-Host "🔧 Fixing empty repository..." -ForegroundColor Cyan

# Check if we're in the right directory
$currentPath = Get-Location
if ($currentPath.Path -notlike "*nerd-herd-v2*") {
    Write-Host "⚠️  Not in nerd-herd-v2 directory. Navigating there..." -ForegroundColor Yellow
    Set-Location C:\Users\Husse\Documents\nerd-herd-v2
}

# Check if directory has any files
$fileCount = (Get-ChildItem -File -Recurse | Measure-Object).Count
Write-Host "📁 Found $fileCount files in directory" -ForegroundColor White

if ($fileCount -eq 0) {
    Write-Host "❌ Directory is empty! Need to copy files first." -ForegroundColor Red
    Write-Host ""
    Write-Host "Run the setup script first:" -ForegroundColor Yellow
    Write-Host "  cd C:\Users\Husse\Documents\Anti" -ForegroundColor Gray
    Write-Host "  .\scripts\setup_v2_repo.ps1 -GitHubUsername 'YOUR-USERNAME'" -ForegroundColor Gray
    exit 1
}

# Add all files
Write-Host "📝 Adding all files to git..." -ForegroundColor Yellow
git add .

# Check if there are files to commit
$status = git status --short
if ([string]::IsNullOrWhiteSpace($status)) {
    Write-Host "⚠️  No changes to commit. Files might already be committed." -ForegroundColor Yellow
    
    # Check commit history
    $commitCount = git rev-list --count HEAD 2>$null
    if ($commitCount -gt 0) {
        Write-Host "✅ Repository already has $commitCount commit(s)" -ForegroundColor Green
        Write-Host ""
        Write-Host "Try pushing again:" -ForegroundColor Cyan
        Write-Host "  git push -u origin main" -ForegroundColor Gray
        exit 0
    }
}

# Create initial commit
Write-Host "💾 Creating initial commit..." -ForegroundColor Yellow
git commit -m "Initial commit: Nerd Herd 2.0 base structure

- Set up project structure for v2.0
- Added Serendipity Engine documentation
- Prepared for AI/ML feature development"

Write-Host ""
Write-Host "✅ Commit created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "Next step - Push to GitHub:" -ForegroundColor Cyan
Write-Host "  git push -u origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "If you get authentication errors, use GitHub Desktop instead:" -ForegroundColor Yellow
Write-Host "  https://desktop.github.com/" -ForegroundColor Gray
