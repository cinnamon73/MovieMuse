# Movie Picker - Environment Setup (PowerShell)

Write-Host "🎬 Movie Picker - Environment Setup" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan

# Check if .env file already exists
if (Test-Path ".env") {
    Write-Host "⚠️  .env file already exists!" -ForegroundColor Yellow
    Write-Host "If you want to update it, please edit it manually or delete it first." -ForegroundColor Yellow
    exit 1
}

# Create .env file
Write-Host "📝 Creating .env file..." -ForegroundColor Green

$envContent = @"
# TMDB API Configuration
# Get your API key from: https://www.themoviedb.org/settings/api
TMDB_API_KEY=f26e4183a1a1ea7149cfb88dd01979bb

# Note: This file should never be committed to version control
# Make sure .env is in your .gitignore file
"@

$envContent | Out-File -FilePath ".env" -Encoding UTF8

Write-Host "✅ .env file created successfully!" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Next steps:" -ForegroundColor Cyan
Write-Host "1. Get your own TMDB API key from: https://www.themoviedb.org/settings/api" -ForegroundColor White
Write-Host "2. Replace the API key in .env file with your own key" -ForegroundColor White
Write-Host "3. Run: flutter pub get" -ForegroundColor White
Write-Host "4. Run: flutter run" -ForegroundColor White
Write-Host ""
Write-Host "⚠️  IMPORTANT: Never commit your .env file to version control!" -ForegroundColor Red
Write-Host "   The .env file has been added to .gitignore for your safety." -ForegroundColor Red 