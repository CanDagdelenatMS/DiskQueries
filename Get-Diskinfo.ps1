
$serverlist = "sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost","sqlalways1", "sqlalways2", "localhost"


 cls
$noofservers= $serverlist.count
$i=0
$totalinfo= @()
while ($i -lt $noofservers)
{
    $submax=$i+9
    if ($noofservers -lt $submax) {$submax = $noofservers}
    $sublist= $serverlist[$i..$submax]
    Write-Progress  -Activity "Sending cmd to servers. Please wait..." -Status "Working on servers $i to $submax. Servers: $sublist"  -PercentComplete (($i/$noofservers)*100)
    $curentdiskinfo= Get-CimInstance -ClassName Win32_LogicalDisk -Filter "DriveType=3" -ComputerName $sublist
    sleep 1
    $i= $submax +1
    $totalinfo += $curentdiskinfo
}


$Hostname= @{label="Hostname";expression={$_.PSComputerName}}
$dizinpath= @{label="Path";expression={$_.DeviceID}}
$TotalSize = @{label="TotalSize";expression={[math]::Round($_.Size/1GB, 1)}}
$used= @{label="Used";expression={[math]::Round(($_.Size - $_.FreeSpace) /1GB, 1)}}
$FreeSize= @{label="FreeSize";expression={[math]::Round($_.FreeSpace /1GB, 1)}}
$usedperct= @{label="Used %";expression={ [math]::Round((($_.Size - $_.FreeSpace) / ($_.Size)) *100,1)}}


$calculatedinfo= $totalinfo | select $Hostname, $dizinpath, $TotalSize, $used, $FreeSize, $usedperct
$calculatedinfo | Export-Csv  -Delimiter '|' -Path ".\Diskinfo.csv" -Force

