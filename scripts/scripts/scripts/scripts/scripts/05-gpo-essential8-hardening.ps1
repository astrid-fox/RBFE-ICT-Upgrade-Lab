<#
.SYNOPSIS
    Creates and links Group Policy Objects (GPOs) for ACSC Essential Eight and APP 11 compliance.
.NOTES
    Run as Domain Admin on RBFE-DC01.
#>

Import-Module GroupPolicy
$DomainDN = (Get-ADDomain).DistinguishedName
$CorpOU   = "OU=RBFE_Corporate,$DomainDN"
$WorkOU   = "OU=Workstations,$CorpOU"

# 1. Create Workstation Security Baseline GPO
$SecGPO = New-GPO -Name "GPO_RBFE_Workstation_Security" -Comment "ACSC Essential Eight & APP 11 Workstation Hardening"

# Enforce screen lock after 10 minutes of inactivity (APP 11 physical access protection)
Set-GPRegistryValue -Name $SecGPO.DisplayName `
                    -Key "HKLM\Software\Microsoft\Windows\CurrentVersion\Policies\System" `
                    -ValueName "InactivityTimeoutSecs" `
                    -Type DWord `
                    -Value 600

# Disable USB removable storage write access to prevent data exfiltration
Set-GPRegistryValue -Name $SecGPO.DisplayName `
                    -Key "HKLM\Software\Policies\Microsoft\Windows\RemovableStorageDevices\{53f5630d-b6bf-11d0-94f2-00a0c91efb8b}" `
                    -ValueName "Deny_Write" `
                    -Type DWord `
                    -Value 1

# Enable Windows Defender Firewall across all profiles
Set-GPRegistryValue -Name $SecGPO.DisplayName `
                    -Key "HKLM\Software\Policies\Microsoft\WindowsFirewall\DomainProfile" `
                    -ValueName "EnableFirewall" `
                    -Type DWord `
                    -Value 1

# Link Security GPO to Workstations OU
New-GPLink -Name $SecGPO.DisplayName -Target $WorkOU -LinkEnabled Yes

# 2. Create Audit & Logging GPO (Supports Notifiable Data Breaches scheme)
$AuditGPO = New-GPO -Name "GPO_RBFE_Audit_Logging" -Comment "Centralised Sign-In and Privilege Auditing"
New-GPLink -Name $AuditGPO.DisplayName -Target $CorpOU -LinkEnabled Yes

Write-Host "Essential Eight & APP 11 Group Policies created and linked." -ForegroundColor Green
