#Requires -Version 7
<#
.SYNOPSIS
    Install or remove a portable academic-writing kit for Claude Code.

.DESCRIPTION
    Writes four things into a project folder:
      .claude/skills/        skills (junction or copy)
      .claude/settings.json  plugins (project scope)
      .claude/CLAUDE.md      writing rules
      .mcp.json              MCP servers

    Nothing is global. A project without these files sees none of it.

.PARAMETER Project
    Target project folder. Default: current directory.

.PARAMETER Profile
    ringkas | riset | lengkap. See profiles.ini.

.PARAMETER ThesisRoot
    Manuscript folder when it differs from the project root (monorepo).

.PARAMETER Portable
    Copy skills instead of linking, so the folder can be moved to another machine.

.PARAMETER Off
    Remove everything the kit installed.

.PARAMETER Status
    Show what is installed in the project.

.PARAMETER NoVendor
    Skip cloning third-party skill repositories (faster, fewer skills).

.EXAMPLE
    ./academic-kit.ps1 -Project D:\skripsi
.EXAMPLE
    ./academic-kit.ps1 -Project D:\skripsi -Profile lengkap -Portable
.EXAMPLE
    ./academic-kit.ps1 -Project D:\skripsi -Off
#>
[CmdletBinding()]
param(
    [string]$Project = (Get-Location).Path,
    [ValidateSet('ringkas', 'riset', 'lengkap')]
    [string]$Profile = 'ringkas',
    [string]$ThesisRoot,
    [switch]$Portable,
    [switch]$Off,
    [switch]$Status,
    [switch]$NoVendor
)

$ErrorActionPreference = 'Stop'

$kit = $PSScriptRoot
if (-not (Test-Path (Join-Path $kit 'skills'))) { throw "Kit not found at: $kit" }
if (-not (Test-Path -LiteralPath $Project)) { throw "Project folder does not exist: $Project" }

# GetFullPath keeps the long form; Resolve-Path can return an 8.3 short name
# (IBNUHA~1) that other tools cannot follow.
$projectPath = if ([System.IO.Path]::IsPathRooted($Project)) { $Project } else { Join-Path (Get-Location).Path $Project }
$projectPath = [System.IO.Path]::GetFullPath($projectPath)
if (-not (Test-Path -LiteralPath $projectPath)) { throw "Project folder does not exist: $projectPath" }
$claudeDir = Join-Path $projectPath '.claude'
$skillsDir = Join-Path $claudeDir 'skills'
$mcpFile = Join-Path $projectPath '.mcp.json'
$manifestFile = Join-Path $claudeDir '.academic-kit.json'
$settingsFile = Join-Path $claudeDir 'settings.json'
$claudeMd = Join-Path $claudeDir 'CLAUDE.md'
$thesisPath = $projectPath
if ($ThesisRoot) {
    $t = if ([System.IO.Path]::IsPathRooted($ThesisRoot)) { $ThesisRoot } else { Join-Path $projectPath $ThesisRoot }
    $thesisPath = [System.IO.Path]::GetFullPath($t)
    if (-not (Test-Path -LiteralPath $thesisPath)) { throw "Thesis folder does not exist: $thesisPath" }
}

$mcpNames = @('zotero', 'arxiv', 'academic-research', 'thesis-latex')
$gitStart = '# >>> academic-kit'
$gitEnd = '# <<< academic-kit'

function Read-Json([string]$Path) {
    if (Test-Path $Path) { Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable } else { @{} }
}

function Write-Json([string]$Path, $Object) {
    Set-Content -Path $Path -Value ($Object | ConvertTo-Json -Depth 20) -Encoding utf8
}

function Get-Profile([string]$Name) {
    $file = Join-Path $kit 'profiles.ini'
    if (-not (Test-Path $file)) { throw "profiles.ini missing: $file" }
    $current = $null
    $result = @{}
    foreach ($line in Get-Content $file) {
        $trim = $line.Trim()
        if (-not $trim -or $trim.StartsWith('#')) { continue }
        if ($trim -match '^\[(.+)\]$') { $current = $Matches[1]; $result[$current] = @(); continue }
        if ($current) { $result[$current] += $trim }
    }
    if (-not $result.ContainsKey($Name)) { throw "Profile '$Name' not found in profiles.ini" }
    return @($result[$Name])
}

