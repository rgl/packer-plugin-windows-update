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
    [int]$RebootDelay = 0,
    [switch]$OnlyCheckForRebootRequired = $false
)

# Attempt to install the join module, which will be used later on
if(!(Get-Module -ListAvailable JoinModule)) { Find-Module -Name JoinModule | Install-Module -Force }
Get-Module -ListAvailable JoinModule | Import-Module -Force

$mock = $false

function ExitWithCode($exitCode) {
    $host.SetShouldExit($exitCode)
    Write-Output "Exiting with code $exitCode"
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
        $begin = Get-Date
        do {
            Start-Sleep -Seconds 1
            try {
              $result = &$Condition
            } catch {
              $result = $false
            }
            if (-not $result) {
                $begin = Get-Date
                continue
            }
        } while (((Get-Date) - $begin).TotalSeconds -lt $DebounceSeconds)
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
        Write-Output 'Waiting for the Windows Modules Installer to exit or updates to complete...'
        Wait-Condition {(Get-Process -ErrorAction SilentlyContinue TiWorker | Measure-Object).Count -eq 0 -or (UpdatesComplete)}
        Write-Output 'The wait condition has been met, adding a delay so I can verify on the machine during testing...'

        # Added a delay so we can control reboot delays, mainly for testing
        Start-Sleep -Seconds $RebootDelay

        ExitWithCode 101
    }
}

