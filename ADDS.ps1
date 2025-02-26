$InterfaceAlias = "Ethernet0"
$NewIPAddress   = "192.168.1.100"
$PrefixLength   = 24
$DefaultGateway = "192.168.1.1"
$DNSServers     = @("8.8.8.8", "8.8.4.4")

$dhcpIP = Get-NetIPAddress -InterfaceAlias $InterfaceAlias -AddressFamily IPv4 | 
    Where-Object { $_.PrefixOrigin -eq "Dhcp" } | Select-Object -First 1

if ($dhcpIP) {
    $NewIPAddress = $dhcpIP.IPAddress
    $PrefixLength = $dhcpIP.PrefixLength
    Write-Output "Kasutan DHCP kaudu määratud IP-aadressi $NewIPAddress staatilisena."

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

try {
    Get-NetIPAddress -InterfaceAlias $InterfaceAlias | Remove-NetIPAddress -Confirm:$false -ErrorAction Stop
    New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $NewIPAddress -PrefixLength $PrefixLength -DefaultGateway $DefaultGateway -ErrorAction Stop
    Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $DNSServers -ErrorAction Stop
} catch {
    Write-Output "Võrgu konfiguratsiooni viga: $_"
}

$NewDomainName = "mihkel.sise"
$SafeModePwd   = ConvertTo-SecureString "Parool1!" -AsPlainText -Force

try {
    Install-WindowsFeature AD-Domain-Services -IncludeManagementTools -ErrorAction Stop
    Import-Module ADDSDeployment -ErrorAction Stop
} catch {
    Write-Output "AD domeeniteenuste installatsiooni viga: $_"
}

try {
    Install-ADDSForest `
        -DomainName $NewDomainName `
        -SafeModeAdministratorPassword $SafeModePwd `
        -InstallDNS `
        -Force `
        -NoRebootOnCompletion -ErrorAction Stop
} catch {
    Write-Output "ADDS metsa installatsiooni viga: $_"
}

try {
    Install-Module PSWindowsUpdate -Force -Confirm:$false -ErrorAction Stop
    Set-PSRepository -Name "PSGallery" -InstallationPolicy Trusted -ErrorAction Stop
    Import-Module PSWindowsUpdate -ErrorAction Stop
} catch {
    Write-Output "Windows Update’i mooduli konfiguratsiooni viga: $_"
}

$Action = New-ScheduledTaskAction `
    -Execute "PowerShell.exe" `
    -Argument "-NoProfile -WindowStyle Hidden -Command `"Install-WindowsUpdate -AcceptAll -AutoReboot`""
$Trigger = New-ScheduledTaskTrigger `
    -Weekly `
    -DaysOfWeek Saturday `
    -At 3am
try {
    Register-ScheduledTask `
        -Action $Action `
        -Trigger $Trigger `
        -TaskName "WeeklyWindowsUpdate" `
        -Description "Kaivitab Windows Update iga nadal." -ErrorAction Stop
} catch {
    Write-Output "Ajastatud ülesande registreerimise viga: $_"
}

$DiskNumber = 1
try {
    Initialize-Disk -Number $DiskNumber -PartitionStyle GPT -Confirm:$false -ErrorAction Stop
    $Partition = New-Partition -DiskNumber $DiskNumber -UseMaximumSize -AssignDriveLetter -ErrorAction Stop
    Format-Volume -Partition $Partition -FileSystem NTFS -NewFileSystemLabel "BackupVolume" -Confirm:$false -ErrorAction Stop
} catch {
    Write-Output "Ketta konfiguratsiooni viga: $_"
}

try {
    Install-WindowsFeature Windows-Server-Backup -ErrorAction Stop
    $BackupDriveLetter = "$($Partition.DriveLetter):"
    Write-Output "Seadistatakse Windows Server Backup kasutama ketast $BackupDriveLetter"
    wbadmin enable backup -addtarget:$BackupDriveLetter -include:C: -allCritical -schedule:"03:00" -quiet
} catch {
    Write-Output "Varunduse seadistamise viga: $_"
}

$restartInput = Read-Host "Skripti täitmine lõppenud. Taaskäivitage süsteem? ([Y]/n)"
if ($restartInput -eq "" -or $restartInput.ToLower() -eq "y") {
    Restart-Computer -Force
} else {
    Write-Output "Süsteemi taaskäivitamist ei sooritatud."
}