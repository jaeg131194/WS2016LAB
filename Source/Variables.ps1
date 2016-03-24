# Create Hashtable of VMs
$LabConfig=@{AdminPassword='LS1setup!'; Prefix = 'SDSWS-'}

$NetworkConfig=@{SwitchName = 'LabSwitch' ; StorageNet1='172.16.1.'; StorageNet2='172.16.2.'}

$LAbVMs = @(
    #TP4 Storage Spaces Direct scenario    
    @{VMName = 'Direct1'  ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB },
    @{VMName = 'Direct2'  ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB },
    @{VMName = 'Direct3'  ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB },
    @{VMName = 'Direct4'  ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB },
    
    #TP4 Shared Storage Spaces scenario 
    @{ VMName = 'Shared1'  ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Shared2'  ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Shared3'  ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Shared4'  ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'},
    

    #TP4 Shared Storage for Storage Replica
    @{ VMName = 'Replica1' ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Replica2' ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Replica3' ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'},
    @{ VMName = 'Replica4' ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'}
)

<# More Dynamic example of the same configuration as above. But now you can deploy thousands VMs with simple change. So instead of 1..4 use 1..1000

$LAbVMs = @()
1..4 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'      ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB } } 
1..4 | % {"Shared$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'} }
1..2 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'} }
3..4 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'} }

#>

<# vnext version

$LAbVMs = @()
1..4 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'      ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB } } 
1..4 | % {"Shared$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1' ; StorageNetwork = 'Yes'} }
1..2 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHV_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'} }
3..4 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHV_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'} }

#>
<#
HELP:
If you need more help or different configuration options, ping me at jaromirk@microsoft.com

### Parameters ###
Prefix
	Prefix for your lab. Each VM and switch will have this prefix.

VMName
    Can be whatever. This name will be used to domain join.

Configuration
    'Simple' - No local storage. Just VM
    'S2D' - locally attached SSDS and HDDs. For Storage Spaces Direct. You can specify 0 for SSDnumber or HDD number if you want only one tier.
    'Shared' - Shared VHDS attached to all nodes. Simulates traditional approach with shared space/shared storage. Requires Shared VHD->Requires Clustering Components
    'Replica' - 2 Shared disks, first for Data, second for Log. Simulates traditional storage. Requires Shared VHD->Requires Clustering Components

VMSet
	This is unique name for your set of VMs. You need to specify it for Spaces and Replica scenario, so script will connect shared disks to the same VMSet.

ParentVHD
	Win2016Core_G2.vhdx     - Windows Server 2016 Core
	Win2016Nano_G2.vhdx     - Windows Server 2016 Nano with these packages: DSC, Failover Cluster, Guest, Storage, SCVMM
	Win2016NanoHV_G2.vhdx   - Windows Server 2016 Nano with these packages: DSC, Failover Cluster, Guest, Storage, SCVMM, Compute, SCVMM Compute
	Win2016NanoHVRF_G2.vhdx - Windows Server 2016 Nano with these packages: DSC, Failover Cluster, Guest, Storage, SCVMM, Compute, SCVMM Compute, Reverse Forwarders (removed in TP5 as RF are always in nano)


StorageNetwork
	'Yes' - Additional 2 networks with IP from StorageNet1 and StorageNet2 

### LABVMs Examples ###

Just some VMs
$LAbVMs = @(
    @{ VMName = 'Simple1'  ; Configuration = 'Simple'   ; ParentVHD = 'Win2016Nano_G2.vhdx'     ; MemoryStartupBytes= 512MB }, 
    @{ VMName = 'Simple2'  ; Configuration = 'Simple'   ; ParentVHD = 'Win2016Nano_G2.vhdx'     ; MemoryStartupBytes= 512MB }, 
    @{ VMName = 'Simple3'  ; Configuration = 'Simple'   ; ParentVHD = 'Win2016Nano_G2.vhdx'     ; MemoryStartupBytes= 512MB }, 
    @{ VMName = 'Simple4'  ; Configuration = 'Simple'   ; ParentVHD = 'Win2016Nano_G2.vhdx'     ; MemoryStartupBytes= 512MB }
)
or you can use this to deploy 100 simple VMs

$LAbVMs = @()
1..100 | % {"Simple$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Simple'   ; ParentVHD = 'Win2016Nano_G2.vhdx'    ; MemoryStartupBytes= 512MB } }


HyperConverged Storage Spaces Direct with Nano Server

$LAbVMs = @()
1..4 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB ; StorageNetwork = 'Yes'} }

vnext
$LAbVMs = @()
1..4 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB ; StorageNetwork = 'Yes'} }

Disaggregated Storage Spaces Direct with Nano Server
$LAbVMs = @()
1..4 | % {"Compute$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Simple'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; MemoryStartupBytes= 512MB } }
1..4 | % {"SOFS$_"}     | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'      ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; SSDNumber = 12; SSDSize=800GB ; HDDNumber = 0 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB } }

vnext
$LAbVMs = @()
1..4 | % {"Compute$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Simple'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; MemoryStartupBytes= 512MB } }
1..4 | % {"SOFS$_"}     | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'      ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; SSDNumber = 12; SSDSize=800GB ; HDDNumber = 0 ; HDDSize= 4TB ; MemoryStartupBytes= 512MB } }

"traditional" stretch cluster (like with traditional SAN)
$LAbVMs = @()
1..2 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'} }
3..4 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHVRF_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'} }

vnext
$LAbVMs = @()
1..2 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHV_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet1' ; StorageNetwork = 'Yes'} }
3..4 | % {"Replica$_"} | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Replica'  ; ParentVHD = 'Win2016NanoHV_G2.vhdx' ; ReplicaHDDSize = 20GB ; ReplicaLogSize = 10GB ; MemoryStartupBytes= 2GB ; VMSet= 'ReplicaSet2' ; StorageNetwork = 'Yes'} }


Stretch cluster with Storage Spaces Direct
$LAbVMs = @()
1..8 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 2GB } }

vnext
$LAbVMs = @()
1..8 | % {"Direct$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'S2D'       ; ParentVHD = 'Win2016NanoHV_G2.vhdx'   ; SSDNumber = 4; SSDSize=800GB ; HDDNumber = 12 ; HDDSize= 4TB ; MemoryStartupBytes= 2GB } }

HyperConverged Storage Spaces with Shared Storage
$LAbVMs = @()
1..4 | % {"Compute$_"}  | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Simple'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; MemoryStartupBytes= 512MB } }
1..4 | % {"SOFS$_"}     | % { $LAbVMs += @{ VMName = $_ ; Configuration = 'Shared'   ; ParentVHD = 'Win2016NanoHV_G2.vhdx'     ; SSDNumber = 6; SSDSize=800GB ; HDDNumber = 8  ; HDDSize= 1TB ; MemoryStartupBytes= 512MB ; VMSet= 'SharedLab1'} }

....

#>