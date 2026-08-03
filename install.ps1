[CmdletBinding()]
param(
    [string]$Protocol = $env:RCLI_GIT_PROTOCOL,
    [string]$LatestUrl = "https://raw.githubusercontent.com/ackwest/reachcollective-cli-installer/main/latest.json",
    [string]$SshRepository = "ssh://git@github.com/ackwest/reachcollective-cli.git",
    [string]$HttpsRepository = "https://github.com/ackwest/reachcollective-cli.git"
)

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

function Write-InstallerMessage {
    param([Parameter(Mandatory = $true)][string]$Message)

    Write-Host $Message
}

function Throw-InstallerError {
    param([Parameter(Mandatory = $true)][string]$Message)

    throw "rcli installer: $Message"
}

function Enable-Tls12 {
    if (-not ([Net.ServicePointManager]::SecurityProtocol -band [Net.SecurityProtocolType]::Tls12)) {
        [Net.ServicePointManager]::SecurityProtocol =
            [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    }
}

function Find-Application {
    param([Parameter(Mandatory = $true)][string]$Name)

    $command = Get-Command $Name -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($null -eq $command) {
        return $null
    }
    return $command.Source
}

function Find-Uv {
    $uvPath = Find-Application "uv"
    if ($uvPath) {
        return $uvPath
    }

    $candidates = @(
        (Join-Path $HOME ".local\bin\uv.exe"),
        (Join-Path $env:USERPROFILE ".local\bin\uv.exe")
    ) | Select-Object -Unique

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate -PathType Leaf)) {
            return $candidate
        }
    }
    return $null
}

function Install-Uv {
    $uvPath = Find-Uv
    if ($uvPath) {
        return $uvPath
    }

    Write-InstallerMessage "Installing uv..."
    try {
        $installer = Invoke-RestMethod -Uri "https://astral.sh/uv/install.ps1"
        Invoke-Expression $installer | Out-Null
    }
    catch {
        Throw-InstallerError "unable to install uv. $($_.Exception.Message)"
    }

    $uvPath = Find-Uv
    if (-not $uvPath) {
        Throw-InstallerError "uv was installed but uv.exe could not be found."
    }
    return $uvPath
}

function Get-StableVersionFromManifest {
    param([Parameter(Mandatory = $true)]$Manifest)

    $version = [string]($Manifest.version)
    if (-not $version) {
        Throw-InstallerError "latest.json does not contain a version."
    }
    if ($version -notmatch '^\d+\.\d+\.\d+$') {
        Throw-InstallerError "latest.json contains an invalid version: $version"
    }
    return $version
}

function Get-LatestVersion {
    param([Parameter(Mandatory = $true)][string]$Url)

    try {
        $manifest = Invoke-RestMethod -Uri $Url
    }
    catch {
        Throw-InstallerError "unable to download latest.json. $($_.Exception.Message)"
    }
    return Get-StableVersionFromManifest $manifest
}

function Resolve-ProtocolChoice {
    param([AllowEmptyString()][string]$Choice)

    $normalizedChoice = ([string]$Choice).Trim().ToLowerInvariant()
    switch ($normalizedChoice) {
        { $_ -in @("", "1", "ssh") } { return "ssh" }
        { $_ -in @("2", "https") } { return "https" }
        default { Throw-InstallerError "invalid Git protocol selection: $Choice" }
    }
}

function Test-InteractiveConsole {
    if (-not [Environment]::UserInteractive) {
        return $false
    }
    try {
        return -not [Console]::IsInputRedirected
    }
    catch {
        return $false
    }
}

function Test-RepositoryAccess {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [Parameter(Mandatory = $true)][string]$Repository,
        [switch]$NonInteractive
    )

    $previousTerminalPrompt = $env:GIT_TERMINAL_PROMPT
    $previousGcmInteractive = $env:GCM_INTERACTIVE
    try {
        if ($NonInteractive) {
            $env:GIT_TERMINAL_PROMPT = "0"
            $env:GCM_INTERACTIVE = "Never"
        }
        & $GitPath ls-remote $Repository HEAD 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    }
    finally {
        if ($null -eq $previousTerminalPrompt) {
            Remove-Item Env:GIT_TERMINAL_PROMPT -ErrorAction SilentlyContinue
        }
        else {
            $env:GIT_TERMINAL_PROMPT = $previousTerminalPrompt
        }
        if ($null -eq $previousGcmInteractive) {
            Remove-Item Env:GCM_INTERACTIVE -ErrorAction SilentlyContinue
        }
        else {
            $env:GCM_INTERACTIVE = $previousGcmInteractive
        }
    }
}

