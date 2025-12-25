# Step 8 Helper: Create Base Database Schema
# This script helps you set up the initial database for nerd-herd-v2

Write-Host "🗄️  Setting up Nerd Herd V2 Database Schema..." -ForegroundColor Cyan
Write-Host ""

# Check if supabase is installed
$supabaseInstalled = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseInstalled) {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Install it with:" -ForegroundColor Yellow
    Write-Host "  scoop install supabase" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Or download from: https://supabase.com/docs/guides/cli" -ForegroundColor Gray
    exit 1
}

Write-Host "✅ Supabase CLI found" -ForegroundColor Green
Write-Host ""

# Navigate to v2 directory
Set-Location C:\Users\Husse\Documents\nerd-herd-v2

# Check if supabase is initialized
if (-not (Test-Path "supabase")) {
    Write-Host "📁 Initializing Supabase..." -ForegroundColor Yellow
    supabase init
    Write-Host ""
}

Write-Host "🔗 Now you need to link to your Supabase project" -ForegroundColor Cyan
Write-Host ""
Write-Host "Steps:" -ForegroundColor White
Write-Host "1. Go to https://supabase.com/dashboard" -ForegroundColor Gray
Write-Host "2. Find your project 'nerd-herd-v2-dev'" -ForegroundColor Gray
Write-Host "3. Copy the Project Reference ID (Settings > General)" -ForegroundColor Gray
Write-Host ""
Write-Host "Then run:" -ForegroundColor Yellow
Write-Host "  supabase link --project-ref YOUR-PROJECT-ID" -ForegroundColor Gray
Write-Host ""
Write-Host "After linking, run this script again to apply the schema." -ForegroundColor Cyan
