param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
    [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
    [switch]$AsCsvFile
)

Import-Module GroupPolicy

Set-StrictMode -Version 2
$ErrorActionPreference = 'Stop'

function Test-XmlProperty {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        $XmlPath,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
        [string]$Property
    )

    [string[]]$properties = $XmlPath | 
        Get-Member -MemberType Properties | 
        Select-Object -ExpandProperty Name

    $properties -Contains($Property)
}

$sb = {
    foreach ($gpo in (Get-GPO -All -Domain $Domain)) { 
        if (!$gpo.displayname) {
            Write-Warning -Message ("GPO is missing from SYSVOL '{0}'" -f $gpo.id.guid)
            continue
        }
        Write-Host ("Searching: '{0}'..." -f $gpo.displayname)

            [xml]$xmlReport = $gpo | Get-GPOReport -ReportType Xml -Domain $Domain

            if (!($xmlReport | Test-XmlProperty -Property 'GPO')) {
                continue
            }
            if (!($xmlReport.GPO | Test-XmlProperty -Property 'Computer')) {
                continue
            }
            if (!($xmlReport.GPO.Computer | Test-XmlProperty -Property 'ExtensionData')) {
                continue
            }

            foreach ($ExtensionData in $xmlReport.GPO.Computer.ExtensionData) {
                if (!($ExtensionData | Test-XmlProperty -Property 'Extension')) {
                    continue
                }
                if (($ExtensionData.Extension | Test-XmlProperty -Property 'RestrictedGroups')) {
                    foreach ($restrictedGroup in $ExtensionData.Extension.RestrictedGroups) {
                        $groupName = $null
                        if (($restrictedGroup.GroupName | Test-XmlProperty -Property 'Name')) {
                            $groupName = $restrictedGroup.GroupName.Name.'#text'
                        }
                        $groupSid = $null            
                        if (($restrictedGroup.GroupName | Test-XmlProperty -Property 'Sid')) {
                            $groupSid = $restrictedGroup.GroupName.Sid.'#text'
                        }        
        
                        if (!($restrictedGroup | Test-XmlProperty -Property 'Member')) {
                            New-Object -TypeName psobject -Property @{
                                GpoDisplayName = $gpo.DisplayName
                                GpoGuid = $gpo.id.guid
                                Action = 'R'
                                RestrictedGroupName = $groupName
                                RestrictedGroupSid = $groupSid
                                MemberName = '<empty>'
                                MemberSid = '<empty>'
                                LocalGroupName = $null
                                LocalGroupSid = $null
                                SettingType = "Policy:RestrictedGroups"
                            }
                        }
                        else {
                            foreach ($member in $restrictedGroup.Member) {
                                $memberName = $null
                                if (($member | Test-XmlProperty -Property 'Name')) {
                                    $memberName = $member.Name.'#text'
                                }
                                $memberSid = $null            
                                if (($member | Test-XmlProperty -Property 'Sid')) {
                                    $memberSid = $member.Sid.'#text'
                                }        
                                New-Object -TypeName psobject -Property @{
                                    GpoDisplayName = $gpo.DisplayName
                                    GpoGuid = $gpo.id.guid
                                    Action = 'R'
                                    RestrictedGroupName = $groupName
                                    RestrictedGroupSid = $groupSid
                                    MemberName = $memberName
                                    MemberSid = $memberSid
                                    LocalGroupName = $null
                                    LocalGroupSid = $null
                                    SettingType = "Policy:RestrictedGroups"
                                }
                            }
                        }
                    }
                }
        
                if (($ExtensionData.Extension | Test-XmlProperty -Property 'LocalUsersAndGroups')) {
                    if (($ExtensionData.Extension.LocalUsersAndGroups | Test-XmlProperty -Property 'Group')) {
                        foreach ($group in $ExtensionData.Extension.LocalUsersAndGroups.Group) {
                            if (!($group.Properties.Members | Test-XmlProperty -Property 'Member')) {
                                New-Object -TypeName psobject -Property @{
                                    GpoDisplayName = $gpo.DisplayName
                                    GpoGuid = $gpo.id.guid
                                    Action = $group.Properties.action
                                    RestrictedGroupName = $null
                                    RestrictedGroupSid = $null
                                    MemberName = '<empty>'
                                    MemberSid = '<empty>'
                                    LocalGroupName = $group.Properties.groupName
                                    LocalGroupSid = $group.Properties.groupSid
                                    SettingType = "Preferences:LocalUsersAndGroups"
                                }
                            }
                            else {            
                                foreach ($member in $group.Properties.Members.Member) {
                                    New-Object -TypeName psobject -Property @{
                                        GpoDisplayName = $gpo.DisplayName
                                        GpoGuid = $gpo.id.guid
                                        Action = $group.Properties.action
                                        RestrictedGroupName = $null
                                        RestrictedGroupSid = $null
                                        MemberName = "[{0}] {1}" -f $member.action, $member.name
                                        MemberSid = "[{0}] {1}" -f $member.action, $member.sid
                                        LocalGroupName = $group.Properties.groupName
                                        LocalGroupSid = $group.Properties.groupSid
                                        SettingType = "Preferences:LocalUsersAndGroups"
                                    }
                                }
                            }
                        }
                    }
                }
            }
    }
}

if ($AsCsvFile) {
    & $sb | 
        Export-Csv -NoTypeInformation -Path (".\{0} Get-GpoReport_RestrictedGroups.csv" -f $Domain.Split('.').ToUpper())   
}
else {
    & $sb
}