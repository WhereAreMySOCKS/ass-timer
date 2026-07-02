$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

flutter pub get
flutter analyze
flutter test
flutter build windows --release

$releaseDir = Join-Path (Get-Location) "releases"
$buildDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"
$zipPath = Join-Path $releaseDir "Ass-Timer-Windows-x64.zip"
New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath }
Copy-Item (Join-Path $PSScriptRoot "WINDOWS_PORTABLE_README.txt") $buildDir
Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath $zipPath
(Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower() |
  Set-Content -NoNewline "$zipPath.sha256"