function Select-GitProtocol {
    param(
        [Parameter(Mandatory = $true)][string]$GitPath,
        [AllowEmptyString()][string]$RequestedProtocol,
        [Parameter(Mandatory = $true)][string]$SshUrl,
        [Parameter(Mandatory = $true)][string]$HttpsUrl
    )

    if ($RequestedProtocol) {
        return Resolve-ProtocolChoice $RequestedProtocol
    }

    if (Test-InteractiveConsole) {
        Write-Host ""
        Write-Host "Git protocol:"
        Write-Host "  1) SSH"
        Write-Host "  2) HTTPS"
        $choice = Read-Host "Select [1]"
        return Resolve-ProtocolChoice $choice
    }

    if (Test-RepositoryAccess $GitPath $SshUrl -NonInteractive) {
        return "ssh"
    }
    if (Test-RepositoryAccess $GitPath $HttpsUrl -NonInteractive) {
        return "https"
    }
    Throw-InstallerError "unable to access the private CLI repository with SSH or HTTPS."
}

function Get-RepositoryForProtocol {
    param(
        [Parameter(Mandatory = $true)][ValidateSet("ssh", "https")][string]$SelectedProtocol,
        [Parameter(Mandatory = $true)][string]$SshUrl,
        [Parameter(Mandatory = $true)][string]$HttpsUrl
    )

    if ($SelectedProtocol -eq "ssh") {
        return $SshUrl
    }
    return $HttpsUrl
}

function Invoke-RcliInstaller {
    param(
        [AllowEmptyString()][string]$RequestedProtocol,
        [Parameter(Mandatory = $true)][string]$ManifestUrl,
        [Parameter(Mandatory = $true)][string]$SshUrl,
        [Parameter(Mandatory = $true)][string]$HttpsUrl
    )

    Enable-Tls12

    $gitPath = Find-Application "git"
    if (-not $gitPath) {
        Throw-InstallerError "Git for Windows is required. Install it from https://git-scm.com/download/win, restart PowerShell, and run this installer again."
    }

    $uvPath = Install-Uv
    $version = Get-LatestVersion $ManifestUrl
    $selectedProtocol = Select-GitProtocol $gitPath $RequestedProtocol $SshUrl $HttpsUrl
    $repository = Get-RepositoryForProtocol $selectedProtocol $SshUrl $HttpsUrl

    Write-InstallerMessage "Checking access to $repository..."
    if (-not (Test-RepositoryAccess $gitPath $repository)) {
        Throw-InstallerError "unable to access the private CLI repository."
    }

    $requirement = "reachcollective-cli @ git+$repository@v$version"
    Write-InstallerMessage "Installing rcli $version with $selectedProtocol..."
    & $uvPath tool install --force $requirement
    if ($LASTEXITCODE -ne 0) {
        Throw-InstallerError "uv could not install rcli."
    }

    $binDirectory = (& $uvPath tool dir --bin | Select-Object -Last 1).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $binDirectory) {
        Throw-InstallerError "rcli was installed but the uv tool executable directory could not be determined."
    }

    if (($env:Path -split [IO.Path]::PathSeparator) -notcontains $binDirectory) {
        $env:Path = "$binDirectory$([IO.Path]::PathSeparator)$env:Path"
    }

    & $uvPath tool update-shell | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "uv could not persist its tool directory in PATH. Add $binDirectory to your user PATH."
    }

    $rcliPath = Join-Path $binDirectory "rcli.exe"
    if (-not (Test-Path -LiteralPath $rcliPath -PathType Leaf)) {
        $rcliPath = Find-Application "rcli"
    }
    if (-not $rcliPath) {
        Throw-InstallerError "rcli was installed but could not be found. Add $binDirectory to PATH."
    }

    & $rcliPath --version
    if ($LASTEXITCODE -ne 0) {
        Throw-InstallerError "rcli was installed but its version check failed."
    }

    Write-InstallerMessage "rcli was installed successfully."
}

if ($MyInvocation.InvocationName -ne ".") {
    Invoke-RcliInstaller `
        -RequestedProtocol $Protocol `
        -ManifestUrl $LatestUrl `
        -SshUrl $SshRepository `
        -HttpsUrl $HttpsRepository
}