function Get-InstalledSkills {
    if (-not (Test-Path $skillsDir)) { return @() }
    return @(Get-ChildItem $skillsDir -Directory | ForEach-Object { $_.Name })
}

# ---------- STATUS ----------
if ($Status) {
    $manifest = if (Test-Path $manifestFile) { Read-Json $manifestFile } else { @{} }
    $plugins = if (Test-Path $settingsFile) { @((Read-Json $settingsFile).enabledPlugins.Keys) } else { @() }
    $mcp = if (Test-Path $mcpFile) { @((Read-Json $mcpFile).mcpServers.Keys) } else { @() }
    Write-Host "Project : $projectPath"
    Write-Host "Profile : $($manifest.profile)  (portable: $($manifest.portable))"
    Write-Host "Skills  : $((Get-InstalledSkills).Count)"
    Write-Host "Plugins : $($plugins.Count)"
    Write-Host "MCP     : $($mcp.Count)  [$($mcp -join ', ')]"
    return
}

# ---------- OFF ----------
if ($Off) {
    $manifest = if (Test-Path $manifestFile) { Read-Json $manifestFile } else { @{} }
    $installed = if ($manifest.skills) { @($manifest.skills) } else { Get-InstalledSkills }
    $removed = 0

    foreach ($name in $installed) {
        $path = Join-Path $skillsDir $name
        if (-not (Test-Path $path)) { continue }
        $item = Get-Item $path -Force
        # Never touch a skill the user added themselves.
        if ($item.LinkType -eq 'Junction' -and $item.Target -notlike "$kit*") { continue }
        Remove-Item $path -Recurse -Force
        $removed++
    }

    if (Test-Path $mcpFile) {
        $mcp = Read-Json $mcpFile
        if ($mcp.mcpServers) {
            foreach ($name in $mcpNames) { if ($mcp.mcpServers.ContainsKey($name)) { $mcp.mcpServers.Remove($name) } }
            if ($mcp.mcpServers.Count -eq 0) { Remove-Item $mcpFile -Force } else { Write-Json $mcpFile $mcp }
        }
    }

    if (Test-Path $claudeMd) {
        $text = Get-Content $claudeMd -Raw
        if ($text.Contains('<!-- academic-kit:start -->')) {
            $pattern = '(?s)' + [regex]::Escape('<!-- academic-kit:start -->') + '.*?' + [regex]::Escape('<!-- academic-kit:end -->') + '\r?\n?'
            $text = [regex]::Replace($text, $pattern, '')
            if ($text.Trim()) { Set-Content $claudeMd $text -Encoding utf8 -NoNewline } else { Remove-Item $claudeMd -Force }
        }
    }

    $plugins = if ($manifest.plugins) { @($manifest.plugins) } else { @() }
    if ($plugins.Count) {
        Push-Location $projectPath
        foreach ($p in $plugins) { claude plugin uninstall $p --scope project 2>&1 | Out-Null }
        Pop-Location
    }
    if (Test-Path $manifestFile) { Remove-Item $manifestFile -Force }

    if (Test-Path $settingsFile) {
        $s = Read-Json $settingsFile
        $keys = @($s.Keys)
        if ($keys.Count -eq 1 -and $keys[0] -eq 'enabledPlugins' -and @($s.enabledPlugins.Keys).Count -eq 0) {
            Remove-Item $settingsFile -Force
        }
    }

    $gitignore = Join-Path $projectPath '.gitignore'
    if (Test-Path $gitignore) {
        $text = Get-Content $gitignore -Raw
        if ($text.Contains($gitStart)) {
            $pattern = '(?s)\r?\n?' + [regex]::Escape($gitStart) + '.*?' + [regex]::Escape($gitEnd) + '\r?\n?'
            $text = [regex]::Replace($text, $pattern, '').TrimEnd()
            if ($text) { Set-Content $gitignore $text -Encoding utf8 -NoNewline } else { Remove-Item $gitignore -Force }
        }
    }

    foreach ($dir in @($skillsDir, $claudeDir)) {
        if ((Test-Path $dir) -and -not (Get-ChildItem $dir -Force)) { Remove-Item $dir -Force }
    }

    Write-Host "Kit removed from $projectPath ($removed skills deleted)."
    return
}

