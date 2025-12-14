$ErrorActionPreference = "Stop"

$flutterUrl = "https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip"
$zipPath = "$env:USERPROFILE\Downloads\flutter.zip"
$extractDest = "$env:USERPROFILE"
$flutterBin = "$extractDest\flutter\bin"

# Write-Host "Downloading Flutter from $flutterUrl..."
# Invoke-WebRequest -Uri $flutterUrl -OutFile $zipPath -UseBasicParsing

Write-Host "Extracting to $extractDest..."
Expand-Archive -Path $zipPath -DestinationPath $extractDest -Force

Write-Host "Adding $flutterBin to User PATH..."
$currentPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($currentPath -notlike "*$flutterBin*") {
    $newPath = "$currentPath;$flutterBin"
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    Write-Host "Path updated."
}
else {
    Write-Host "Path already contains Flutter."
}

Write-Host "Cleaning up zip file..."
Remove-Item $zipPath -Force

Write-Host "Installation complete! YOU MUST RESTART YOUR TERMINAL/VSCODE TO USE FLUTTER."
