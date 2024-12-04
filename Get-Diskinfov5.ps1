﻿

<#PSScriptInfo

.VERSION 5.0

.GUID 96c98068-2777-4f71-b17f-0d715e4efa50

.AUTHOR Can Dagdelen

.COMPANYNAME 

.COPYRIGHT 

.TAGS 

.LICENSEURI 

.PROJECTURI 

.ICONURI 

.EXTERNALMODULEDEPENDENCIES 

.REQUIREDSCRIPTS 

.EXTERNALSCRIPTDEPENDENCIES 

.RELEASENOTES


#>

<# 

.DESCRIPTION 
 This Script is aimed to list disk information from a list os servers and group & query according to their FQDN 

#>

param (
[Parameter(Mandatory=$false,
                HelpMessage="Turkcell domain Credentials")][pscredential]$TcellCredentials= $null, # This credential is optional because currently logged in user will be used by default
[Parameter(Mandatory=$true,
                HelpMessage="Superonline domain Credentials")][pscredential]$SuperCredentials,
[Parameter(Mandatory=$true,
        HelpMessage="TCloud domain Credentials")][pscredential]$TcloudCredentials
)


#region input files
cls
$serverlistfile= ".\serverlist.csv"
$excludefile= ".\excludelist.txt"

#endregion

#region output files
$outputfolder= '.\ReportsAndLogs'
$Logfile= "$outputfolder\DiskInfoLogs$(get-date -Format 'ddMMyyyy-hhmm').txt"
$ServerDiskFile= "$outputfolder\ServerDiskInfo$(get-date -Format 'ddMMyyyy-hhmm').csv"
$UnresolvedServers = "$outputfolder\UnresolvedServers$(get-date -Format 'ddMMyyyy-hhmm').txt"
$UnreachableServers = "$outputfolder\UnreachableServers$(get-date -Format 'ddMMyyyy-hhmm').txt" 
$AccessibleServers= "$outputfolder\AccessibleServerList$(get-date -Format 'ddMMyyyy-hhmm').txt"
if (-not (Get-Item $outputfolder -ErrorAction SilentlyContinue)) {New-Item $outputfolder -ItemType Directory | Out-Null}
Remove-Item $outputfolder -Recurse -Force -Confirm:$false

Start-Transcript -Path "$Logfile"
#endregion

#region function

