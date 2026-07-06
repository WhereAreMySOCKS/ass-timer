$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

flutter pub get
flutter analyze
flutter test
flutter build windows --release

$releaseDir = Join-Path (Get-Location) "releases"
$buildDir = Join-Path (Get-Location) "build\windows\x64\runner\Release"
$zipPath = Join-Path $releaseDir "Ass-Timer-Windows-x64.zip"
$runtimeNames = @("msvcp140.dll", "vcruntime140.dll", "vcruntime140_1.dll")

function Find-VcRuntimeDirectory {
  $candidates = @()
  if ($env:VCToolsRedistDir) {
    $candidates += Join-Path $env:VCToolsRedistDir "x64\Microsoft.VC143.CRT"
  }

  $visualStudioRoot = Join-Path ${env:ProgramFiles} "Microsoft Visual Studio\2022"
  if (Test-Path $visualStudioRoot) {
    $candidates += Get-ChildItem $visualStudioRoot -Directory -Recurse -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -like "*VC\Redist\MSVC\*\x64\Microsoft.VC143.CRT" } |
      Sort-Object FullName -Descending |
      Select-Object -ExpandProperty FullName
  }

  foreach ($candidate in $candidates) {
    $missingRuntime = @($runtimeNames | Where-Object {
      -not (Test-Path (Join-Path $candidate $_))
    })
    if ($missingRuntime.Count -gt 0) {
      continue
    }
    return $candidate
  }
  return $null
}

$runtimeDirectory = Find-VcRuntimeDirectory
foreach ($runtime in $runtimeNames) {
  $destination = Join-Path $buildDir $runtime
  if (-not (Test-Path $destination)) {
    if (-not $runtimeDirectory) {
      throw "VC143 x64 runtime not found. Install Visual Studio C++ Redistributable components."
    }
    Copy-Item (Join-Path $runtimeDirectory $runtime) $destination
  }
}

New-Item -ItemType Directory -Force -Path $releaseDir | Out-Null
if (Test-Path $zipPath) { Remove-Item $zipPath }
Copy-Item (Join-Path $PSScriptRoot "WINDOWS_PORTABLE_README.txt") $buildDir

$requiredFiles = @(
  "Ass-Timer.exe",
  "flutter_windows.dll",
  "data\icudtl.dat",
  "data\flutter_assets\AssetManifest.bin",
  "data\flutter_assets\assets\fonts\NotoSansSC-VariableFont_wght.ttf",
  "data\flutter_assets\assets\fonts\OFL.txt",
  "WINDOWS_PORTABLE_README.txt"
) + $runtimeNames
foreach ($required in $requiredFiles) {
  if (-not (Test-Path (Join-Path $buildDir $required))) {
    throw "Release package is incomplete: missing $required"
  }
}

Compress-Archive -Path (Join-Path $buildDir "*") -DestinationPath $zipPath
(Get-FileHash -Algorithm SHA256 $zipPath).Hash.ToLower() |
  Set-Content -NoNewline "$zipPath.sha256"
