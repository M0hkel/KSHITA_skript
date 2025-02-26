$InterfaceAlias = "Ethernet"
$NewIPAddress   = "192.168.1.100"
$PrefixLength   = 24
$DefaultGateway = "192.168.1.1"
$DNSServers     = @("8.8.8.8", "8.8.4.4")

$dhcpIP = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | 
    Where-Object { $_.PrefixOrigin -eq "Dhcp" } | Select-Object -First 1

if ($dhcpIP) {
    $NewIPAddress = $dhcpIP.IPAddress
    $PrefixLength = $dhcpIP.PrefixLength
    Write-Output "Kasutatan DHCP kaudu määratud IP aadressi $NewIPAddress staatilisena."

    $dhcpRoute = Get-NetRoute -InterfaceAlias $InterfaceAlias | 
        Where-Object { $_.NextHop -and $_.NextHop -ne "0.0.0.0" } | Select-Object -First 1
    if ($dhcpRoute) {
        $DefaultGateway = $dhcpRoute.NextHop
    }

    $dhcpDNS = (Get-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4).ServerAddresses
    if ($dhcpDNS -and $dhcpDNS.Count -gt 0) {
        $DNSServers = $dhcpDNS
    }
}

Get-NetIPAddress -InterfaceAlias $InterfaceAlias | Remove-NetIPAddress -Confirm:$false

New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $NewIPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers

$NewDomainName = "mihkel.sise"
$SafeModePwd   = ConvertTo-SecureString "Parool1!" -AsPlainText -Force

Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
Import-Module ADDSDeployment

Install-ADDSForest `
    -DomainName $NewDomainName `
    -SafeModeAdministratorPassword $SafeModePwd `
    -InstallDNS `
    -Force `
    -NoRebootOnCompletion

Install-Module PSWindowsUpdate -Force -Confirm:$false
Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted
Import-Module PSWindowsUpdate

$Action  = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-NoProfile -WindowStyle Hidden -Command `"Install-WindowsUpdate -AcceptAll -AutoReboot`""
$Trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Saturday -At 3am
Register-ScheduledTask -Action $Action -Trigger $Trigger -TaskName "WeeklyWindowsUpdate" -Description "Käivitab Windows Update iga nädal."

$DiskNumber = 1
Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -Confirm:$false
$Partition  = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter
Format-Volume -Partition $Partition -FileSystem NTFS -NewFileSystemLabel "BackupVolume" -Confirm:$false

Install-WindowsFeature Windows-Server-Backup

Write-Output "Skripti täitmine lõpetatud. Palun taaskäivitage süsteem."