function Get-Diskinfo{

param(
        [string[]]$slist,
        $cred #can be either a pscredential object or null (since $tcellcredential could be $null)
        )
Write-host "Working on server list:`n$slist"
$noofservers= $slist.count
$i=0
$totalinfo= @()

while ($i -lt $noofservers)
{
    Write-Progress  -Activity "Sending cmd to servers. Please wait..." -Status "Working on servers $i to $submax. Servers: $sublist"  -PercentComplete (($i/$noofservers)*100)
    $submax=$i+9
    if ($noofservers -lt $submax) {$submax = $noofservers}
    $sublist= $slist[$i..$submax]
    if ($cred) {
$sessions= New-CimSession -ComputerName $sublist -Credential $cred 
        $curentdiskinfo= Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -CimSession $sessions
        Remove-CimSession $sessions
        }
    else {$curentdiskinfo= Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $sublist}
    $totalinfo += $curentdiskinfo
    $i= $submax +1
}


$Hostname= @{label="Hostname";expression={$_.PSComputerName}}
$dizinpath= @{label="Path";expression={"$($_.DeviceID)\"}}
$dizinpath2= @{label="Path2";expression={"$($_.DeviceID)\"}}
$TotalSize = @{label="TotalSize";expression={"$([math]::Round($_.Size/1GB, 1))GB"}}
$used= @{label="Used";expression={"$([math]::Round(($_.Size - $_.FreeSpace) /1GB, 1))GB"}}
$FreeSize= @{label="FreeSize";expression={"$([math]::Round($_.FreeSpace /1GB, 1))GB"}}
$usedperct= @{label="Used %";expression={ [math]::Round((($_.Size - $_.FreeSpace) / ($_.Size)) *100,1)}}


$calculatedinfo= $totalinfo | select $Hostname, $dizinpath, $TotalSize, $used, $FreeSize, $usedperct, $dizinpath2 | sort hostname
$calculatedinfo
}

function Test-QuickWinrm  { # test-netconnection is too slow
    param( [string]$compname, [int]$timeout=100)
    $connection = (New-Object System.Net.Sockets.TcpClient)
    $result= $connection.ConnectAsync("$compname", 5985).Wait($timeout)
    $connection.Close()
    return $result
    
} 

#endregion


#region create server lists for tcell, tcloud and superonline
$serverlist = (Import-csv $serverlistfile -Delimiter ";" | where {$_.OSTYPE -eq 'WINDOWS' -and $_.'CI_TYPE' -eq 'Server' }).CINAME
$excludelist= Get-Content $excludefile
foreach ($excludeserver in $excludelist) {
    $serverlist = $serverlist -ne $excludeserver 
    }

$tcelllist= @()
$superlist= @()
$tcloudlist= @()

foreach ($server in $serverlist) {
$serverfqdn= (Resolve-DnsName $server -Type A -QuickTimeout -ErrorAction SilentlyContinue).name
if ($serverfqdn)
    {
    if ( ($serverfqdn -like '*.richcan.local') -or ($serverfqdn -like '*.ng.entp.tgc') `
                    -or ($serverfqdn -like'*.turkcell.entp.tgc') -or ($serverfqdn -like'*.wss.local'))
            {
            if (Test-QuickWinrm -compname $serverfqdn) {$tcelllist += $serverfqdn}
            else {Add-Content -Path $UnreachableServers -Value $serverfqdn }          
            }
    if ( ($serverfqdn -like '*.superonlineds.com') -or ($serverfqdn -like '*.richcan.local'))
            {
            if (Test-QuickWinrm -compname $serverfqdn) {$superlist += $serverfqdn}
            else {Add-Content -Path $UnreachableServers -Value $serverfqdn }          
            }
    if ( ($serverfqdn -like '*.tcloud.local') -or ($serverfqdn -like'*.richcan.local'))
            {
            if (Test-QuickWinrm -compname $serverfqdn) {$tcloudlist += $serverfqdn}
            else {Add-Content -Path $UnreachableServers -Value $serverfqdn }          
            }
    #>
    }
else { #Server is unreachable
    Add-Content -Path $UnresolvedServers -Value $server 

    }

}

#endregion

#region save output
#$serverlist = "sqlalways1", "dc03","sqlalways1", "localhost","sqlalways1", "sqlalways2", "abc","localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost"
Set-Content -Value "*****************************************`nTurkcell Servers:" -PassThru $AccessibleServers |out-null
Add-Content -Value $tcelllist -Path $AccessibleServers
Add-Content -Value "*****************************************`n" $AccessibleServers |out-null

Add-Content -Value "*****************************************`nSuperonline Servers:" -PassThru $AccessibleServers |out-null
Add-Content -Value $superlist -Path $AccessibleServers
Add-Content -Value "*****************************************`n" $AccessibleServers |out-null

Add-Content -Value "*****************************************`nTCloud Servers:" -PassThru $AccessibleServers |out-null
Add-Content -Value $tcloudlist -Path $AccessibleServers
Add-Content -Value "*****************************************`n" $AccessibleServers |out-null


Write-Host "`n****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "TCell Servers " -ForegroundColor Green
Get-Diskinfo -slist $tcelllist -cred $TcellCredentials | Export-Csv  -Delimiter '|' -Path "$ServerDiskFile" -Force -NoTypeInformation #; ISE "$ServerDiskFile"
Write-Host "****************************************" -ForegroundColor Gray

Write-Host "`n****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "SuperOnline Servers " -ForegroundColor Green
Get-Diskinfo -slist $superlist -cred $SuperCredentials | Export-Csv  -Delimiter '|' -Path "$ServerDiskFile" -Force -NoTypeInformation -Append
Write-Host "****************************************" -ForegroundColor Gray


Write-Host "`n****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "TCloud Servers " -ForegroundColor Green
Get-Diskinfo -slist $tcloudlist -cred $TcloudCredentials | Export-Csv  -Delimiter '|' -Path "$ServerDiskFile" -Force -NoTypeInformation -Append
(Get-Content $ServerDiskFile) -replace('"','') -replace("Path2","Path")| Set-Content $ServerDiskFile
Write-Host "****************************************`n" -ForegroundColor Gray
Stop-Transcript
#endregion