# ---------- ON ----------
$profilePlugins = Get-Profile $Profile

# Third-party skills are cloned rather than bundled: each upstream keeps its
# own license, and this repo stays small.
$vendorDir = Join-Path $kit 'vendor'
if (-not $NoVendor) {
    $vendorScript = Join-Path $kit 'scripts\fetch-vendor.ps1'
    if (Test-Path $vendorScript) { & $vendorScript -VendorDir $vendorDir }
}

if (-not (Test-Path $skillsDir)) { New-Item -ItemType Directory -Force $skillsDir | Out-Null }

$linked = 0; $copied = 0; $skipped = 0
$skillNames = @()

# Skills that live in this repo.
$localSkillRoots = @(Get-ChildItem (Join-Path $kit 'skills') -Directory)
# Skills fetched from third-party repos, recorded by fetch-vendor.ps1.
$vendorManifest = Join-Path $vendorDir '.manifest.json'
$vendorSkills = @()
if (Test-Path $vendorManifest) {
    $vm = Read-Json $vendorManifest
    foreach ($entry in $vm.skills.GetEnumerator()) {
        $vendorSkills += [pscustomobject]@{ Name = $entry.Key; Source = [string]$entry.Value }
    }
}

$allSkills = @()
foreach ($s in $localSkillRoots) { $allSkills += [pscustomobject]@{ Name = $s.Name; Source = $s.FullName } }
foreach ($s in $vendorSkills) { if (-not ($allSkills | Where-Object Name -eq $s.Name)) { $allSkills += $s } }

foreach ($skill in $allSkills) {
    $skillNames += $skill.Name
    $target = Join-Path $skillsDir $skill.Name
    if (Test-Path $target) { $skipped++; continue }
    if ($Portable) { Copy-Item $skill.Source $target -Recurse -Force; $copied++ }
    else { New-Item -ItemType Junction -Path $target -Target $skill.Source | Out-Null; $linked++ }
}

# MCP
# thesis-latex needs fastmcp; give it a private venv so the host Python stays untouched.
$venvPython = Join-Path $kit '.venv\Scripts\python.exe'
if (-not (Test-Path $venvPython)) { $venvPython = Join-Path $kit '.venv\bin\python' }
if (-not (Test-Path $venvPython)) {
    $py = Get-Command python -ErrorAction SilentlyContinue
    if ($py) {
        Write-Host 'preparing the thesis-latex venv (fastmcp) ...'
        & $py.Source -m venv (Join-Path $kit '.venv') 2>&1 | Out-Null
        $candidate = Join-Path $kit '.venv\Scripts\python.exe'
        if (-not (Test-Path $candidate)) { $candidate = Join-Path $kit '.venv\bin\python' }
        if (Test-Path $candidate) {
            $venvPython = $candidate
            & $venvPython -m pip install --quiet --upgrade pip 2>&1 | Out-Null
            & $venvPython -m pip install --quiet fastmcp 2>&1 | Out-Null
        }
    }
}

$kitMcp = Read-Json (Join-Path $kit 'mcp.json')
foreach ($name in $kitMcp.mcpServers.Keys) {
    $server = $kitMcp.mcpServers[$name]
    if ($server.command -eq '{{KIT_PYTHON}}') {
        if (Test-Path $venvPython) { $server.command = $venvPython }
        else { $server.command = (Get-Command python -ErrorAction Stop).Source }
    }
    if ($server.args) {
        $server.args = @($server.args | ForEach-Object {
            if ($_ -eq '{{KIT_SCRIPT}}') { Join-Path $kit 'latex\latex_mcp.py' } else { $_ }
        })
    }
    $server.env = if ($server.env) { $server.env } else { @{} }
    if ($name -eq 'thesis-latex') { $server.env['THESIS_ROOT'] = $thesisPath }
}
$mcp = Read-Json $mcpFile
if (-not $mcp.ContainsKey('mcpServers')) { $mcp['mcpServers'] = @{} }
foreach ($name in $kitMcp.mcpServers.Keys) { $mcp.mcpServers[$name] = $kitMcp.mcpServers[$name] }
Write-Json $mcpFile $mcp

