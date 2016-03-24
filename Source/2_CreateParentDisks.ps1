# Verify Running as Admin
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
If (!( $isAdmin )) {
	Write-Host "-- Restarting as Administrator" -ForegroundColor Cyan ; Sleep -Seconds 1
	Start-Process powershell.exe "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs 
	exit
}

###Get workdirectory###
$workdir=Split-Path $script:MyInvocation.MyCommand.Path

###Start LOG###
Start-Transcript -Path $workdir\CreateParentDisks.log
$StartDateTime = get-date
Write-host	"Script started at $StartDateTime"

#Temp variables
#$workdir= 'E:\WSvNext'

##Load Variables....
. "$($workdir)\variables.ps1"

#Variables
##################################
$AdminPassword=$LabConfig.AdminPassword
$Switchname='DC_HydrationSwitch'
$VMName='DC'
##################################


#############
# Functions #
#############

#Create Unattend for VHD 
Function Create-UnattendFileVHD{     
    param (
        [parameter(Mandatory=$true)]
        [string]
        $Computername,
        [parameter(Mandatory=$true)]
        [string]
        $AdminPassword,
        [parameter(Mandatory=$true)]
        [string]
        $Path
    )

    if ( Test-Path "$path\Unattend.xml" ) {
      Remove-Item "$Path\Unattend.xml"
    }
    $unattendFile = New-Item "$Path\Unattend.xml" -type File
    $fileContent =  @"
<?xml version='1.0' encoding='utf-8'?>
<unattend xmlns="urn:schemas-microsoft-com:unattend" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">

  <settings pass="offlineServicing">
   <component
        xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State"
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
        language="neutral"
        name="Microsoft-Windows-PartitionManager"
        processorArchitecture="amd64"
        publicKeyToken="31bf3856ad364e35"
        versionScope="nonSxS"
        >
      <SanPolicy>1</SanPolicy>
    </component>
 </settings>
 <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
        <ComputerName>$Computername</ComputerName>
    </component>
 </settings>
 <settings pass="oobeSystem">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <UserAccounts>
        <AdministratorPassword>
           <Value>$AdminPassword</Value>
           <PlainText>true</PlainText>
        </AdministratorPassword>
      </UserAccounts>
      <OOBE>
        <HideEULAPage>true</HideEULAPage>
        <SkipMachineOOBE>true</SkipMachineOOBE> 
        <SkipUserOOBE>true</SkipUserOOBE> 
      </OOBE>
    </component>
  </settings>
  <settings pass="specialize">
    <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS">
      <RegisteredOwner>PFE</RegisteredOwner>
      <RegisteredOrganization>Contoso</RegisteredOrganization>
    </component>
  </settings>
</unattend>

"@

    Set-Content -path $unattendFile -value $fileContent

    #return the file object
    Return $unattendFile 
}

##############
# Lets start #
##############

#Check if Hyper-V is installed.
Write-Host "Checking if Hyper-V is installed" -ForegroundColor Cyan
if ((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).state -eq 'Enabled'){
	Write-Host "`t Hyper-V is Installed" -ForegroundColor Green
}else{
	Write-Host "`t Hyper-V not installed. Please install hyper-v feature including Hyper-V management tools. Exiting" -ForegroundColor Red
	Write-Host "Press any key to continue ..."
	$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
	$HOST.UI.RawUI.Flushinputbuffer()
	Exit
}


## Open file dialog
If (Test-Path -Path "$workdir\OS"){
    $ISO = Get-ChildItem -Path "$workdir\OS" -Recurse -Include '*.iso' -ErrorAction SilentlyContinue
    }

