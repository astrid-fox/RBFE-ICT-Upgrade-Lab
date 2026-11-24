<#
.SYNOPSIS
    Configures Hyper-V Failover Cluster and Storage Spaces Direct (S2D) for RBFE.
.NOTES
    Target Nodes: RBFE-HOST01, RBFE-HOST02
    VLANs: 10 (Corp), 16 & 17 (Storage), 30 (Guest), 100 (Mgmt), 170 (Uplink)
#>

# --- PART A: Run on Parent Hyper-V Host (if using Nested Virtualisation) ---
$Nodes = @("RBFE-HOST01", "RBFE-HOST02")
foreach ($Node in $Nodes) {
    Set-VMProcessor -VMName $Node -ExposeVirtualizationExtensions $true
    Get-VMNetworkAdapter -VMName $Node | Set-VMNetworkAdapter -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan -VMName $Node -Trunk -AllowedVlanIdList "10,16,17,30,100,170" -NativeVlanId 100
}

# --- PART B: Run inside RBFE-HOST01 to Build the Cluster ---
# 1. Install Hyper-V and Failover Clustering roles on both hosts
Invoke-Command -ComputerName RBFE-HOST01, RBFE-HOST02 -ScriptBlock {
    Install-WindowsFeature -Name Hyper-V, Failover-Clustering -IncludeManagementTools -Restart
}

# 2. Validate cluster readiness (run after reboot)
Test-Cluster -Node RBFE-HOST01, RBFE-HOST02 -Include "Storage Spaces Direct", "Inventory", "Network", "System Configuration"

# 3. Create the Failover Cluster on Management VLAN 100
New-Cluster -Name "RBFE-CLUSTER" -Node RBFE-HOST01, RBFE-HOST02 -StaticAddress "10.100.0.10" -NoStorage

# 4. Enable Storage Spaces Direct (S2D) and create Cluster Shared Volume
Enable-ClusterS2D -CimSession "RBFE-CLUSTER" -Confirm:$false
New-Volume -FriendlyName "CSV-Workloads" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName "S2D*" -UseMaximumSize
