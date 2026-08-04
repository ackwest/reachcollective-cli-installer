$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "..\install.ps1")

function Assert-Equal {
    param(
        [Parameter(Mandatory = $true)]$Expected,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string]$Label
    )

    if ($Expected -ne $Actual) {
        throw "$Label`: expected '$Expected', got '$Actual'."
    }
}

function Assert-Throws {
    param(
        [Parameter(Mandatory = $true)][scriptblock]$Action,
        [Parameter(Mandatory = $true)][string]$Label
    )

    try {
        & $Action
    }
    catch {
        return
    }
    throw "$Label`: expected an exception."
}

Assert-Equal "1.2.3" (Get-StableVersionFromManifest ([pscustomobject]@{ version = "1.2.3" })) "stable version"
Assert-Throws { Get-StableVersionFromManifest ([pscustomobject]@{}) } "missing version"
Assert-Throws { Get-StableVersionFromManifest ([pscustomobject]@{ version = "1.2.3-beta.1" }) } "prerelease version"

Assert-Equal "https" (Resolve-ProtocolChoice "") "default protocol"
Assert-Equal "https" (Resolve-ProtocolChoice "1") "numeric HTTPS protocol"
Assert-Equal "ssh" (Resolve-ProtocolChoice "2") "numeric SSH protocol"
Assert-Equal "https" (Resolve-ProtocolChoice "HTTPS") "named HTTPS protocol"
Assert-Throws { Resolve-ProtocolChoice "ftp" } "invalid protocol"

$sshUrl = "ssh://git@example.com/company/tool.git"
$httpsUrl = "https://example.com/company/tool.git"
Assert-Equal $sshUrl (Get-RepositoryForProtocol "ssh" $sshUrl $httpsUrl) "SSH repository"
Assert-Equal $httpsUrl (Get-RepositoryForProtocol "https" $sshUrl $httpsUrl) "HTTPS repository"

$temporaryDirectory = Join-Path ([IO.Path]::GetTempPath()) ("rcli-installer-tests-" + [guid]::NewGuid())
$binDirectory = Join-Path $temporaryDirectory "bin"
$originalPath = $env:Path
$originalTestBin = $env:RCLI_TEST_BIN
try {
    New-Item -ItemType Directory -Path $binDirectory -Force | Out-Null
    Set-Content -Path (Join-Path $temporaryDirectory "git.cmd") -Encoding Ascii -Value @(
        "@echo off",
        "@exit /b 0"
    )
    Set-Content -Path (Join-Path $temporaryDirectory "uv.cmd") -Encoding Ascii -Value @(
        "@echo off",
        '@if "%2"=="dir" echo %RCLI_TEST_BIN%',
        "@exit /b 0"
    )
    Set-Content -Path (Join-Path $temporaryDirectory "rcli.cmd") -Encoding Ascii -Value @(
        "@echo off",
        "@echo rcli 1.2.3",
        "@exit /b 0"
    )

    $env:RCLI_TEST_BIN = $binDirectory
    $env:Path = "$temporaryDirectory$([IO.Path]::PathSeparator)$originalPath"
    function Get-LatestVersion {
        param([string]$Url)
        return "1.2.3"
    }

    Invoke-RcliInstaller `
        -RequestedProtocol "https" `
        -ManifestUrl "https://example.com/latest.json" `
        -SshUrl $sshUrl `
        -HttpsUrl $httpsUrl
}
finally {
    $env:Path = $originalPath
    if ($null -eq $originalTestBin) {
        Remove-Item Env:RCLI_TEST_BIN -ErrorAction SilentlyContinue
    }
    else {
        $env:RCLI_TEST_BIN = $originalTestBin
    }
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "PowerShell installer tests passed."
