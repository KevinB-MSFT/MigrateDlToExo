#########################################################################################
# LEGAL DISCLAIMER
# This Sample Code is provided for the purpose of illustration only and is not
# intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
# RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
# EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
# MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
# nonexclusive, royalty-free right to use and modify the Sample Code and to
# reproduce and distribute the object code form of the Sample Code, provided
# that You agree: (i) to not use Our name, logo, or trademarks to market Your
# software product in which the Sample Code is embedded; (ii) to include a valid
# copyright notice on Your software product in which the Sample Code is embedded;
# and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
# against any claims or lawsuits, including attorneys’ fees, that arise or result
# from the use or distribution of the Sample Code.
# 
# This posting is provided "AS IS" with no warranties, and confers no rights. Use
# of included script samples are subject to the terms specified at 
# https://www.microsoft.com/en-us/legal/intellectualproperty/copyright/default.aspx.
#
#Migrate-DL.Ps1
#  
# Created by: Kevin Bloom Kevin.Bloom@Microsoft.com 
#
#########################################################################################
# This script will prompt for a DL name, read the DL settings from AD, update it it's AD object so AADC will no longer sync it, runs an AADC sync, and re-create the DL as a net-new DL in EXO
#
# It's best to run this script on the AADC server so it can trigger an AADC sync
# Reguires Exchnage Online and Active Directory PowerShell module already installed on the machine running the script
# Script should be ran with an account that has rights to run an AADC sync and modify the Dl's AD properties.
#
#########################################################################################

#Connects to Exchange Online
Write-Host -ForegroundColor cyan "Connecting to Exchange Online PowerShell"
Connect-ExchangeOnline
Import-MOdule ActiveDirectory
Write-Host -ForegroundColor Green "Connected to Exchange Online PowerShell"

#cd C:\Scripts\DLs
$DlName = Read-Host "Enter Dl name"
try {$DL = Get-ADGroup $DlName -Properties mail,displayname,legacyExchangeDN,mailNickname,managedBy,proxyAddresses,msExchHideFromAddressLists}
Catch 
{
    $DlName = Read-Host "Bad DL name, re-enter Dl name"
    $DL = Get-ADGroup $DlName -Properties mail,displayname,legacyExchangeDN,mailNickname,managedBy,proxyAddresses,msExchHideFromAddressLists
}

#Get DL members
$DLMembers = (Get-ADGroupMember $dl | Get-ADUser -Properties mail,objectguid | select mail,objectGUID).mail

#Get DL Info
$DLDisplayName = $dl.DisplayName
$DLMail = $dl.mail
$DLLegExchDN = $dl.legacyExchangeDN
$DLLegExchDNX500 = "X500:"+$DLLegExchDN
$DLMailKnickName = $dl.mailNickname
$DlManagedBy = (Get-ADUser -Identity ($dl.ManagedBy) -Properties mail | select mail).mail
$DLProxy = $Dl.proxyAddresses
#$DLHideFromAddressLists = $dl.msexchhidefromaddresslists 

#Stop Syncing DL
Set-ADGroup $Dl -Replace @{adminDescription = 'Group_'}

#Forces a DirSync and waits 3 minutes for the sync to run
Write-Host -ForegroundColor Green "Starting DirSync"
Start-ADSyncSyncCycle -PolicyType delta
Write-Host "Pausing for 3 minutes for DirSync Replication"
Start-Sleep -Seconds 180

#Re-creates the DL in O365
Write-Host -ForegroundColor Cyan "creating $DLDisplayName"
New-DistributionGroup -Name $DLDisplayName -DisplayName $DLDisplayName -Alias $DLMailKnickName -PrimarySmtpAddress $DLMail -Notes "Recreated from on-prem" -MemberDepartRestriction closed -MemberJoinRestriction closed
Set-DistributionGroup -Identity $DLMail -EmailAddresses $DLProxy
Set-DistributionGroup -iDentity $DLMail -ManagedBy $DlManagedBy
#If ($DLHideFromAddressLists -eq $true) {Set-DistributionGroup -Identity $DLMail -HiddenFromAddressListsEnabled $true}
Write-Host -ForegroundColor Cyan "Adding members to $DLDisplayName"
    foreach ($member in $DLMembers)
    {
        Add-DistributionGroupMember -Identity $DLMail -Member $member
    }
Set-DistributionGroup -Identity $DLMail -EmailAddresses @{add = $DLLegExchDNX500}
