# Nerd Herd V2 Setup Script
# Run this script to automatically set up the nerd-herd-v2 repository

param(
    [Parameter(Mandatory=$true)]
    [string]$GitHubUsername,
    
    [Parameter(Mandatory=$false)]
    [string]$StartOption = "fresh"  # "fresh" or "fork"
)

Write-Host "🚀 Setting up Nerd Herd V2 Repository..." -ForegroundColor Cyan
Write-Host ""

# Step 1: Create directory
Write-Host "📁 Creating nerd-herd-v2 directory..." -ForegroundColor Yellow
$v2Path = "C:\Users\Husse\Documents\nerd-herd-v2"

if (Test-Path $v2Path) {
    Write-Host "⚠️  Directory already exists. Delete it first? (y/n)" -ForegroundColor Red
    $response = Read-Host
    if ($response -eq 'y') {
        Remove-Item -Recurse -Force $v2Path
    } else {
        Write-Host "❌ Aborting setup." -ForegroundColor Red
        exit 1
    }
}

New-Item -ItemType Directory -Path $v2Path | Out-Null
Set-Location $v2Path

# Step 2: Initialize Git
Write-Host "🔧 Initializing Git repository..." -ForegroundColor Yellow
git init
git branch -M main

# Step 3: Copy files based on option
if ($StartOption -eq "fresh") {
    Write-Host "📋 Copying essential files only (fresh start)..." -ForegroundColor Yellow
    
    # Copy config files
    Copy-Item ..\Anti\pubspec.yaml .
    Copy-Item ..\Anti\analysis_options.yaml .
    Copy-Item ..\Anti\.gitignore .
    Copy-Item ..\Anti\.env . -ErrorAction SilentlyContinue
    
    # Copy models
    New-Item -ItemType Directory -Path lib\models -Force | Out-Null
    Copy-Item ..\Anti\lib\models\*.dart lib\models\ -ErrorAction SilentlyContinue
    
    # Copy config
    New-Item -ItemType Directory -Path lib\config -Force | Out-Null
    Copy-Item ..\Anti\lib\config\*.dart lib\config\ -ErrorAction SilentlyContinue
    
    # Copy assets
    if (Test-Path ..\Anti\assets) {
        Copy-Item -Recurse ..\Anti\assets .
    }
    
    # Create basic structure
    New-Item -ItemType Directory -Path lib\pages -Force | Out-Null
    New-Item -ItemType Directory -Path lib\widgets -Force | Out-Null
    New-Item -ItemType Directory -Path lib\services -Force | Out-Null
    New-Item -ItemType Directory -Path lib\pages\serendipity -Force | Out-Null
    
} else {
    Write-Host "📋 Copying entire v1 codebase (fork)..." -ForegroundColor Yellow
    Copy-Item -Recurse ..\Anti\* . -Exclude .git,build,.dart_tool,node_modules,.idea
}

# Step 4: Update pubspec.yaml
Write-Host "📝 Updating pubspec.yaml..." -ForegroundColor Yellow
$pubspecContent = Get-Content pubspec.yaml -Raw
$pubspecContent = $pubspecContent -replace "name: nerd_herd", "name: nerd_herd_v2"
$pubspecContent = $pubspecContent -replace "description:.*", "description: Nerd Herd 2.0 with AI-powered Serendipity Engine"
$pubspecContent = $pubspecContent -replace "version:.*", "version: 2.0.0+1"
Set-Content pubspec.yaml $pubspecContent

# Step 5: Create README
Write-Host "📄 Creating README.md..." -ForegroundColor Yellow
$readmeContent = @"
# Nerd Herd 2.0 🧠

AI-powered campus social network with the **Serendipity Engine**.

## What's New in V2.0

### The Serendipity Engine
- **Contextual Proximity Alerts**: Get notified when someone nearby can help
- **Study Constellation**: AI finds optimal study groups
- **Temporal Pattern Matching**: Connect with peers in your golden hours

## Quick Start

``````bash
flutter pub get
flutter run
``````

## Documentation
- [Serendipity Engine Strategy](docs/SERENDIPITY_ENGINE_STRATEGY.md)
- [Implementation Plan](docs/SERENDIPITY_IMPLEMENTATION.md)
- [Setup Guide](docs/V2_SETUP_GUIDE.md)

## Repository
Separate from v1.0 for maximum safety and clean development.
"@
Set-Content README.md $readmeContent

# Step 6: Copy documentation
Write-Host "📚 Copying documentation..." -ForegroundColor Yellow
if (-not (Test-Path docs)) {
    New-Item -ItemType Directory -Path docs | Out-Null
}
Copy-Item ..\Anti\docs\SERENDIPITY_*.md docs\ -ErrorAction SilentlyContinue
Copy-Item ..\Anti\docs\V2_*.md docs\ -ErrorAction SilentlyContinue
Copy-Item ..\Anti\docs\DEPLOYMENT_OPTIONS_COMPARISON.md docs\ -ErrorAction SilentlyContinue

# Step 7: Create initial commit
Write-Host "💾 Creating initial commit..." -ForegroundColor Yellow
git add .
git commit -m "Initial commit: Nerd Herd 2.0 base structure

- Copied essential files from v1.0
- Updated pubspec.yaml for v2.0
- Added Serendipity Engine documentation
- Set up project structure for AI/ML features"

# Step 8: Add remote
Write-Host "🔗 Adding GitHub remote..." -ForegroundColor Yellow
$repoUrl = "https://github.com/$GitHubUsername/nerd-herd-v2.git"
git remote add origin $repoUrl

Write-Host ""
Write-Host "✅ Setup complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "1. Create the repository on GitHub: https://github.com/new" -ForegroundColor White
Write-Host "   - Name: nerd-herd-v2" -ForegroundColor White
Write-Host "   - Private: Yes" -ForegroundColor White
Write-Host "   - Do NOT initialize with README" -ForegroundColor White
Write-Host ""
Write-Host "2. Push to GitHub:" -ForegroundColor White
Write-Host "   git push -u origin main" -ForegroundColor Gray
Write-Host ""
Write-Host "3. Set up Supabase project:" -ForegroundColor White
Write-Host "   - Go to https://supabase.com/dashboard" -ForegroundColor Gray
Write-Host "   - Create new project: nerd-herd-v2-dev" -ForegroundColor Gray
Write-Host ""
Write-Host "4. Update .env file with new Supabase credentials" -ForegroundColor White
Write-Host ""
Write-Host "Repository location: $v2Path" -ForegroundColor Cyan
