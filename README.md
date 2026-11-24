# RBFE-ICT-Upgrade-Lab
Royal Bob`s Food Emporium IT Infrastructure Upgrade and National Expansion Project - North Metro TAFE - Joondalup Campus - Advanced Cyber Security Diploma Assessment November 2026 
# 🦢 Royal Bob’s Food Emporium (RBFE) — ICT Infrastructure Lab Guide

This repository contains the step-by-step lab build, network segmentation, Active Directory hardening, and validation runbook for the **RBFE National Expansion Infrastructure Upgrade** (Tender Ref: `3740991`).

---

## 📋 1. Lab Topology & IP/VLAN Plan

### Virtual Machines & Roles

| Hostname | Role | OS | vCPU / RAM | VLAN | IP Address |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `RBFE-HOST01` | Hyper-V / S2D Node 1 | Windows Server 2022/2025 | 4 vCPU / 16 GB | 100 (Mgmt) | `10.100.0.11/24` |
| `RBFE-HOST02` | Hyper-V / S2D Node 2 | Windows Server 2022/2025 | 4 vCPU / 16 GB | 100 (Mgmt) | `10.100.0.12/24` |
| `RBFE-FW01` | NGFW / Router / VPN | pfSense / OPNsense / VyOS | 2 vCPU / 4 GB | Trunk (All) | `10.170.0.1/24` (Uplink) |
| `RBFE-DC01` | Primary DC + DNS + Entra Connect | Windows Server 2022/2025 | 2 vCPU / 4 GB | 10 (Corp) | `10.10.0.10/24` |
| `RBFE-DC02` | Secondary DC + DNS | Windows Server 2022/2025 | 2 vCPU / 4 GB | 10 (Corp) | `10.10.0.11/24` |
| `RBFE-SQL01` | Legacy SQL Inventory & Payroll | Windows Server 2022 | 2 vCPU / 8 GB | 10 (Corp) | `10.10.0.20/24` |
| `RBFE-PC01` | East Perth Staff Client | Windows 11 Pro | 2 vCPU / 4 GB | 10 (Corp) | `10.10.0.50/24` (DHCP) |
| `CAFE-GUEST01` | Café Customer Kiosk PC | Windows 11 Pro | 2 vCPU / 4 GB | 30 (Guest) | `10.30.0.50/24` (DHCP) |

### VLAN Segmentation Matrix (Simulating Dell PowerSwitch S5224)

| VLAN ID | Name | Subnet | Purpose & Firewall Policy |
| :--- | :--- | :--- | :--- |
| **VLAN 10** | `CORP_LAN` | `10.10.0.0/24` | Corporate staff, DCs, and SQL/Payroll VMs. Full domain access. |
| **VLAN 16** | `STORAGE_A` | `10.16.0.0/24` | Dedicated non-routable east-west S2D storage replication network 1. |
| **VLAN 17** | `STORAGE_B` | `10.17.0.0/24` | Dedicated non-routable east-west S2D storage replication network 2. |
| **VLAN 30** | `CAFE_GUEST` | `10.30.0.0/24` | Customer-facing café PCs. **Internet-only; RFC1918 corporate traffic blocked.** |
| **VLAN 100** | `MGMT_OOB` | `10.100.0.0/24` | Hypervisor and switch management interfaces. Restricted to IT Admin IPs. |
| **VLAN 170** | `UPLINK_WAN` | `10.170.0.0/24` | Core switch to NGFW/IDPS and simulated fibre gateway interconnect. |

---

## 🛠️ 2. Phase 1: Virtual Network & Hypervisor Setup

### Checklist
- [ ] Create an External/Internal Virtual Switch (`vSwitch-Trunk`) supporting 802.1Q VLAN tagging.
- [ ] Configure `RBFE-FW01` with sub-interfaces/VLANs (`10`, `30`, `100`, `170`) and NAT to your lab's internet connection.
- [ ] Add two non-routable private virtual switches (`vSwitch-StorageA` and `vSwitch-StorageB`) between `RBFE-HOST01` and `RBFE-HOST02` for VLANs 16 and 17.
- [ ] Enable Nested Virtualisation if running `HOST01` and `HOST02` inside a parent hypervisor.

### PowerShell: Configure Host Networking & Nested Virtualisation
Run on your parent Hyper-V host (if nesting) to allow VLAN trunking and nested VMs:

```powershell
# Enable nested virtualisation and MAC spoofing on lab cluster nodes
$Nodes = @("RBFE-HOST01", "RBFE-HOST02")
foreach ($Node in $Nodes) {
    Set-VMProcessor -VMName $Node -ExposeVirtualizationExtensions $true
    Get-VMNetworkAdapter -VMName $Node | Set-VMNetworkAdapter -MacAddressSpoofing On
    Set-VMNetworkAdapterVlan -VMName $Node -Trunk -AllowedVlanIdList "10,16,17,30,100,170" -NativeVlanId 100
}
```

### PowerShell: Configure Hyperconverged Failover Cluster & S2D
Run inside `RBFE-HOST01` (with 2+ empty virtual data disks attached to each node):

```powershell
# Install Failover Clustering and Hyper-V roles on both nodes
Invoke-Command -ComputerName RBFE-HOST01, RBFE-HOST02 -ScriptBlock {
    Install-WindowsFeature -Name Hyper-V, Failover-Clustering -IncludeManagementTools -Restart
}

