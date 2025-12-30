# Optimized Flutter Web Build Script
# Reduces build time and bundle size

Write-Host "Starting optimized Flutter web build..." -ForegroundColor Cyan

# Clean previous build
Write-Host "Cleaning previous build..." -ForegroundColor Yellow
flutter clean

# Get dependencies
Write-Host "Getting dependencies..." -ForegroundColor Yellow
flutter pub get

# Build with optimizations
Write-Host "Building with optimizations..." -ForegroundColor Green
flutter build web --release `
  --tree-shake-icons `
  --no-source-maps `
  -O4 `
  --pwa-strategy none

Write-Host "Build complete!" -ForegroundColor Green
Write-Host "Output: build/web" -ForegroundColor Cyan

# Show bundle size
$bundleSize = (Get-ChildItem -Path "build/web" -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB
Write-Host "Total bundle size: $([math]::Round($bundleSize, 2)) MB" -ForegroundColor Yellow
