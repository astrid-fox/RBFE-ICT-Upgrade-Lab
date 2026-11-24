<#
.SYNOPSIS
    Validation test suite for RBFE Lab (Guest Isolation, Cluster Failover, and AD Compliance).
#>

# --- TEST 1: Run on CAFE-GUEST01 (VLAN 30) to verify network isolation ---
Write-Host "=== TEST 1: Guest VLAN 30 Isolation ===" -ForegroundColor Cyan
# Expected: TcpTestSucceeded = True (Internet allowed)
Test-NetConnection -ComputerName 8.8.8.8 -Port 443 | Select-Object ComputerName, RemotePort, TcpTestSucceeded

# Expected: TcpTestSucceeded = False (Corporate DC & SQL blocked)
Test-NetConnection -ComputerName 10.10.0.10 -Port 389 | Select-Object ComputerName, RemotePort, TcpTestSucceeded
Test-NetConnection -ComputerName 10.10.0.20 -Port 1433 | Select-Object ComputerName, RemotePort, TcpTestSucceeded


# --- TEST 2: Run on RBFE-HOST01 to verify Hyperconverged Cluster & Live Migration ---
Write-Host "=== TEST 2: Hyper-V Cluster & Live Failover ===" -ForegroundColor Cyan
Get-ClusterNode | Select-Object Name, State
Get-ClusterSharedVolume | Select-Object Name, State
Move-ClusterVirtualMachineRole -Name "RBFE-DC01" -Node "RBFE-HOST02"


# --- TEST 3: Run on RBFE-DC01 to verify AD Hardening & User Provisioning ---
Write-Host "=== TEST 3: Active Directory Hardening & OUs ===" -ForegroundColor Cyan
Get-ADDefaultDomainPasswordPolicy | Select-Object MinPasswordLength, ComplexityEnabled, LockoutThreshold, LockoutDuration
Get-ADUser -Filter * -SearchBase "OU=RBFE_Corporate,DC=rbfe,DC=local" | Select-Object Name, SamAccountName, Title, Enabled
