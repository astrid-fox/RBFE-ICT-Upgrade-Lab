<#
.SYNOPSIS
    Builds RBFE Active Directory OU structure, RBAC groups, user accounts, and Essential Eight hardening.
.NOTES
    Run as Domain Admin on RBFE-DC01 (Domain: rbfe.local)
#>

Import-Module ActiveDirectory
$DomainDN = (Get-ADDomain).DistinguishedName

# 1. Create Top-Level RBFE Corporate OU
New-ADOrganizationalUnit -Name "RBFE_Corporate" -Path $DomainDN -ProtectedFromAccidentalDeletion $true
$CorpPath = "OU=RBFE_Corporate,$DomainDN"

# 2. Create Department Sub-OUs and Corresponding RBAC Security Groups
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

# 3. Provision Key Staff Accounts Mapped to RBFE Company Structure
$Password = ConvertTo-SecureString "RoyalBobs!Pies2026#" -AsPlainText -Force

$Users = @(
    @{Name="Bob Simpson";    Sam="bsimpson";   Dept="Executive";      Title="CEO"},
    @{Name="Sheila Simpson"; Sam="ssimpson";   Dept="Accounts_HR_IT"; Title="Accounts and HR Manager"},
    @{Name="Fiona Simpson";  Sam="fsimpson";   Dept="Sales_Exports";  Title="Sales and Exports Manager"},
    @{Name="Jack Simpson";   Sam="jsimpson";   Dept="Sales_Exports";  Title="Exports Lead"},
    @{Name="Jill Walsh";     Sam="jwalsh";     Dept="Retail_Cafes";   Title="Retail Manager"},
    @{Name="Frank Smith";    Sam="fsmith";     Dept="Warehouse";      Title="Warehouse Manager"},
    @{Name="John Douglas";   Sam="jdouglas";   Dept="Farm_Produce";   Title="Farm Manager"},
    @{Name="IT Admin Tier1"; Sam="adm.ittech"; Dept="Tier0_Admins";   Title="Systems Administrator"}
)

foreach ($u in $Users) {
    $OU = "OU=$($u.Dept),$CorpPath"
    New-ADUser -Name $u.Name `
               -SamAccountName $u.Sam `
               -UserPrincipalName "$($u.Sam)@rbfe.local" `
               -Title $u.Title `
               -Path $OU `
               -AccountPassword $Password `
               -Enabled $true `
               -ChangePasswordAtLogon $false

    Add-ADGroupMember -Identity "GRP_$($u.Dept)" -Members $u.Sam
}

# 4. Essential Eight Hardening: Rename Default Administrator & Enforce 14-Char Passphrase Policy
$DefaultAdmin = Get-ADUser -Identity "Administrator"
Rename-ADObject -Identity $DefaultAdmin.DistinguishedName -NewName "rbfe_breakglass"
Set-ADUser -Identity "rbfe_breakglass" `
           -SamAccountName "rbfe_breakglass" `
           -Description "Break-glass emergency account - Do not use for daily tasks"

Set-ADDefaultDomainPasswordPolicy -Identity "rbfe.local" `
                                  -MinPasswordLength 14 `
                                  -ComplexityEnabled $true `
                                  -LockoutThreshold 5 `
                                  -LockoutDuration "00:30:00"

Write-Host "RBFE Active Directory structure and Essential Eight hardening completed successfully." -ForegroundColor Green