if ( -not [bool]($ISO)){
    Write-Host "No ISO found in $Workdir\OS" -ForegroundColor Green
    Write-Host "please select ISO file with Windows Server 2016 wim file. Please use TP4 and newer" -ForegroundColor Green

    [reflection.assembly]::loadwithpartialname(“System.Windows.Forms”)
    $openFile = New-Object System.Windows.Forms.OpenFileDialog
    $openFile.Filter = “iso files (*.iso)|*.iso|All files (*.*)|*.*” 
    If($openFile.ShowDialog() -eq “OK”)
    {
       Write-Host  "File"$openfile.filename"selected" -ForegroundColor Green
    } 
    $ISO = Mount-DiskImage -ImagePath $openFile.FileName -PassThru
}else {
    Write-Host "Found ISO $($ISO.FullName)" -ForegroundColor Green
    $ISO = Mount-DiskImage -ImagePath $ISO.FullName -PassThru
}

$ISODriveLetter = (Get-Volume -DiskImage $ISO).DriveLetter

New-Item -Type Directory -Path "$workdir\ParentDisks"
New-Item -Type Directory -Path "$workdir\Tools" -Force
New-Item -Type Directory -Path "$workdir\Tools\mountdir"
New-Item -Type Directory -Path "$workdir\Tools\dism"
New-Item -Type Directory -Path "$workdir\Tools\packages"

. "$workdir\tools\convert-windowsimage.ps1"

Convert-WindowsImage -SourcePath $ISODriveLetter':\sources\install.wim' -Edition ServerDataCenterCore -VHDPath $workdir'\ParentDisks\Win2016Core_G2.vhdx' -SizeBytes 30GB -VHDFormat VHDX -DiskLayout UEFI

#copy dism tools 
  
Copy-Item -Path $ISODriveLetter':\sources\api*downlevel*.dll' -Destination $workdir\Tools\dism
Copy-Item -Path $ISODriveLetter':\sources\*provider*' -Destination $workdir\Tools\dism
Copy-Item -Path $ISODriveLetter':\sources\*dism*' -Destination $workdir\Tools\dism
Copy-Item -Path $ISODriveLetter':\nanoserver\packages\*' -Destination $workdir\Tools\packages\ -Recurse 


#Old way
#Todo: use the tool for NanoServer
if (Test-Path -Path $ISODriveLetter':\nanoserver\Packages\en-us\*en-us*'){
#vnext version
Convert-WindowsImage -SourcePath $ISODriveLetter':\Nanoserver\NanoServer.wim' -edition 2 -VHDPath $workdir'\ParentDisks\Win2016Nano_G2.vhdx' -SizeBytes 30GB -VHDFormat VHDX -DiskLayout UEFI
&"$workdir\tools\dism\dism" /Mount-Image /ImageFile:$workdir\Parentdisks\Win2016Nano_G2.vhdx /Index:1 /MountDir:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-DSC-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-DSC-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-FailoverCluster-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-FailoverCluster-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Guest-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Guest-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Storage-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Storage-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-SCVMM-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-SCVMM-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$workdir\tools\mountdir /Commit

Copy-Item -Path "$workdir\Parentdisks\Win2016Nano_G2.vhdx" -Destination "$workdir\ParentDisks\Win2016NanoHV_G2.vhdx"
 
&"$workdir\tools\dism\dism" /Mount-Image /ImageFile:$workdir\Parentdisks\Win2016NanoHV_G2.vhdx /Index:1 /MountDir:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Compute-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-SCVMM-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-SCVMM-Compute-Package_en-us.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$workdir\tools\mountdir /Commit

}else{

#TP4 Version
Convert-WindowsImage -SourcePath $ISODriveLetter':\Nanoserver\NanoServer.wim' -edition 1 -VHDPath $workdir'\ParentDisks\Win2016Nano_G2.vhdx' -SizeBytes 30GB -VHDFormat VHDX -DiskLayout UEFI
&"$workdir\tools\dism\dism" /Mount-Image /ImageFile:$workdir\Parentdisks\Win2016Nano_G2.vhdx /Index:1 /MountDir:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-DSC-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-DSC-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-FailoverCluster-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-FailoverCluster-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Guest-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Guest-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Storage-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Storage-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-Windows-Server-SCVMM-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-Windows-Server-SCVMM-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$workdir\tools\mountdir /Commit

Copy-Item -Path "$workdir\Parentdisks\Win2016Nano_G2.vhdx" -Destination "$workdir\ParentDisks\Win2016NanoHV_G2.vhdx"
 
&"$workdir\tools\dism\dism" /Mount-Image /ImageFile:$workdir\Parentdisks\Win2016NanoHV_G2.vhdx /Index:1 /MountDir:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-NanoServer-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-NanoServer-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-Windows-Server-SCVMM-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-Windows-Server-SCVMM-Compute-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$workdir\tools\mountdir /Commit

Copy-Item -Path "$workdir\ParentDisks\Win2016NanoHV_G2.vhdx" -Destination "$workdir\ParentDisks\Win2016NanoHVRF_G2.vhdx"

&"$workdir\tools\dism\dism" /Mount-Image /ImageFile:$workdir\Parentdisks\Win2016NanoHVRF_G2.vhdx /Index:1 /MountDir:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\Microsoft-OneCore-ReverseForwarders-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Add-Package /PackagePath:$workdir\tools\packages\en-us\Microsoft-OneCore-ReverseForwarders-Package.cab /Image:$workdir\tools\mountdir
&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$workdir\tools\mountdir /Commit

}

