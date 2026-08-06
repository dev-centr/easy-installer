#!/usr/bin/env pwsh
# Copy built easy-installer next to shell assets for local modern registration.
$ErrorActionPreference = 'Stop'
$root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $root 'easy-installer.exe'))) {
  $root = Split-Path $PSScriptRoot -Parent
}
$exe = Join-Path $root 'easy-installer.exe'
if (-not (Test-Path $exe)) {
  Write-Host "Build with: dub build --build=release"
  exit 1
}
& $exe shell install
