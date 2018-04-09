function Get-GpoPermission {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        [Microsoft.GroupPolicy.Gpo]   
        $InputObject
    )

    begin {
    }
    process {
        [adsi]('LDAP://CN={' + $InputObject.Id.Guid + '},CN=Policies,CN=System,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) |
            Get-ADObjectAccessRight |
            ForEach-Object {
                $_.Parent_canonicalName = $_.Parent_canonicalName.ToLower().Replace("$($InputObject.Id.Guid.ToLower())","$($InputObject.DisplayName)")
                $_.Parent_distinguishedName = $_.Parent_distinguishedName.ToLower().Replace("$($InputObject.Id.Guid.ToLower())","$($InputObject.DisplayName)")
                $_
            }
    }
    end {
    } 
}

function Set-GpoPermission {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=1)]
        [switch]
        $Force = $false
    )

    begin {
    }
    process {
        $gpo = Get-GPO -DisplayName $InputObject.Parent_canonicalName.split('/')[-1].Trim('{}')
        Write-Verbose -Message ("[    ] Set-GpoPermission : {0}" -f $gpo.DisplayName)
        $_.Parent_canonicalName = $_.Parent_canonicalName.ToLower().Replace("$($gpo.DisplayName.ToLower())","$($gpo.Id.Guid)")
        $_.Parent_distinguishedName = $_.Parent_distinguishedName.ToLower().Replace("$($gpo.DisplayName.ToLower())","$($gpo.Id.Guid)")
        $_.Parent_distinguishedName |
            Get-ADDirectoryEntry |             
            Remove-ADObjectAccessRight `
                -IdentityReference 'NT AUTHORITY\Authenticated Users' `
                -ActiveDirectoryRights 'ExtendedRight' `
                -AccessControlType 'Allow' `
                -ObjectType 'edacfd8f-ffb3-11d1-b41d-00a0c968f939' `
                -InheritanceType 'All' `
                -InheritedObjectType '00000000-0000-0000-0000-000000000000' `
                -Confirm:(-not $Force)       
        $_ | Set-ADObjectAccessRight -Force:($Force)
    }
    end {
    } 
}

function Get-GpoLink {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        [Microsoft.GroupPolicy.Gpo]   
        $InputObject
    )

    begin {
        $gpoLinks = [string[]](Get-ADOrganizationalUnit -Filter * | Select-Object -ExpandProperty distinguishedName) + `
            [string[]]([adsi]'LDAP://RootDSE').defaultNamingContext |
                Get-GPInheritance |
                Select-Object -ExpandProperty GpoLinks
    }
    process {
        $gpoLinks |
            Where-Object {
                $_.DisplayName -eq $InputObject.DisplayName
            } |
            ForEach-Object {
                if ($_.Enabled) {$linkEnabled = 'Yes'} else {$linkEnabled = 'No'}
                if ($_.Enforced) {$linkEnforced = 'Yes'} else {$linkEnforced = 'No'}
                New-Object -TypeName psobject -Property @{
                   'Id' = $_.GpoId
                   'DisplayName' = $_.DisplayName
                   'LinkOrder' = $_.Order
                   'LinkEnabled' = $linkEnabled
                   'LinkEnforced' = $linkEnforced
                   'LinkTarget' = $_.Target
                }
            }
    }
    end {
    } 
}

function Set-GpoLink {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject
    )

    begin {
    }
    process {
        Write-Verbose -Message ("[    ] Set-GpoLink : {0} -> {1}" -f $InputObject.DisplayName, $InputObject.LinkTarget)
            if (
                (Get-GPInheritance -Target $InputObject.LinkTarget |
                Select-Object -ExpandProperty GpoLinks |
                Select-Object -ExpandProperty DisplayName) -contains $InputObject.DisplayName
            ) {
                Set-GPLink -Name $_.DisplayName -Target $_.LinkTarget -Order $_.LinkOrder -LinkEnabled $_.LinkEnabled -Enforced $_.LinkEnforced 
            }
            else {
                New-GPLink -Name $_.DisplayName -Target $_.LinkTarget -Order $_.LinkOrder -LinkEnabled $_.LinkEnabled -Enforced $_.LinkEnforced 
            }
    }
    end {
    }
}

function Get-GpoWmiFiler {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject
    )

    begin {
    }
    process {

    }
    end {
    }
}

function Set-GpoWmiFiler {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject
    )

    begin {
    }
    process {

    }
    end {
    }
}