# Validate and create the cluster
Test-Cluster -Node RBFE-HOST01, RBFE-HOST02 -Include "Storage Spaces Direct", "Inventory", "Network", "System Configuration"
New-Cluster -Name RBFE-CLUSTER -Node RBFE-HOST01, RBFE-HOST02 -StaticAddress 10.100.0.10 -NoStorage

# Enable Storage Spaces Direct (S2D)
Enable-ClusterS2D -CimSession RBFE-CLUSTER -Confirm:$false
New-Volume -FriendlyName "CSV-Workloads" -FileSystem CSVFS_ReFS -StoragePoolFriendlyName "S2D*" -UseMaximumSize
```

---

## 🔐 3. Phase 2: Hybrid Identity & Active Directory Hardening

### Checklist
- [ ] Promote `RBFE-DC01` and `RBFE-DC02` to Domain Controllers for `rbfe.local` (or `://rbfe.com.au`).
- [ ] Structure Organizational Units (OUs) and RBAC Security Groups matching RBFE's company chart.
- [ ] Harden administrative accounts (rename built-in `Administrator`, enforce 14+ character passphrases, create tiered admin accounts).
- [ ] *(Optional)* Install **Microsoft Entra Connect** on `RBFE-DC01` to sync test users to a free M365 Developer / Entra ID tenant and enforce MFA.

### PowerShell: Build RBFE OU Structure, RBAC Groups & Test Users
Run on `RBFE-DC01` after AD DS promotion:

```powershell
Import-Module ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName

# 1. Create Top-Level RBFE OU and Department Sub-OUs
New-ADOrganizationalUnit -Name "RBFE_Corporate" -Path $DomainDN -ProtectedFromAccidentalDeletion $true
$CorpPath = "OU=RBFE_Corporate,$DomainDN"

$Departments = @(
    "Executive",
    "Accounts_HR_IT",
    "Sales_Exports",
    "Retail_Cafes",
    "Warehouse",
    "Farm_Produce",
    "Tier0_Admins",
    "Workstations"
)

foreach ($Dept in $Departments) {
    New-ADOrganizationalUnit -Name $Dept -Path $CorpPath -ProtectedFromAccidentalDeletion $true
    New-ADGroup -Name "GRP_$Dept" -GroupScope Global -GroupCategory Security -Path "OU=$Dept,$CorpPath"
}

# 2. Provision Key Staff Accounts (Enforcing Strong Passphrases)
$Password = ConvertTo-SecureString "RoyalBobs!Pies2026#" -AsPlainText -Force

$Users = @(
    @{Name="Bob Simpson"; Sam="bsimpson"; Dept="Executive"; Title="CEO"},
    @{Name="Sheila Simpson"; Sam="ssimpson"; Dept="Accounts_HR_IT"; Title="Accounts and HR Manager"},
    @{Name="Fiona Simpson"; Sam="fsimpson"; Dept="Sales_Exports"; Title="Sales and Exports Manager"},
    @{Name="Jack Simpson"; Sam="jsimpson"; Dept="Sales_Exports"; Title="Exports Lead"},
    @{Name="Jill Walsh"; Sam="jwalsh"; Dept="Retail_Cafes"; Title="Retail Manager"},
    @{Name="Frank Smith"; Sam="fsmith"; Dept="Warehouse"; Title="Warehouse Manager"},
    @{Name="John Douglas"; Sam="jdouglas"; Dept="Farm_Produce"; Title="Farm Manager"},
    @{Name="IT Admin Tier1"; Sam="adm.ittech"; Dept="Tier0_Admins"; Title="Systems Administrator"}
)

foreach ($u in $Users) {
    $OU = "OU=$($u.Dept),$CorpPath"
    New-ADUser -Name $u.Name -SamAccountName $u.Sam -UserPrincipalName "$($u.Sam)@rbfe.local" `
        -Title \$u.Title -Path OU -AccountPassword Password -Enabled true -ChangePasswordAtLogon false
    Add-ADGroupMember -Identity "GRP_\$(u.Dept)" -Members u.Sam
}