# Using eventvwr, search system logs for WindowsUpdateClient source.  Return the status of the KBArticles in the array
# to determine if they are completed or not.  If completed, return true.  If not completed, return false.
function UpdatesComplete
{
    param(
        [string[]]$kbarticles = @()
    )
    Write-Output "Validating Windows Update status from event logs and CBS logs..."
    
    # Search pattern for extracting exit code
    $EventLogExitCodePattern = "0x[0-9A-Fa-f]+"
    
    # Search the event log
    $event_kb_logs = Get-EventLog -LogName System -Source Microsoft-Windows-WindowsUpdateClient |
                        Where-Object { $_.Message -match 'KB\d+' -or $_.ReplacementStrings -join ";" -match 'KB\d+' } |
                        Group-Object { if ($_.Message -match 'KB\d+' -or $_.ReplacementStrings -join ";" -match 'KB\d+') { $matches[0] } } |
                        ForEach-Object {
                            $latest = $_.Group | Sort-Object TimeGenerated -Descending | Select-Object -First 1
                            $event_return_code = ""
                            $completion_status = $false
                            $return_code = $latest.Message -match $EventLogExitCodePattern
                            if($return_code) { $event_return_code = $matches[0] }
                            switch -regex ($latest.Message)
                            {
                                "Downloading"
                                {
                                    $install_status = "Downloading"
                                    break
                                }
                                "^Installation Started:"
                                {
                                    $install_status = "Installing"
                                    break
                                }
                                "^Installation Successful:"
                                {
                                    $install_status = "Installed"
                                    $completion_status = $true
                                    break
                                }
                                "^Installation Failure:"
                                {
                                    $install_status = "Failed"
                                    $completion_status = $true
                                    break
                                }
                            }
                            [PSCustomObject]@{
                                ArticleID     = $_.Name   # e.g., KB5021234
                                EventTimeGenerated = $latest.TimeGenerated
                                EventID       = $latest.EventID
                                EventResultCode = $event_return_code
                                EventInstallComplete      = $completion_status
                                EventInstallStatus        = $install_status
                                EventMessage       = $latest.Message
                                EventRecord        = $latest
                            }
                        }

    # Search the CBS logs for additional patch details
    if(Test-Path -Path "$env:WINDIR\Logs\CBS\CBS.log" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
    {
        $cbs_log_messages = Get-Item -Path "$env:WINDIR\Logs\CBS\CBS.log"
        if($null -ne $cbs_log_messages)
        {
            # Regex matches
            $ArticleIDMatch = "Identifier:\s*(KB\d+)"
            $StepMatch = "Exec:\s*([^\.]+). "
            $PackageMatch = "Package:\s*(.+), "
            $TimestampMatch = "(\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}), "
            $Results = "\[HRESULT\s*=\s*([\dx]+)\s*-\s*(.*)]"

            # Empty the return strings for the CBS Logs
            $ArticleID = ""
            $Message = ""
            $Package = ""
            $Timestamp = ""
            $ReturnCode = ""
            $ReturnMessage = ""
            
            # Search $cbs_log_messages for "Identifier: KB"
            $cbs_kb_logs = $cbs_log_messages |  Select-String -Pattern $ArticleIDMatch |
                                                Foreach-Object {
                                                    if($_ -match $ArticleIDMatch) { $ArticleID = $Matches[1] }
                                                    if($_ -match $StepMatch)      { $Message = $Matches[1] }
                                                    if($_ -match $PackageMatch)   { $Package = $Matches[1] }
                                                    if($_ -match $TimestampMatch) { $Timestamp = $Matches[1]}
                                                    if($_ -match $Results)        { $ReturnCode = $Matches[1]; $ReturnMessage = $Matches[2]}
                                                    $Record = $_ -replace "                  ",""
                                                    
                                                    [PSCustomObject]@{
                                                        ArticleID        = $ArticleID
                                                        CBSPackage       = $Package
                                                        CBSMessage       = $Message
                                                        CBSResultCode    = $ReturnCode
                                                        CBSResultMessage = $ReturnMessage
                                                        CBSTimeGenerated = $Timestamp
                                                        CBSRecord        = $Record
                                                    } 
                                                } |
                                                Group-Object ArticleID |
                                                Foreach-Object {
                                                    $_.Group | Sort-Object CBSTimeGenerated -Descending | Select -First 1
                                                }                                            
        }
    }

    # If the CBS KB Logs and the Event log KB Logs are populated, join them to find an overall status.
    # Otherwise, just use either the event or cbs logs
    if($null -ne $cbs_kb_logs -and $null -ne $event_kb_logs)
    {
        Write-Output "Joining CBS and Event logs for Windows Update status..."
        $windows_updates = Join-Object -LeftObject $event_kb_logs -RightObject $cbs_kb_logs -On ArticleId -JoinType Full
    }
    elseif($null -ne $event_kb_logs)
    {
        Write-Output "Using Event logs for Windows Update status..."
        $windows_updates = $event_kb_logs
    }
    elseif($null -ne $cbs_kb_logs)
    {
        Write-Output "Using CBS logs for Windows Update status..."
        $windows_updates = $cbs_kb_logs
    }
    else 
    {
        Write-Output "No Additional Windows Update logs found, using just the logs from the session..."  
    }

    # Loop through the logs to determine the overall status
    foreach($windows_update in $windows_updates)
    {
        # If the event install has completed, mark the overall completion status
        if($windows_update.EventInstallComplete) { $overall_completion_status = $true } else {$overall_completion_status = $false }

        # If the event install status is installed OR the CBS status code is success, then mark the overall status as installed
        if($windows_update.EventInstallStatus -eq "Installed" -or $windows_update.CBSResultCode -eq "0x00000000")
        {
            $overall_install_status = "Installed"
            $overall_completion_status = $true
        }
        elseif(![string]::IsNullOrEmpty($windows_update.EventInstallStatus))
        {
            # Fallback to using the install status from the event log if it's availiable
            $overall_install_status = $windows_update.EventInstallStatus
        }
        elseif(![string]::IsNullOrEmpty($windows_update.CBSStatusMessage))
        {
            # Fallback to using the CBS log install status if it's availiable
            if($windows_update.CBSMessage -eq "Processing Complete")
            {
                $overall_install_status = "Installed"
                $overall_completion_status = $true
            }
            else 
            {
                $overall_install_status = $windows_update.CBSStatusMessage
            }
        }

        # Add the overall status properties to the object
        $windows_update | Add-Member -MemberType NoteProperty -Name InstallStatus -Value $overall_install_status
        $windows_update | Add-Member -MemberType NoteProperty -Name Completed -Value $overall_completion_status
    }

    # Determine if there are updates left and set true/false for a return
    if($null -ne $kbarticles -and $kbarticles.Count -gt 0)
    {
        $blnReturn = $null -eq ($kbarticles | Where-Object { $_ -in $windows_updates.ArticleID } |
                        ForEach-Object { $kb = $_; $windows_updates | Where-Object { $_.ArticleID -eq $kb } } |
                        Where-Object { $_.Completed -ne $true } )

    }
    else
    {
        $blnReturn = $null -eq ($windows_updates | Where-Object { $_.Completed -ne $true })
    }

    $blnReturn
}

# try to repair the windows update settings to work in non-preview mode.
# see https://github.com/rgl/packer-plugin-windows-update/issues/144
# see https://learn.microsoft.com/en-sg/answers/questions/1791668/powershell-command-outputting-system-comobject-on
function Repair-WindowsUpdate {
    $settingsPath = 'C:\ProgramData\Microsoft\Windows\OneSettings\UusSettings.json'
    if (!(Test-Path $settingsPath)) {
        throw 'the windows update api is in an invalid state. see https://github.com/rgl/packer-plugin-windows-update/issues/144.'
    }
    $version = (New-Object -ComObject Microsoft.Update.AgentInfo).GetInfo('ProductVersionString')
    $settings = Get-Content -Raw $settingsPath | ConvertFrom-Json
    if ($settings.settings.EXCLUSIONS -notcontains $version) {
        $settings.settings.EXCLUSIONS += $version
        Write-Output 'Repairing the windows update settings to work in non-preview mode...'
        Copy-Item $settingsPath "$settingsPath.backup.json" -Force
        [System.IO.File]::WriteAllText(
            $settingsPath,
            ($settings | ConvertTo-Json -Compress -Depth 100),
            (New-Object System.Text.UTF8Encoding $false))
    }
    Write-Output 'Restarting the machine to retry a new windows update round...'
    ExitWithCode 101
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

    # when the windows update api returns an invalid update object, repair
    # windows update and signal a reboot to try again.
    # see https://github.com/rgl/packer-plugin-windows-update/issues/144
    # see The June 2024 preview update might impact applications using Windows Update APIs
    #     https://learn.microsoft.com/en-us/windows/release-health/status-windows-11-23h2#3351msgdesc
    $expectedProperties = @(
        'Title'
        'MaxDownloadSize'
        'LastDeploymentChangeTime'
        'InstallationBehavior'
        'AcceptEula'
    )
    $properties = $update `
        | Get-Member $expectedProperties `
        | Select-Object -ExpandProperty Name
    if (!$properties -or (Compare-Object $expectedProperties $properties)) {
        Repair-WindowsUpdate
    }

    $updateTitle = $update.Title
    $updateMaxDownloadSize = $update.MaxDownloadSize
    $updateDate = $update.LastDeploymentChangeTime.ToString('yyyy-MM-dd')
    $updateSize = ($updateMaxDownloadSize/1024/1024).ToString('0.##')
    $updateSummary = "Windows update ($updateDate; $updateSize MB): $updateTitle"

    if (!(Test-IncludeUpdate $updateFilters $update)) {
        Write-Output "Skipped (filter) $updateSummary"
        continue
    }

    if ($update.InstallationBehavior.CanRequestUserInput) {
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

ExitWithCode 0