function Backup-Gpo {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        [Microsoft.GroupPolicy.Gpo]   
        $InputObject,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=1)]
        $Path
    )

    begin {
        if (Test-Path -Path $Path) {
            Write-Error -Message ("An item with the specified name '{0}' already exists." -f $Path)
            break
        }
        $Path = New-Item -Force -ItemType Directory -Path $Path
    }
    process {
        if ($InputObject.DisplayName.EndsWith(' ')) {
            Write-Warning ("Not backing up policy '{0}' because it's DisplayName ends with a space (' ')." -f $InputObject.DisplayName)
        }
        elseif ($InputObject.DisplayName.StartsWith(' ')) {
            Write-Warning ("Not backing up policy '{0}' because it's DisplayName starts with a space (' ')." -f $InputObject.DisplayName)
        }
        else {
            $InputObject | 
                GroupPolicy\Backup-GPO -Path $Path |
                Export-Csv -Append -NoTypeInformation -Path (Join-Path -Path $Path -ChildPath 'policy.config.csv')
            $InputObject |
                Get-GpoPermission |
                Export-Csv -Append -NoTypeInformation -Path (Join-Path -Path $Path -ChildPath 'ace.config.csv')
            $InputObject | 
                Get-GpoLink |
                Export-Csv -Append -NoTypeInformation -Path (Join-Path -Path $Path -ChildPath 'link.config.csv')                
        }
    }
    end {
        Get-ADObject -SearchBase ('CN=Partitions,CN=Configuration,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) -Filter * -Properties netbiosname | 
            Select-Object -ExpandProperty netbiosname |
            Out-File -FilePath (Join-Path -Path $Path -ChildPath 'ace.netbiosname')
    }
}

function Restore-Gpo {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=0)]
        $Path,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=1)]
        [string]
        $MigrationTable=""
    )

    begin {
        $netBiosName_source = Get-Content (Join-Path -Path $Path -ChildPath 'ace.netbiosname').trim()
        $netBiosName_target = Get-ADObject -SearchBase ('CN=Partitions,CN=Configuration,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) -Filter * -Properties netbiosname | 
            Select-Object -ExpandProperty netbiosname  
    }
    process {
        Import-Csv -Path (Join-Path -Path $Path -ChildPath 'policy.config.csv') | 
            ForEach-Object {
                Write-Verbose -Message ("[    ] Restore-Gpo : {0}" -f $_.DisplayName)
                if ($MigrationTable.Length -gt 0) {
                    GroupPolicy\Import-GPO -CreateIfNeeded -BackupGpoName $_.DisplayName -TargetName $_.DisplayName -Path $Path -MigrationTable $MigrationTable
                } 
                else {
                    GroupPolicy\Import-GPO -CreateIfNeeded -BackupGpoName $_.DisplayName -TargetName $_.DisplayName -Path $Path
                }
            }

        Import-Csv -Path (Join-Path -Path $Path -ChildPath 'ace.config.csv') | 
            ForEach-Object {
                if ($_.IsInherited -eq 'False') {
                    $_.__AddRemoveIndicator = 1
                }
                $_.IdentityReference = $_.IdentityReference.ToUpper().Replace("$($netBiosName_source.ToUpper())\","$($netBiosName_target.ToUpper())\")
                $_.Parent_canonicalName = (([adsi]'LDAP://RootDSE').defaultNamingContext -replace('dc=','') -replace(',','.')) + $_.Parent_canonicalName.SubString($_.Parent_canonicalName.IndexOf('/'))
                $_.Parent_distinguishedName = $_.Parent_distinguishedName.SubString(0,$_.Parent_distinguishedName.ToUpper().IndexOf('DC=')) + ([adsi]"LDAP://RootDSE").defaultNamingContext
                $_ | Set-GpoPermission -Force -Verbose:$VerbosePreference
            }

        Import-Csv -Path (Join-Path -Path $Path -ChildPath 'link.config.csv') | 
            ForEach-Object {        
                $_.LinkTarget = $_.LinkTarget.SubString(0,$_.LinkTarget.ToUpper().IndexOf('DC=')) + ([adsi]"LDAP://RootDSE").defaultNamingContext
                $_ | Set-GpoLink -Verbose:$VerbosePreference
            }
    }
    end {
    }
}

# This check is not ideal, need to replace with a propper .psd1 manifest
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory
}
if (-not (Get-Module -Name GroupPolicy)) {
    Import-Module GroupPolicy
}
if (-not (Get-Module -Name ADObjectAccessRight)) {
    Write-Error -Message "This module requires the 'ADObjectAccessRight' module. Import the 'ADObjectAccessRight' module and then try to import this module again."
    Export-ModuleMember
    break
}

Export-ModuleMember `
    -Function @(
        'Get-GpoPermission',
        'Set-GpoPermission',
        'Get-GpoLink',
        'Set-GpoLink',
        'Backup-Gpo',
        'Restore-Gpo'
    )