# 3. Essential Eight Hardening: Rename Default Administrator & Enforce Password Policy
Rename-ADObject -Identity (Get-ADUser -Identity "Administrator").DistinguishedName -NewName "rbfe_breakglass"
Set-ADUser -Identity "rbfe_breakglass" -SamAccountName "rbfe_breakglass" -Description "Break-glass emergency account - Do not use for daily tasks"
Set-ADDefaultDomainPasswordPolicy -Identity "rbfe.local" -MinPasswordLength 14 -ComplexityEnabled \$true -LockoutThreshold 5 -LockoutDuration "00:30:00"
```

---

## 🛡️ 4. Phase 3: Firewall, IDPS & Workload Migration Simulation

### Checklist
- [ ] Configure firewall rules on `RBFE-FW01`:
  - **Allow** `VLAN 10 (CORP_LAN)` $\rightarrow$ `WAN` (Internet) and `VLAN 10` internal services.
  - **Allow** `VLAN 30 (CAFE_GUEST)` $\rightarrow$ `WAN` (Internet) **ONLY**.
  - **Block** `VLAN 30 (CAFE_GUEST)` $\rightarrow$ `10.0.0.0/8` (Blocks access to DCs, SQL, and Management).
  - **Allow** `VLAN 100 (MGMT_OOB)` $\leftarrow$ `10.10.0.50` (IT Admin workstation only).
- [ ] Enable **Suricata / Snort IDPS** on `RBFE-FW01` WAN and LAN interfaces in IPS (blocking) mode.
- [ ] Deploy `RBFE-SQL01` on `VLAN 10`, create a dummy `RBFE_Inventory` database, and restrict access exclusively to `GRP_Retail_Cafes` and `GRP_Warehouse`.

---

## ✅ 5. Lab Verification & Sign-Off Tests

Run these validation commands to capture screenshots for your final presentation/report:

### Test 1: Verify Guest Isolation (`CAFE-GUEST01` on VLAN 30)
Log into `CAFE-GUEST01` (`10.30.0.50`) and run PowerShell:
```powershell
# Should SUCCEED (Public Internet)
Test-NetConnection -ComputerName 8.8.8.8 -Port 443

# Should FAIL / TIMEOUT (Blocked Corporate Domain Controller & SQL Server)
Test-NetConnection -ComputerName 10.10.0.10 -Port 389
Test-NetConnection -ComputerName 10.10.0.20 -Port 1433
```

### Test 2: Verify Hyperconverged Live Migration (`RBFE-HOST01` $\leftrightarrow$ `RBFE-HOST02`)
Run on `RBFE-HOST01` to prove zero-downtime failover:
```powershell
# Confirm both nodes are Up and CSV storage is Online
Get-ClusterNode
Get-ClusterSharedVolume

# Perform live migration of Primary DC without dropping pings
Move-ClusterVirtualMachineRole -Name "RBFE-DC01" -Node "RBFE-HOST02"
```

### Test 3: Verify Active Directory Hardening & RBAC
Run on `RBFE-DC01`:
```powershell
# Confirm 14-character password policy and renamed default admin
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, ComplexityEnabled, LockoutThreshold
Get-ADUser -Filter * -SearchBase "OU=RBFE_Corporate,DC=rbfe,DC=local" | Select-Object Name, SamAccountName, Enabled, DistinguishedName
```
