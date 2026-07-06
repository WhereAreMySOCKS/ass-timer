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

function Test-VcRuntimeDirectory {
  param([string]$Path)

  if ([string]::IsNullOrWhiteSpace($Path) -or
      -not (Test-Path -LiteralPath $Path -PathType Container)) {
    return $false
  }

  foreach ($runtime in $runtimeNames) {
    if (-not (Test-Path -LiteralPath (Join-Path $Path $runtime) -PathType Leaf)) {
      return $false
    }
  }
  return $true
}

function Get-VcRuntimeCandidates {
  $candidates = [System.Collections.Generic.List[string]]::new()

  # Available in a Visual Studio developer shell. The CRT directory name is
  # intentionally wildcarded because GitHub's windows-latest toolset changes.
  if ($env:VCToolsRedistDir) {
    $x64Root = Join-Path $env:VCToolsRedistDir "x64"
    if (Test-Path -LiteralPath $x64Root -PathType Container) {
      Get-ChildItem -LiteralPath $x64Root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like "Microsoft.VC*.CRT" } |
        ForEach-Object { $candidates.Add($_.FullName) }
    }
  }

  # GitHub-hosted runners provide vswhere even when VCToolsRedistDir is not
  # exported to the PowerShell step.
  $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
  if (Test-Path -LiteralPath $vswhere -PathType Leaf) {
    $installations = @(& $vswhere -all -products * -property installationPath)
    foreach ($installation in $installations) {
      if ([string]::IsNullOrWhiteSpace($installation)) { continue }
      $redistRoot = Join-Path $installation "VC\Redist\MSVC"
      if (-not (Test-Path -LiteralPath $redistRoot -PathType Container)) { continue }

      Get-ChildItem -LiteralPath $redistRoot -Directory -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        ForEach-Object {
          $x64Root = Join-Path $_.FullName "x64"
          if (Test-Path -LiteralPath $x64Root -PathType Container) {
            Get-ChildItem -LiteralPath $x64Root -Directory -ErrorAction SilentlyContinue |
              Where-Object { $_.Name -like "Microsoft.VC*.CRT" } |
              ForEach-Object { $candidates.Add($_.FullName) }
          }
        }
    }
  }

  # A 64-bit GitHub runner already has the matching redistributable installed.
  # Keeping this last makes the Visual Studio redist payload the preferred copy.
  if ($env:WINDIR) {
    $candidates.Add((Join-Path $env:WINDIR "System32"))
  }

  return @($candidates | Select-Object -Unique)
}

function Find-VcRuntimeDirectory {
  $script:runtimeCandidates = @(Get-VcRuntimeCandidates)
  foreach ($candidate in $script:runtimeCandidates) {
    if (Test-VcRuntimeDirectory $candidate) { return $candidate }
  }
  return $null
}

$runtimeDirectory = Find-VcRuntimeDirectory
if (-not $runtimeDirectory) {
  Write-Host "Searched VC runtime directories:"
  $runtimeCandidates | ForEach-Object { Write-Host "  $_" }
  throw "x64 Visual C++ runtime not found. Install the Visual Studio C++ Redistributable components."
}
Write-Host "Using Visual C++ runtime from: $runtimeDirectory"

foreach ($runtime in $runtimeNames) {
  $destination = Join-Path $buildDir $runtime
  if (-not (Test-Path $destination)) {
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
