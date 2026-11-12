#Requires -Version 7
<#
.SYNOPSIS
    Clone the third-party skill repositories listed in vendor.ini.

.DESCRIPTION
    Each repo is cloned into <VendorDir>/<name> at the pinned commit, and the
    skills it provides are recorded in <VendorDir>/.manifest.json.
    academic-kit.ps1 reads that manifest to link them into the project.

    Upstream licenses stay in their own repositories; nothing is vendored here.
#>
[CmdletBinding()]
param(
    [string]$VendorDir
)

$ErrorActionPreference = 'Stop'
$kitRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
if (-not $VendorDir) { $VendorDir = Join-Path $kitRoot 'vendor' }
$vendorPath = [System.IO.Path]::GetFullPath($VendorDir)
$ini = Join-Path $kitRoot 'vendor.ini'

if (-not (Test-Path $ini)) { throw "vendor.ini not found: $ini" }
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required to fetch third-party skills.' }

function Read-Ini([string]$Path) {
    $current = $null
    $result = [ordered]@{}
    foreach ($line in Get-Content $Path) {
        $trim = $line.Trim()
        if (-not $trim -or $trim.StartsWith('#')) { continue }
        if ($trim -match '^\[(.+)\]$') { $current = $Matches[1]; $result[$current] = @{}; continue }
        if ($current -and $trim -match '^(\w+)\s*=\s*(.*)$') {
            $result[$current][$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $result
}

function Resolve-SkillDirs([string]$RepoDir, [string]$Spec) {
    $found = @()
    foreach ($entry in ($Spec -split ',')) {
        $entry = $entry.Trim()
        if (-not $entry) { continue }
        if ($entry.EndsWith('/*')) {
            $base = Join-Path $RepoDir $entry.Substring(0, $entry.Length - 2)
            if (Test-Path $base) {
                $found += Get-ChildItem $base -Directory |
                    Where-Object { Test-Path (Join-Path $_.FullName 'SKILL.md') }
            }
        } elseif ($entry -eq '.') {
            if (Test-Path (Join-Path $RepoDir 'SKILL.md')) { $found += Get-Item $RepoDir }
        } else {
            $path = Join-Path $RepoDir $entry
            if (Test-Path (Join-Path $path 'SKILL.md')) { $found += Get-Item $path }
        }
    }
    return $found
}

New-Item -ItemType Directory -Force $vendorPath | Out-Null
$sources = Read-Ini $ini
$manifest = [ordered]@{}
$fetched = 0

foreach ($name in $sources.Keys) {
    $meta = $sources[$name]
    $repo = $meta['repo']
    $commit = $meta['commit']
    $dest = Join-Path $vendorPath $name
    if (-not $repo) { continue }

    if (-not (Test-Path (Join-Path $dest '.git'))) {
        Write-Host "fetching $name ..."
        git clone --quiet $repo $dest 2>&1 | Out-Null
        $fetched++
    }
    if ($commit) {
        $head = (git -C $dest rev-parse HEAD 2>$null)
        if ($head -ne $commit) {
            git -C $dest fetch --quiet origin $commit 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) { git -C $dest checkout --quiet $commit 2>&1 | Out-Null }
        }
    }

    $spec = $meta['skills']
    if (-not $spec) { continue }
    foreach ($skill in (Resolve-SkillDirs $dest $spec)) {
        if (-not $manifest.Contains($skill.Name)) { $manifest[$skill.Name] = $skill.FullName }
    }
}

$manifestPath = Join-Path $vendorPath '.manifest.json'
$json = [ordered]@{
    fetchedAt = (Get-Date).ToString('o')
    skills    = $manifest
}
Set-Content -Path $manifestPath -Value ($json | ConvertTo-Json -Depth 5) -Encoding utf8

Write-Host "vendor ready: $($manifest.Count) skills from $($sources.Keys.Count) sources (cloned now: $fetched)"