# Rules
$rulesFile = Join-Path $kit 'rules\academic-writing.md'
$block = "<!-- academic-kit:start -->`n$(Get-Content $rulesFile -Raw)`n<!-- academic-kit:end -->"
$existing = if (Test-Path $claudeMd) { Get-Content $claudeMd -Raw } else { '' }
if ($existing.Contains('<!-- academic-kit:start -->')) {
    $pattern = '(?s)' + [regex]::Escape('<!-- academic-kit:start -->') + '.*?' + [regex]::Escape('<!-- academic-kit:end -->')
    $existing = [regex]::Replace($existing, $pattern, $block.Replace('$', '$$'))
} else {
    $existing = if ($existing.Trim()) { "$existing`n`n$block" } else { $block }
}
Set-Content $claudeMd $existing -Encoding utf8 -NoNewline

# Plugins
Push-Location $projectPath
$pluginOk = 0; $failed = @()

$allManaged = @(
    (Get-Profile 'ringkas') + (Get-Profile 'riset') + (Get-Profile 'lengkap') |
        Select-Object -Unique
)
foreach ($id in $allManaged) {
    if ($profilePlugins -notcontains $id) { claude plugin uninstall $id --scope project 2>&1 | Out-Null }
}

foreach ($id in $profilePlugins) {
    $ok = $false
    foreach ($attempt in 1..2) {
        $result = claude plugin install $id --scope project 2>&1 | Out-String
        if ($result -match 'Successfully installed|already installed|already enabled') { $ok = $true; break }
    }
    if ($ok) { $pluginOk++ } else { $failed += $id }
}
Pop-Location

# Manifest + gitignore
Write-Json $manifestFile ([ordered]@{
    profile  = $Profile
    portable = [bool]$Portable
    skills   = $skillNames
    plugins  = $profilePlugins
})

$gitignore = Join-Path $projectPath '.gitignore'
$isRepo = (Test-Path (Join-Path $projectPath '.git')) -or (Test-Path $gitignore)
if ($isRepo) {
    $text = if (Test-Path $gitignore) { Get-Content $gitignore -Raw } else { '' }
    $gitBlock = @(
        $gitStart
        '# Local, per-machine. Do not commit.'
        '.claude/'
        '.mcp.json'
        $gitEnd
    ) -join "`n"
    if ($text.Contains($gitStart)) {
        $pattern = '(?s)' + [regex]::Escape($gitStart) + '.*?' + [regex]::Escape($gitEnd)
        $text = [regex]::Replace($text, $pattern, $gitBlock.Replace('$', '$$'))
    } else {
        $text = if ($text.Trim()) { "$($text.TrimEnd())`n`n$gitBlock`n" } else { "$gitBlock`n" }
    }
    Set-Content $gitignore $text -Encoding utf8 -NoNewline
}

Write-Host "Academic kit installed in $projectPath"
Write-Host "  profile : $Profile"
Write-Host "  skills  : $linked linked, $copied copied, $skipped already present"
Write-Host "  plugins : $pluginOk/$($profilePlugins.Count)"
Write-Host "  MCP     : $($mcpNames.Count)"
if ($thesisPath -ne $projectPath) { Write-Host "  thesis  : $thesisPath" }
if ($Portable) { Write-Host "  mode    : portable (self-contained folder)" }
if ($failed.Count) { Write-Host "  FAILED  : $($failed -join ', ')" -ForegroundColor Yellow }
Write-Host "Open Claude Code in that folder: /mcp to approve, /plugin to verify."
