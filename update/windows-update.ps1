# see Using the Windows Update Agent API | Searching, Downloading, and Installing Updates
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa387102(v=vs.85).aspx
# see ISystemInformation interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386095(v=vs.85).aspx
# see IUpdateSession interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386854(v=vs.85).aspx
# see IUpdateSearcher interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386515(v=vs.85).aspx
# see IUpdateSearcher::Search method
#     at https://docs.microsoft.com/en-us/windows/desktop/api/wuapi/nf-wuapi-iupdatesearcher-search
# see IUpdateDownloader interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386131(v=vs.85).aspx
# see IUpdateCollection interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386107(v=vs.85).aspx
# see IUpdate interface
#     at https://msdn.microsoft.com/en-us/library/windows/desktop/aa386099(v=vs.85).aspx
# see xWindowsUpdateAgent DSC resource
#     at https://github.com/PowerShell/xWindowsUpdate/blob/dev/DscResources/MSFT_xWindowsUpdateAgent/MSFT_xWindowsUpdateAgent.psm1
# NB you can install common sets of updates with one of these settings:
#       | Name          | SearchCriteria                            | Filters       |
#       |---------------|-------------------------------------------|---------------|
#       | Important     | AutoSelectOnWebSites=1 and IsInstalled=0  | $true         |
#       | Recommended   | BrowseOnly=0 and IsInstalled=0            | $true         |
#       | All           | IsInstalled=0                             | $true         |
#       | Optional Only | AutoSelectOnWebSites=0 and IsInstalled=0  | $_.BrowseOnly |

param(
    [string]$SearchCriteria = 'BrowseOnly=0 and IsInstalled=0',
    [string[]]$Filters = @('include:$true'),
    [int]$UpdateLimit = 1000,
    [switch]$OnlyCheckForRebootRequired = $false
)

$mock = $false

function ExitWithCode($exitCode) {
    $host.SetShouldExit($exitCode)
    Exit
}

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    ExitWithCode 1
}

if ($mock) {
    $mockWindowsUpdatePath = 'C:\Windows\Temp\windows-update-count-mock.txt'
    if (!(Test-Path $mockWindowsUpdatePath)) {
        Set-Content $mockWindowsUpdatePath 10
    }
    $count = [int]::Parse((Get-Content $mockWindowsUpdatePath).Trim())
    if ($count) {
        Write-Output "Synthetic reboot countdown counter is at $count"
        Set-Content $mockWindowsUpdatePath (--$count)
        ExitWithCode 101
    }
    Write-Output 'No Windows updates found'
    ExitWithCode 0
}

Add-Type @'
using System;
using System.Runtime.InteropServices;

public static class Windows
{
    [DllImport("kernel32", SetLastError=true)]
    public static extern UInt64 GetTickCount64();

    public static TimeSpan GetUptime()
    {
        return TimeSpan.FromMilliseconds(GetTickCount64());
    }
}
'@

function Wait-Condition {
    param(
      [scriptblock]$Condition,
      [int]$DebounceSeconds=15
    )
    process {
        $begin = [Windows]::GetUptime()
        do {
            Start-Sleep -Seconds 1
            try {
              $result = &$Condition
            } catch {
              $result = $false
            }
            if (-not $result) {
                $begin = [Windows]::GetUptime()
                continue
            }
        } while ((([Windows]::GetUptime()) - $begin).TotalSeconds -lt $DebounceSeconds)
    }
}

$operationResultCodes = @{
    0 = "NotStarted";
    1 = "InProgress";
    2 = "Succeeded";
    3 = "SucceededWithErrors";
    4 = "Failed";
    5 = "Aborted"
}

function LookupOperationResultCode($code) {
    if ($operationResultCodes.ContainsKey($code)) {
        return $operationResultCodes[$code]
    }
    return "Unknown Code $code"
}

function ExitWhenRebootRequired($rebootRequired = $false) {
    # check for pending Windows Updates.
    if (!$rebootRequired) {
        $systemInformation = New-Object -ComObject 'Microsoft.Update.SystemInfo'
        $rebootRequired = $systemInformation.RebootRequired
    }

    # check for pending Windows Features.
    if (!$rebootRequired) {
        $pendingPackagesKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\PackagesPending'
        $pendingPackagesCount = (Get-ChildItem -ErrorAction SilentlyContinue $pendingPackagesKey | Measure-Object).Count
        $rebootRequired = $pendingPackagesCount -gt 0
    }

    if ($rebootRequired) {
        Write-Output 'Waiting for the Windows Modules Installer to exit...'
        Wait-Condition {(Get-Process -ErrorAction SilentlyContinue TiWorker | Measure-Object).Count -eq 0}
        ExitWithCode 101
    }
}

ExitWhenRebootRequired

if ($OnlyCheckForRebootRequired) {
    Write-Output "$env:COMPUTERNAME restarted."
    ExitWithCode 0
}

$updateFilters = $Filters | ForEach-Object {
    $action, $expression = $_ -split ':',2
    New-Object PSObject -Property @{
        Action = $action
        Expression = [ScriptBlock]::Create($expression)
    }
}

function Test-IncludeUpdate($filters, $update) {
    foreach ($filter in $filters) {
        if (Where-Object -InputObject $update $filter.Expression) {
            return $filter.Action -eq 'include'
        }
    }
    return $false
}