#create Tools VHDX

$vhd=New-VHD -Path "$workdir\ParentDisks\tools.vhdx" -SizeBytes 30GB -Dynamic
$VHDMount = Mount-VHD $vhd.Path -Passthru

$vhddisk = $VHDMount| get-disk 
$vhddiskpart = $vhddisk | Initialize-Disk -PartitionStyle GPT -PassThru | New-Partition -UseMaximumSize -AssignDriveLetter |Format-Volume -FileSystem NTFS -AllocationUnitSize 8kb -NewFileSystemLabel ToolsDisk 

$VHDPathTest=Test-Path -Path "$workdir\Tools\ToolsVHD\"

if (!$VHDPathTest){
	New-Item -Type Directory -Path $workdir'\Tools\ToolsVHD'
}

if ($VHDPathTest){
    Write-Host "Found $workdir\Tools\ToolsVHD\*, copying files into VHDX"
    Copy-Item -Path "$workdir\Tools\ToolsVHD\*" -Destination ($vhddiskpart.DriveLetter+':\') -Recurse -Force
}else{
    write-host "Files not found" 
    Write-Host "Add required tools into $workdir\Tools\toolsVHD and Press any key to continue..." -ForegroundColor Green
    $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
    Copy-Item -Path "$workdir\Tools\ToolsVHD\*" -Destination ($vhddiskpart.DriveLetter+':\') -Recurse -Force
}

Dismount-VHD $vhddisk.Number

##############
# Hydrate DC #
##############

$workdir
$vhdpath=$workdir+'\LAB\'+$VMName+'\Virtual Hard Disks\'+$VMName+'.vhdx'
$VMPath=$Workdir+'\LAB\'


#Create Parent VHD
Convert-WindowsImage -SourcePath $ISODriveLetter':\sources\install.wim' -Edition ServerDataCenter -VHDPath $vhdpath -SizeBytes 60GB -VHDFormat VHDX -DiskLayout UEFI





#If the switch does not already exist, then create a switch with the name $SwitchName
if (-not [bool](Get-VMSwitch -Name $Switchname -ErrorAction SilentlyContinue)) {New-VMSwitch -SwitchType Private -Name $Switchname}

if (Get-VM -Name DC -ErrorAction SilentlyContinue) {Write-Error -Message "A VM already exisits that has the name $VMName" -ErrorAction Stop}
New-VM -Name $VMname -VHDPath $vhdpath -MemoryStartupBytes 2GB -path $vmpath -SwitchName $Switchname -Generation 2 
Set-VMProcessor -Count 2 -VMName $VMname
Set-VMMemory -DynamicMemoryEnabled $true -VMName $VMname

#$ToolsVHD=New-VHD -ParentPath $workdir'\parentdisks\tools.vhdx' -Path $workdir'\tools\tools.vhdx'
#Add-VMHardDiskDrive -VMName $VMName -Path $ToolsVHD.Path

#Apply Unattend
$unattendfile=Create-UnattendFileVHD -Computername $VMName -AdminPassword $AdminPassword -path "$workdir\tools\"
New-item -type directory -Path $Workdir\tools\mountdir -force
&"$workdir\tools\dism\dism" /mount-image /imagefile:$vhdpath /index:1 /MountDir:$Workdir\tools\mountdir
&"$workdir\tools\dism\dism" /image:$Workdir\tools\mountdir /Apply-Unattend:$unattendfile
New-item -type directory -Path "$Workdir\tools\mountdir\Windows\Panther" -force
Copy-Item -Path $unattendfile -Destination "$Workdir\tools\mountdir\Windows\Panther\unattend.xml" -force
Copy-Item -Path "$workdir\tools\DSC\*" -Destination "$Workdir\tools\mountdir\Program Files\WindowsPowerShell\Modules\" -Recurse -force


#####
#Here goes Configuration and creation of pending.mof

$username = "corp\Administrator"
$password = $AdminPassword
$secstr = New-Object -TypeName System.Security.SecureString
$password.ToCharArray() | ForEach-Object {$secstr.AppendChar($_)}
$cred = new-object -typename System.Management.Automation.PSCredential -argumentlist $username, $secstr

configuration DCHydration
{
     param 
    ( 
        [Parameter(Mandatory)] 
        [pscredential]$safemodeAdministratorCred, 
 
        [Parameter(Mandatory)] 
        [pscredential]$domainCred,

        [Parameter(Mandatory)]
        [pscredential]$NewADUserCred
    )
 
    Import-DscResource -ModuleName xActiveDirectory,xDHCPServer,xNetworking
    Import-DscResource –ModuleName PSDesiredStateConfiguration

    Node $AllNodes.Where{$_.Role -eq "Parent DC"}.Nodename 
          
    {
        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }
        
        WindowsFeature FeatureGPMC
        {
            Ensure = "Present"
            Name = "GPMC"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 

        WindowsFeature FeatureADPowerShell
        {
            Ensure = "Present"
            Name = "RSAT-AD-PowerShell"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 

        WindowsFeature FeatureADAdminCenter
        {
            Ensure = "Present"
            Name = "RSAT-AD-AdminCenter"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 

        WindowsFeature FeatureADDSTools
        {
            Ensure = "Present"
            Name = "RSAT-ADDS-Tools"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 

        WindowsFeature FeatureDNSTools
        {
            Ensure = "Present"
            Name = "RSAT-DNS-Server"
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 
 
        xADDomain FirstDS 
        { 
            DomainName = $Node.DomainName 
            DomainAdministratorCredential = $domainCred 
            SafemodeAdministratorPassword = $safemodeAdministratorCred
            DomainNetbiosName = $node.DomainNetbiosName
            DependsOn = "[WindowsFeature]ADDSInstall"
        } 
     
        xWaitForADDomain DscForestWait 
        { 
            DomainName = $Node.DomainName 
            DomainUserCredential = $domainCred 
            RetryCount = $Node.RetryCount 
            RetryIntervalSec = $Node.RetryIntervalSec 
            DependsOn = "[xADDomain]FirstDS" 
        }
        
		xADOrganizationalUnit WorkshopOU
        {
			Name = 'Workshop'
			Path = 'dc=corp,dc=contoso,dc=com'
			ProtectedFromAccidentalDeletion = $true
			Description = 'Default OU for Workshop'
			Ensure = 'Present'
			DependsOn = "[xADDomain]FirstDS" 
        }

		xADUser VMM_SA
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            UserName = "VMM_SA"
            Password = $NewADUserCred
            Ensure = "Present"
            DependsOn = "[xADOrganizationalUnit]WorkshopOU"
			Description = "VMM Service Account"
			Path = 'OU=workshop,dc=corp,dc=contoso,dc=com'
			PasswordNeverExpires = $true
        }

		xADUser SQL_SA
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            UserName = "SQL_SA"
            Password = $NewADUserCred
            Ensure = "Present"
            DependsOn = "[xADOrganizationalUnit]WorkshopOU"
			Description = "SQL Service Account"
			Path = 'OU=workshop,dc=corp,dc=contoso,dc=com'
			PasswordNeverExpires = $true
        }

		xADUser SQL_Agent
        {
            DomainName = $Node.DomainName
            DomainAdministratorCredential = $domainCred
            UserName = "SQL_Agent"
            Password = $NewADUserCred
            Ensure = "Present"
            DependsOn = "[xADOrganizationalUnit]WorkshopOU"
			Description = "SQL Agent Account"
			Path = 'OU=workshop,dc=corp,dc=contoso,dc=com'
			PasswordNeverExpires = $true
        }

		xADGroup DomainAdmins
		{
			GroupName = "Domain Admins"
			DependsOn = "[xADUser]VMM_SA"
			MembersToInclude = "VMM_SA"
		}

		xADUser AdministratorNeverExpires
        {
            DomainName = $Node.DomainName
			UserName = "Administrator"
            Ensure = "Present"
            DependsOn = "[xADDomain]FirstDS"
			PasswordNeverExpires = $true
	    }

        xIPaddress IP
        {
            IPAddress = '10.0.0.1'
            SubnetMask = 24
            AddressFamily = 'IPv4'
            InterfaceAlias = 'Ethernet'
        }
        WindowsFeature DHCPServer
        {
            Ensure = "Present"
            Name = "DHCP"
            DependsOn = "[xADDomain]FirstDS"
        }
        
        WindowsFeature DHCPServerManagement
        {
            Ensure = "Present"
            Name = "RSAT-DHCP"
            DependsOn = "[WindowsFeature]DHCPServer"
        } 

        xDhcpServerScope ManagementScope
        
        {
        Ensure = 'Present'
        IPStartRange = '10.0.0.10'
        IPEndRange = '10.0.0.254'
        Name = 'ManagementScope'
        SubnetMask = '255.255.255.0'
        LeaseDuration = '00:08:00'
        State = 'Active'
        AddressFamily = 'IPv4'
        DependsOn = "[WindowsFeature]DHCPServerManagement"
        }

        xDhcpServerOption Option
        {
        Ensure = 'Present'
        ScopeID = '10.0.0.0'
        DnsDomain = 'corp.contoso.com'
        DnsServerIPAddress = '10.0.0.1'
        AddressFamily = 'IPv4'
        Router = '10.0.0.1'
        DependsOn = "[xDHCPServerScope]ManagementScope"
        }
		
		xDhcpServerAuthorization LocalServerActivation
		{
        Ensure = 'Present'
		}
    }
}

$ConfigData = @{ 
 
    AllNodes = @( 
        @{ 
            Nodename = "DC" 
            Role = "Parent DC" 
            DomainName = "corp.contoso.com"
            DomainNetbiosName = "corp"
            PSDscAllowPlainTextPassword = $true
            PsDscAllowDomainUser= $true        
            RetryCount = 50  
            RetryIntervalSec = 30  
        }         
    ) 
} 

[DSCLocalConfigurationManager()]

configuration LCMConfig
{
    Node DC
    {
        Settings
        {
            RebootNodeIfNeeded = $true
			ActionAfterReboot = 'ContinueConfiguration'
        }
    }
}

<#
$ConfigData = @{
    AllNodes = @();
    NonNodeData = @{ DomainName = 'corp.contoso.com' ; DistinguishedName = 'dc=corp,dc=contoso,dc=com' }
}
# you can say "'DC1','DC2' | % { ..."
'DC' | % { 
    $ConfigData.AllNodes += @{ NodeName   = $_       ; PSDSCAllowPlainTextPassword = $True ;
                               Role       = 'DC'     ; PSDSCAllowDomainUser        = $True }
}

#region Sub
Configuration IP {
    param ( $IPAddress      , $SubnetMask    = '24',
            $InterfaceAlias , $AddressFamily = 'IPv4' )

    Import-DSCResource -ModuleName xNetworking -ModuleVersion "2.7.0.0"
    
    Node $AllNodes.NodeName {
        xIPaddress IP {
            IPAddress      = $IPAddress
            SubnetMask     = $SubnetMask
            AddressFamily  = $AddressFamily
            InterfaceAlias = $InterfaceAlias
        }
    }
}

Configuration FeatureConfig {
    param ( [Parameter()] $Role        ,
            [Parameter()] $FeatureList ,
            [Parameter()] $State       )
    
	Import-DscResource –ModuleName PSDesiredStateConfiguration

    node $AllNodes.NodeName {
        foreach ( $Feature in $FeatureList ) {
            WindowsFeature ( $Feature -replace '-','_' ) {
                Name   = $Feature
                Ensure = $State
            }
        }
    }
}

Configuration AD_Domain {
    param ( $DomainName       , $DatabasePath = 'C:\Windows\NTDS' ,
            $RetryCount       , $LogPath      = 'C:\Windows\NTDS' ,
            $RetryIntervalSec , $SysvolPath   = 'C:\Windows\SYSVOL' )

    Import-DSCResource -Module xActiveDirectory -ModuleVersion "2.9.0.0"
    
    Node $AllNodes.NodeName {
        xADDomain PromoteDC {
            DomainName                    = $DomainName
            DomainAdministratorCredential = $cred
            SafemodeAdministratorPassword = $cred
            DatabasePath                  = $DatabasePath
            LogPath                       = $LogPath
            SysvolPath                    = $SysvolPath
        }
        
        xWaitForADDomain DscForestWait { 
            DomainName           = $DomainName
            DomainUserCredential = $Cred 
            RetryCount           = $RetryCount 
            RetryIntervalSec     = $RetryIntervalSec 
            DependsOn            = '[xADDomain]PromoteDC'
        }
    }
}

Configuration AD_OU {
    param ( $Name   ,  $ProtectedFromAccidentalDeletion = $true ,
            $Path   ,  $Description = 'DSC OU' ,
            $Ensure 
          )

    Import-DSCResource -ModuleName xActiveDirectory -ModuleVersion "2.9.0.0"
    
    Node $AllNodes.NodeName {
        xADOrganizationalUnit WorkshopOU {
            Name = $Name
            Path = $Path
            ProtectedFromAccidentalDeletion = $ProtectedFromAccidentalDeletion
            Description = $Description
            Ensure      = $Ensure
        }
    }
}

Configuration AD_User {
    param ( $DomainName ,  $Description = 'DSC User'     ,
            $UserName   ,  $PasswordNeverExpires = $true , 
            $Ensure     ,  $Path                         )

    Import-DSCResource -ModuleName xActiveDirectory -ModuleVersion "2.9.0.0"
    
    Node $AllNodes.NodeName {
        xADUser $UserName {
            DomainName  = $ConfigData.NonNodeData.DomainName
            DomainAdministratorCredential = $Cred
            UserName    = $UserName
            Password    = $Cred
            Ensure      = $Ensure
            Description = $Description
            Path        = $Path
            PasswordNeverExpires = $PasswordNeverExpires
        }
    }
}

Configuration AD_Group {
    param ( $GroupName        ,  
            $MembersToInclude ,
            $Ensure           )

    Import-DSCResource -ModuleName xActiveDirectory -ModuleVersion "2.9.0.0" 
    
    Node $AllNodes.NodeName {
        xADGroup DomainAdmins {
            GroupName        = $GroupName
            MembersToInclude = $MembersToInclude
        }
    }
}

Configuration DHCPServer {
    Import-DSCResource -ModuleName xDHCPServer

        Node $AllNodes.NodeName {
        xDhcpServerScope ManagementScope {
            Name         = 'ManagementScope'
            Ensure       = 'Present'
            IPStartRange = '10.0.0.10'
            IPEndRange   = '10.0.0.254'
            SubnetMask   = '255.255.255.0'
            LeaseDuration = '08:00:00'
            State         = 'Active'
            AddressFamily = 'IPv4'
        }

        xDhcpServerOption Option {
            Ensure = 'Present'
            ScopeID = '10.0.0.0'
            DnsDomain = 'contoso.com'
            DnsServerIPAddress = '10.0.0.1'
            AddressFamily = 'IPv4'
            Router = '10.0.0.1'
            DependsOn = "[xDHCPServerScope]ManagementScope"
        }
              
        xDhcpServerAuthorization LocalServerActivation { Ensure = 'Present' }
    }
}
#endregion Sub

[DscLocalConfigurationManager()]
Configuration LCMConfig {
    node $AllNodes.NodeName {
        Settings {
            RebootNodeIfNeeded = $true
            ActionAfterReboot  = 'ContinueConfiguration'
        }
    }
}

Configuration ContosoCaller {
    IP DC {
        IPAddress      = '10.0.0.1'
        SubnetMask     = 24
        AddressFamily  = 'IPv4'
        InterfaceAlias = 'Ethernet'
    }

    FeatureConfig ADFeatures { 
        Role        = 'DC'                  # Fabric Management Nodes
        State       = 'Present'
        FeatureList = 'AD-Domain-Services','GPMC','RSAT-AD-PowerShell','RSAT-AD-AdminCenter','RSAT-ADDS-Tools',
                      'RSAT-DNS-Server','DHCP','RSAT-DHCP'
    }

    AD_Domain Contoso {
        DomainName       = $ConfigData.NonNodeData.DomainName
        RetryCount       = 50
        RetryIntervalSec = 30
        DependsOn        = '[FeatureConfig]ADFeatures'
    }

    AD_OU    ContosoOU_Workshop {
        Name        = 'Workshop'
        Path        = $ConfigData.NonNodeData.DistinguishedName
        Description = 'Default OU for Workshop'
        Ensure      = 'Present'
        DependsOn   = '[AD_Domain]Contoso'
    }

    AD_User  ContosoUser_VMM_SA {
        UserName    = 'VMM_SA'
        Ensure      = 'Present'
        DomainName  = $ConfigData.NonNodeData.DomainName
        Path        = 'OU=workshop,' + $ConfigData.NonNodeData.DistinguishedName
        Description = 'VMM Service Account'
        DependsOn   = '[AD_OU]ContosoOU_Workshop'
    }

    AD_User  ContosoUser_SQL_SA {
        UserName    = 'SQL_SA'
        Ensure      = 'Present'
        DomainName  = $ConfigData.NonNodeData.DomainName
        Path        = 'OU=workshop,' + $ConfigData.NonNodeData.DistinguishedName
        Description = 'SQL Service Account'
        DependsOn   = '[AD_OU]ContosoOU_Workshop'
    }

    AD_User  ContosoUser_SQL_Agent {
        UserName    = 'SQL_Agent'
        Ensure      = 'Present'
        DomainName  = $ConfigData.NonNodeData.DomainName
        Path        = 'OU=workshop,' + $ConfigData.NonNodeData.DistinguishedName
        Description = 'SQL Agent Account'
        DependsOn   = '[AD_OU]ContosoOU_Workshop'
    }

    AD_User  ContosoUser_Administrator {
        UserName   = 'Administrator'
        Ensure     = 'Present'
        DomainName  = $ConfigData.NonNodeData.DomainName
        PasswordNeverExpires = $true
    }

    AD_Group Contoso_Domain_Admins {
        Ensure           = 'Present'
        GroupName        = 'Domain Admins'
        MembersToInclude = 'VMM_SA'
        DependsOn        = '[AD_User]ContosoUser_VMM_SA'
    }

    DHCPServer Main { DependsOn = '[FeatureConfig]ADFeatures','[AD_Domain]Contoso'}
}

#>
# Set-DscLocalConfigurationManager -Path c:\temp -Verbose
LCMConfig       -OutputPath "$workdir\tools\config" -ConfigurationData $ConfigData
#ContosoCaller  -OutputPath "$workdir\tools\config" -ConfigurationData $ConfigData
DCHydration     -OutputPath "$workdir\tools\config" -ConfigurationData $ConfigData -safemodeAdministratorCred $cred -domainCred $cred -NewADUserCred $cred

#Start-DscConfiguration -path c:\temp -Verbose -Wait -Force

New-item -type directory -Path "$Workdir\tools\Config" -ErrorAction Ignore
#DChydration -OutputPath "$workdir\tools\config" -safemodeAdministratorCred $cred -domainCred $cred -ConfigurationData $ConfigData -NewADUserCred $cred
#LCMconfig -OutputPath "$workdir\tools\config"
Copy-Item -path "$workdir\tools\config\dc.mof"      -Destination "$workdir\tools\mountdir\Windows\system32\Configuration\pending.mof"
Copy-Item -Path "$workdir\tools\config\dc.meta.mof" -Destination "$workdir\tools\mountdir\Windows\system32\Configuration\metaconfig.mof"


#####

&"$workdir\tools\dism\dism" /Unmount-Image /MountDir:$Workdir\tools\mountdir /Commit


#Start and wait for configuration
Start-VM -VMName $VMName

$VMStartupTime = 250 
Write-host "Configuring DC takes a while"
Write-host "Initial configuration in progress. Sleeping $VMStartupTime seconds"
Start-Sleep $VMStartupTime

do{
	$test=Invoke-Command -VMName $vmname -ScriptBlock {Get-DscConfigurationStatus} -Credential $cred -ErrorAction SilentlyContinue
	if ($test -eq $null) {
		Write-Host "Configuration in Progress. Sleeping 10 seconds"
	}else{
		Write-Host "Current DSC state: $($test.status), ResourncesNotInDesiredState: $($test.resourcesNotInDesiredState.count), ResourncesInDesiredState: $($test.resourcesInDesiredState.count). Sleeping 10 seconds" 
		Write-Host "Invoking DSC Configuration again" 
		Invoke-Command -VMName $vmname -ScriptBlock {Start-DscConfiguration -UseExisting} -Credential $cred
	}
	Start-Sleep 10
}until ($test.Status -eq 'Success' -and $test.rebootrequested -eq $false)
$test

Invoke-Command -VMName $vmname -ScriptBlock {redircmp 'OU=Workshop,DC=corp,DC=contoso,DC=com'} -Credential $cred -ErrorAction SilentlyContinue

Get-VMNetworkAdapter -VMName $VMName | Disconnect-VMNetworkAdapter
Stop-VM -Name $VMName


#cleanup

###Backup VM Configuration ###
Copy-Item -Path "$vmpath\$VMNAME\Virtual Machines\" -Destination "$vmpath\$VMNAME\Virtual Machines_Bak\" -Recurse
Remove-VM -Name $VMName -Force
Remove-Item -Path "$vmpath\$VMNAME\Virtual Machines\" -Recurse
Rename-Item -Path "$vmpath\$VMNAME\Virtual Machines_Bak\" -NewName 'Virtual Machines'
Compress-Archive -Path "$vmpath\$VMNAME\Virtual Machines\" -DestinationPath "$vmpath\$VMNAME\Virtual Machines.zip"

###Cleanup The rest ###
Remove-VMSwitch -Name $Switchname -Force
$ISO | Dismount-DiskImage
Remove-Item -Path $workdir'\tools\config' -Force -Recurse
Remove-Item -Path $workdir'\tools\dism' -Force -Recurse
Remove-Item -Path $workdir'\tools\mountdir' -Force -Recurse
Remove-Item -Path $workdir'\tools\packages' -Force -Recurse
Remove-Item -Path $workdir'\tools\unattend.xml' -Force

Write-Host "Script finished at $(Get-date) and took $(((get-date) - $StartDateTime).TotalMinutes) Minutes"

Stop-Transcript
Write-Host "Job Done. Press any key to continue..." -ForegroundColor Green
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | OUT-NULL
