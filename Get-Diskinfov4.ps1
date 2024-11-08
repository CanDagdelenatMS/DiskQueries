

<#PSScriptInfo

.VERSION 4.0

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
                HelpMessage="Turkcell domain Credentials")][pscredential]$TcellCredentials= $null, # This credential is optional because currently logged in user will be used bu default
[Parameter(Mandatory=$true,
                HelpMessage="Superonline domain Credentials")][pscredential]$SuperCredentials,
[Parameter(Mandatory=$true,
        HelpMessage="TCloud domain Credentials")][pscredential]$TcloudCredentials
)

cls

#region input files

$serverlistfile= ".\serverlist.csv"
$excludefile= ".\excludelist.txt"

#endregion

#region output files
$Logfile= ".\DiskInfoLogs$(get-date -Format 'dd.mm.yyyy.hhmm').txt"
$TcellDiskFile= ".\TcellDiskInfo$(get-date -Format 'dd.mm.yyyy.hhmm').csv"
$SuperDiskFile= ".\SuperDiskInfo$(get-date -Format 'dd.mm.yyyy.hhmm').csv"
$TcloudDiskFile= ".\TcloudDiskInfo$(get-date -Format 'dd.mm.yyyy.hhmm').csv"
$UnresolvedServers = ".\UnresolvedServers$(get-date -Format 'dd.mm.yyyy.hhmm').txt"
#$Global:UnreachableServers = ".\UnreachableServers$(get-date -Format 'dd.mm.yyyy.hhmm').txt" #used in get-diskinfo function!

$TcellServerFile= ".\TcellServerList$(get-date -Format 'dd.mm.yyyy.hhmm').txt"
$SuperServerFile= ".\SuperServerList$(get-date -Format 'dd.mm.yyyy.hhmm').txt"
$TcloudServerFile= ".\TcloudServerList$(get-date -Format 'dd.mm.yyyy.hhmm').txt"
<#
Get-Item tcell* | remove-item -force
Get-Item tcloud* | remove-item -force
Get-Item super* | remove-item -force
Get-Item diskinfologs* | remove-item -force 
Get-Item UnreachableServers* | remove-item -force
#>
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
#$dizinpath2= @{label="Path2";expression={$_.DeviceID}}
$TotalSize = @{label="TotalSize";expression={"$([math]::Round($_.Size/1GB, 1))GB"}}
$used= @{label="Used";expression={"$([math]::Round(($_.Size - $_.FreeSpace) /1GB, 1))GB"}}
$FreeSize= @{label="FreeSize";expression={"$([math]::Round($_.FreeSpace /1GB, 1))GB"}}
$usedperct= @{label="Used %";expression={ [math]::Round((($_.Size - $_.FreeSpace) / ($_.Size)) *100,1)}}


$calculatedinfo= $totalinfo | select $Hostname, $dizinpath, $TotalSize, $used, $FreeSize, $usedperct | sort hostname
$calculatedinfo
}

#endregion




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
        {$tcelllist += $serverfqdn}
    if ( ($serverfqdn -like '*.superonlineds.com') -or ($serverfqdn -like '*.richcan.local'))
        {$superlist += $serverfqdn}
    if ( ($serverfqdn -like '*.tcloud.local') -or ($serverfqdn -like'*.richcan.local'))
        {$tcloudlist += $serverfqdn}

    }
else { #Server is unreachable
    Add-Content -Path $UnresolvedServers -Value $server 

    }

}


#$serverlist = "sqlalways1", "dc03","sqlalways1", "localhost","sqlalways1", "sqlalways2", "abc","localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost"
Set-Content -Value $tcelllist -Path $TcellServerFile
Set-Content -Value $superlist -Path $SuperServerFile
Set-Content -Value $tcloudlist -Path $TcloudServerFile
Write-Host "****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "TCell Servers " -ForegroundColor Green
Write-Host "****************************************" -ForegroundColor Gray
Get-Diskinfo -slist $tcelllist -cred $TcellCredentials | Export-Csv  -Delimiter '|' -Path "$TcellDiskFile" -Force -NoTypeInformation # ISE .\TcellDiskInfo.csv

Write-Host "****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "SuperOnline Servers " -ForegroundColor Green
Write-Host "****************************************" -ForegroundColor Gray
Get-Diskinfo -slist $superlist -cred $SuperCredentials | Export-Csv  -Delimiter '|' -Path "$SuperDiskFile" -Force -NoTypeInformation

Write-Host "****************************************" -ForegroundColor Gray
Write-Host "Starting working on " -NoNewline
Write-Host "TCloud Servers " -ForegroundColor Green
Write-Host "****************************************" -ForegroundColor Gray
Get-Diskinfo -slist $tcloudlist -cred $TcloudCredentials | Export-Csv  -Delimiter '|' -Path "$TcloudDiskFile" -Force -NoTypeInformation
#(Get-Content .\Diskinfo.csv) -replace('"','') -replace("Path2","Path")| Set-Content .\Diskinfo.csv
Stop-Transcript


<#
Hostname | dizin/path | TotalSize | Used | FreeSize | Used %| dizin/path
dsscrmwt01|c:\ |50G|12G|39G|23%|c:\
dsscrmwt01|d:\|100G|14G|87G|14%| d:\
dsscrmwt01|e:\|2.0G|346M|1.7G|17%| e:\
dsscrmwt01|f:\ |200M|5.8M|194M|3%|f:\ 
 #>