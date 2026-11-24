<#
.SYNOPSIS
    Configures DHCP scopes for RBFE Corporate LAN (VLAN 10) and Café Guest Isolation (VLAN 30).
.NOTES
    Run as Domain Admin on RBFE-DC01 after installing the DHCP feature.
#>

Install-WindowsFeature -Name DHCP -IncludeManagementTools
Add-DhcpServerInDC -DnsName "rbfe-dc01.rbfe.local" -IPAddress "10.10.0.10"

# 1. Corporate LAN Scope (VLAN 10: 10.10.0.0/24)
Add-DhcpServerv4Scope -Name "RBFE_Corp_VLAN10" `
                      -StartRange "10.10.0.50" `
                      -EndRange "10.10.0.200" `
                      -SubnetMask "255.255.255.0" `
                      -State Active

Set-DhcpServerv4OptionValue -ScopeId "10.10.0.0" `
                            -Router "10.10.0.1" `
                            -DnsServer "10.10.0.10", "10.10.0.11" `
                            -DnsDomain "rbfe.local"

# 2. Café Customer Guest Scope (VLAN 30: 10.30.0.0/24 - Public DNS Only)
Add-DhcpServerv4Scope -Name "RBFE_CafeGuest_VLAN30" `
                      -StartRange "10.30.0.50" `
                      -EndRange "10.30.0.200" `
                      -SubnetMask "255.255.255.0" `
                      -State Active

# Assign public DNS (Cloudflare/Google) so guests cannot query internal AD DNS
Set-DhcpServerv4OptionValue -ScopeId "10.30.0.0" `
                            -Router "10.30.0.1" `
                            -DnsServer "1.1.1.1", "8.8.8.8"

Restart-Service -Name DHCPServer
Write-Host "DHCP scopes for VLAN 10 and VLAN 30 configured successfully." -ForegroundColor Green
