# Convert PNG/JPG images to WebP format
# Requires: npm install -g sharp-cli

Write-Host "Image Conversion Script - PNG/JPG to WebP" -ForegroundColor Cyan
Write-Host "=" -NoNewline
Write-Host "==========================================================="

# Check if sharp-cli is installed
$sharpInstalled = $null -ne (Get-Command "sharp" -ErrorAction SilentlyContinue)

if (-not $sharpInstalled) {
    Write-Host "Installing sharp-cli for image conversion..." -ForegroundColor Yellow
    npm install -g sharp-cli
}

# Directories to process
$directories = @(
    "assets\leaderboards_rank",
    "assets\storybook_covers",
    "assets\notes_cover"
)

$totalSaved = 0
$filesConverted = 0

foreach ($dir in $directories) {
    if (Test-Path $dir) {
        Write-Host ""
        Write-Host "Processing: $dir" -ForegroundColor Green
        
        $images = Get-ChildItem -Path $dir -Filter "*.png"
        $images += Get-ChildItem -Path $dir -Filter "*.jpg"
        $images += Get-ChildItem -Path $dir -Filter "*.jpeg"
        
        foreach ($img in $images) {
            $originalSize = $img.Length
            $outputPath = $img.FullName -replace '\.(png|jpg|jpeg)$', '.webp'
            
            # Skip if WebP already exists and is newer
            if ((Test-Path $outputPath) -and ((Get-Item $outputPath).LastWriteTime -gt $img.LastWriteTime)) {
                Write-Host "  Skipping (already converted): $($img.Name)" -ForegroundColor Gray
                continue
            }
            
            try {
                # Use sharp-cli for conversion (quality 90 for great balance)
                & sharp -i $img.FullName -o $outputPath --webp --quality 90 2>&1 | Out-Null
                
                if (Test-Path $outputPath) {
                    $newSize = (Get-Item $outputPath).Length
                    $saved = $originalSize - $newSize
                    $savingPercent = [math]::Round(($saved / $originalSize) * 100, 1)
                    
                    $totalSaved += $saved
                    $filesConverted++
                    
                    Write-Host "  Converted: $($img.Name)" -ForegroundColor Green
                    Write-Host "     Original: $([math]::Round($originalSize/1KB, 1)) KB to WebP: $([math]::Round($newSize/1KB, 1)) KB ($savingPercent% smaller)" -ForegroundColor White
                }
                else {
                    Write-Host "  Failed to convert: $($img.Name)" -ForegroundColor Red
                }
            }
            catch {
                Write-Host "  Error converting $($img.Name): $_" -ForegroundColor Red
            }
        }
    }
    else {
        Write-Host ""
        Write-Host "Directory not found: $dir" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "==========================================================="
Write-Host "Conversion Complete!" -ForegroundColor Cyan
Write-Host "Files converted: $filesConverted" -ForegroundColor Green
Write-Host "Total space saved: $([math]::Round($totalSaved/1MB, 2)) MB" -ForegroundColor Green
Write-Host ""
Write-Host "Remember to update image references in your code" -ForegroundColor Yellow
