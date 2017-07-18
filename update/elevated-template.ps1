Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
trap {
    Write-Output "ERROR: $_"
    Write-Output (($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1')
    Write-Output (($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1')
    Exit 1
}
$name = "{{.TaskName}}"
$log = "$env:SystemRoot\Temp\$name.out"
$s = New-Object -ComObject "Schedule.Service"
$s.Connect()
$t = $s.NewTask($null)
$t.XmlText = @'
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
    <RegistrationInfo>
        <Description>{{.TaskDescription}}</Description>
    </RegistrationInfo>
    <Principals>
        <Principal id="Author">
            <RunLevel>HighestAvailable</RunLevel>
        </Principal>
    </Principals>
    <Settings>
        <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
        <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
        <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
        <AllowHardTerminate>true</AllowHardTerminate>
        <StartWhenAvailable>false</StartWhenAvailable>
        <RunOnlyIfNetworkAvailable>false</RunOnlyIfNetworkAvailable>
        <IdleSettings>
            <StopOnIdleEnd>false</StopOnIdleEnd>
            <RestartOnIdle>false</RestartOnIdle>
        </IdleSettings>
        <AllowStartOnDemand>true</AllowStartOnDemand>
        <Enabled>true</Enabled>
        <Hidden>false</Hidden>
        <RunOnlyIfIdle>false</RunOnlyIfIdle>
        <WakeToRun>false</WakeToRun>
        <ExecutionTimeLimit>PT24H</ExecutionTimeLimit>
        <Priority>4</Priority>
    </Settings>
    <Actions Context="Author">
        <Exec>
            <Command>cmd</Command>
            <Arguments>/c {{.Command}} &gt;%SYSTEMROOT%\Temp\{{.TaskName}}.out 2&gt;&amp;1</Arguments>
        </Exec>
    </Actions>
</Task>
'@
$username = "{{.Username}}"
$password = "{{.Password}}"
if (!$password) {
    $password = $null
}
$f = $s.GetFolder("\")
$f.RegisterTaskDefinition($name, $t, 6, $username, $password, 1, $null) | Out-Null
$t = $f.GetTask("\$name")
$t.Run($null) | Out-Null
$timeout = 10
$sec = 0
while ((!($t.state -eq 4)) -and ($sec -lt $timeout)) {
    Start-Sleep -s 1
    $sec++
}
$line = 0
do {
    Start-Sleep -m 100
    if (Test-Path $log) {
        Get-Content $log | select -skip $line | ForEach {
            ++$line
            Write-Output $_
        }
    }
} while (!($t.state -eq 3))
$result = $t.LastTaskResult
if (Test-Path $log) {
    Remove-Item $log -Force -ErrorAction SilentlyContinue | Out-Null
}
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($s) | Out-Null
exit $result
