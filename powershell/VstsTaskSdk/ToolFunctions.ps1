<#
.SYNOPSIS
Asserts the agent version is at least the specified minimum.

.PARAMETER Minimum
Minimum version - must be 2.104.1 or higher.
#>
function Assert-Agent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [version]$Minimum)

    if (([version]'2.104.1').CompareTo($Minimum) -ge 1) {
        Write-Error "Assert-Agent requires the parameter to be 2.104.1 or higher."
        return
    }

    $agent = Get-TaskVariable -Name 'agent.version'
    if (!$agent -or $Minimum.CompareTo([version]$agent) -ge 1) {
        Write-Error (Get-LocString -Key 'PSLIB_AgentVersion0Required' -ArgumentList $Minimum)
    }
}

<#
.SYNOPSIS
Asserts that a path exists. Throws if the path does not exist.

.PARAMETER PassThru
True to return the path.
#>
function Assert-Path {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LiteralPath,
        [Microsoft.PowerShell.Commands.TestPathType]$PathType = [Microsoft.PowerShell.Commands.TestPathType]::Any,
        [switch]$PassThru)

    if ($PathType -eq [Microsoft.PowerShell.Commands.TestPathType]::Any) {
        Write-Verbose "Asserting path exists: '$LiteralPath'"
    } else {
        Write-Verbose "Asserting $("$PathType".ToLowerInvariant()) path exists: '$LiteralPath'"
    }

    if (Test-Path -LiteralPath $LiteralPath -PathType $PathType) {
        if ($PassThru) {
            return $LiteralPath
        }

        return
    }

    $resourceKey = switch ($PathType) {
        ([Microsoft.PowerShell.Commands.TestPathType]::Container) { "PSLIB_ContainerPathNotFound0" ; break }
        ([Microsoft.PowerShell.Commands.TestPathType]::Leaf) { "PSLIB_LeafPathNotFound0" ; break }
        default { "PSLIB_PathNotFound0" }
    }

    throw (Get-LocString -Key $resourceKey -ArgumentList $LiteralPath)
}

<#
.SYNOPSIS
Executes an external program.

.DESCRIPTION
Executes an external program and waits for the process to exit.

After calling this command, the exit code of the process can be retrieved from the variable $LASTEXITCODE.

.PARAMETER Encoding
This parameter not required for most scenarios. Indicates how to interpret the encoding from the external program. An example use case would be if an external program outputs UTF-16 XML and the output needs to be parsed.

.PARAMETER RequireExitCodeZero
Indicates whether to write an error to the error pipeline if the exit code is not zero.
#>
function Invoke-Tool { # TODO: RENAME TO INVOKE-PROCESS?
    [CmdletBinding()]
    param(
        [ValidatePattern('^[^\r\n]*$')]
        [Parameter(Mandatory = $true)]
        [string]$FileName,
        [ValidatePattern('^[^\r\n]*$')]
        [Parameter()]
        [string]$Arguments,
        [string]$WorkingDirectory,
        [System.Text.Encoding]$Encoding,
        [switch]$RequireExitCodeZero,
        [bool]$IgnoreHostException)

    Trace-EnteringInvocation $MyInvocation
    $isPushed = $false
    $originalEncoding = $null
    try {
        if ($Encoding) {
            $originalEncoding = [System.Console]::OutputEncoding
            [System.Console]::OutputEncoding = $Encoding
        }

        if ($WorkingDirectory) {
            Push-Location -LiteralPath $WorkingDirectory -ErrorAction Stop
            $isPushed = $true
        }

        $FileName = $FileName.Replace('"', '').Replace("'", "''")
        Write-Host "##[command]""$FileName"" $Arguments"
        try {
            Invoke-Expression "& '$FileName' --% $Arguments"
        } catch [System.Management.Automation.Host.HostException] {
            if ($IgnoreHostException -eq $False) {
                throw
            }

            Write-Host "##[warning]Host Exception was thrown by Invoke-Expression, suppress it due IgnoreHostException setting"
        }
        Write-Verbose "Exit code: $LASTEXITCODE"
        if ($RequireExitCodeZero -and $LASTEXITCODE -ne 0) {
            Write-Error (Get-LocString -Key PSLIB_Process0ExitedWithCode1 -ArgumentList ([System.IO.Path]::GetFileName($FileName)), $LASTEXITCODE)
        }
    } finally {
        if ($originalEncoding) {
            [System.Console]::OutputEncoding = $originalEncoding
        }

        if ($isPushed) {
            Pop-Location
        }

        Trace-LeavingInvocation $MyInvocation
    }
}
