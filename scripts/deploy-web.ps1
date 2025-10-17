# PowerShell script to automate copy -> build -> prerender -> deploy for Windows
# Usage: ./scripts/deploy-web.ps1

Set-StrictMode -Version Latest

Write-Host "Copying favicon..."
node .\scripts\copy_favicon.js
if ($LASTEXITCODE -ne 0) { throw "copy_favicon failed" }

Write-Host "Building Flutter web (this may take a while)..."
flutter build web --release --base-href=/
if ($LASTEXITCODE -ne 0) { throw "flutter build web failed" }

Write-Host "Running prerender script..."
node .\scripts\prerender.js
if ($LASTEXITCODE -ne 0) { throw "prerender failed" }

Write-Host "Deploying to Firebase Hosting..."
firebase deploy --only hosting
if ($LASTEXITCODE -ne 0) { throw "firebase deploy failed" }

Write-Host "Deploy complete."