$windowsOsVersion = [System.Environment]::OSVersion.Version

Write-Output 'Searching for Windows updates...'
$updatesToDownloadSize = 0
$updatesToDownload = New-Object -ComObject 'Microsoft.Update.UpdateColl'
$updatesToInstall = New-Object -ComObject 'Microsoft.Update.UpdateColl'
while ($true) {
    try {
        $updateSession = New-Object -ComObject 'Microsoft.Update.Session'
        $updateSession.ClientApplicationID = 'packer-windows-update'
        $updateSearcher = $updateSession.CreateUpdateSearcher()
        $searchResult = $updateSearcher.Search($SearchCriteria)
        if ($searchResult.ResultCode -eq 2) {
            break
        }
        $searchStatus = LookupOperationResultCode($searchResult.ResultCode)
    } catch {
        $searchStatus = $_.ToString()
    }
    Write-Output "Search for Windows updates failed with '$searchStatus'. Retrying..."
    Start-Sleep -Seconds 5
}
$rebootRequired = $false
for ($i = 0; $i -lt $searchResult.Updates.Count; ++$i) {
    $update = $searchResult.Updates.Item($i)
    if (!$update) {
        continue
    }

    $updateTitle = $update.Title
    if (!$updateTitle) {
        continue
    }

    $updateMaxDownloadSize = try { [int64]$update.MaxDownloadSize } catch { [int64]0 }
    $updateDate = try { $update.LastDeploymentChangeTime.ToString('yyyy-MM-dd') } catch { '1970-01-01' }
    $updateSize = ($updateMaxDownloadSize/1024/1024).ToString('0.##')
    $updateSummary = "Windows update ($updateDate; $updateSize MB): $updateTitle"

    if (!(Test-IncludeUpdate $updateFilters $update)) {
        Write-Output "Skipped (filter) $updateSummary"
        continue
    }

    $updateCanRequestUserInput = try { $update.InstallationBehavior.CanRequestUserInput } catch { $false }
    if ($updateCanRequestUserInput) {
        Write-Output "Warning The update '$updateTitle' has the CanRequestUserInput flag set (if the install hangs, you might need to exclude it with the filter 'exclude:`$_.InstallationBehavior.CanRequestUserInput' or 'exclude:`$_.Title -like '*$updateTitle*'')"
    }

    if (($updatesToInstall | Select-Object -ExpandProperty Title) -contains $updateTitle) {
        Write-Output "Warning, Skipping queueing the duplicated titled update '$updateTitle'."
        continue
    }

    Write-Output "Found $updateSummary"

    $update.AcceptEula() | Out-Null

    $updatesToDownloadSize += $updateMaxDownloadSize
    $updatesToDownload.Add($update) | Out-Null

    $updatesToInstall.Add($update) | Out-Null
    if ($updatesToInstall.Count -ge $UpdateLimit) {
        $rebootRequired = $true
        break
    }
}

if ($updatesToDownload.Count) {
    $updateSize = ($updatesToDownloadSize/1024/1024).ToString('0.##')
    Write-Output "Downloading Windows updates ($($updatesToDownload.Count) updates; $updateSize MB)..."
    $updateDownloader = $updateSession.CreateUpdateDownloader()
    # https://docs.microsoft.com/en-us/windows/desktop/api/winnt/ns-winnt-_osversioninfoexa#remarks
    if (($windowsOsVersion.Major -eq 6 -and $windowsOsVersion.Minor -gt 1) -or ($windowsOsVersion.Major -gt 6)) {
        $updateDownloader.Priority = 4 # 1 (dpLow), 2 (dpNormal), 3 (dpHigh), 4 (dpExtraHigh).
    } else {
        # For versions lower then 6.2 highest prioirty is 3
        $updateDownloader.Priority = 3 # 1 (dpLow), 2 (dpNormal), 3 (dpHigh).
    }
    $updateDownloader.Updates = $updatesToDownload
    while ($true) {
        $downloadResult = $updateDownloader.Download()
        if ($downloadResult.ResultCode -eq 2) {
            break
        }
        if ($downloadResult.ResultCode -eq 3) {
            Write-Output "Download Windows updates succeeded with errors. Will retry after the next reboot."
            $rebootRequired = $true
            break
        }
        $downloadStatus = LookupOperationResultCode($downloadResult.ResultCode)
        Write-Output "Download Windows updates failed with $downloadStatus. Retrying..."
        Start-Sleep -Seconds 5
    }
}

if ($updatesToInstall.Count) {
    Write-Output 'Installing Windows updates...'
    $updateInstaller = $updateSession.CreateUpdateInstaller()
    $updateInstaller.Updates = $updatesToInstall

    $installRebootRequired = $false
    try {
        $installResult = $updateInstaller.Install()
        $installRebootRequired = $installResult.RebootRequired
    } catch {
        Write-Warning "Windows update installation failed with error:"
        Write-Warning $_.Exception.ToString()

        # Windows update install failed for some reason
        # restart the machine and try again
        $rebootRequired = $true
    }
    ExitWhenRebootRequired ($installRebootRequired -or $rebootRequired)
} else {
    ExitWhenRebootRequired $rebootRequired
    Write-Output 'No Windows updates found'
}
