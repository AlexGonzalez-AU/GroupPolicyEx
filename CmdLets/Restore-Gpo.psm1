function Restore-Gpo {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=0)]
        $Path,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=1)]
        [switch]$IncludeLinks,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=2)]
        [switch]$LinksOnly,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=3)]
        [switch]$IncludeWmiFilters, 
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=4)]
        [switch]$WmiFiltersOnly,        
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=5)]
        [switch]$IncludePermissions,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=6)]
        [switch]$PermissionsOnly,
        [Parameter(Mandatory=$false,ValueFromPipeline=$false,Position=7,ParameterSetName='Parameter Set 1')]
        [switch]$DoNotMigrateSAMAccountName,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=8,ParameterSetName='Parameter Set 2')]
        [switch]$MigrateSAMAccountNameSameAsSource,          
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=9,ParameterSetName='Parameter Set 3')]
        [switch]$MigrateSAMAccountNameByRelativeName,         
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=10,ParameterSetName='Parameter Set 4')]
        [switch]$MigrateSAMAccountNameUsingMigrationTable,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=11,ParameterSetName='Parameter Set 4')]
        [string]$MigrationTable
    )

    begin {
        $netBiosName_source = Get-Content (Join-Path -Path $Path -ChildPath 'netbiosname').trim()
        $netBiosName_target = Get-ADObject -SearchBase ('CN=Partitions,CN=Configuration,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) -Filter * -Properties netbiosname | 
            Select-Object -ExpandProperty netbiosname

        if ($DoNotMigrateSAMAccountName) {
           $MigrationTable = (Join-Path -Path $Path -ChildPath 'destination.none.migtable') 
        }

        if ($MigrateSAMAccountNameSameAsSource) {
            $MigrationTable = (Join-Path -Path $Path -ChildPath 'destination.sameassource.migtable')
        }

        if ($MigrateSAMAccountNameByRelativeName) {
            $MigrationTable = (Join-Path -Path $Path -ChildPath 'destination.byrelativename.migtable')
        }

        if ($MigrateSAMAccountNameUsingMigrationTable) {
            if (-not (Test-Path $MigrationTable)) {
                Write-Error -Message "Migration table file not found '{$MigrationTable}'."
                break
            }
        }
    }
    process {
        if ((-not $LinksOnly) -and (-not $WmiFiltersOnly) -and (-not $PermissionsOnly)) {
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
        }

        if ($IncludePermissions -or $PermissionsOnly) {
            Import-Csv -Path (Join-Path -Path $Path -ChildPath 'ace.config.csv') | 
                ForEach-Object {
                    if ($_.IsInherited -eq 'False') {
                        $_.__AddRemoveIndicator = 1
                    }
                    $_.IdentityReference = $_.IdentityReference.ToUpper().Replace("$($netBiosName_source.ToUpper())\","$($netBiosName_target.ToUpper())\")
                    if ($_.Parent_canonicalName -like "*/*") {
                        $_.Parent_canonicalName = (([adsi]'LDAP://RootDSE').defaultNamingContext.ToString() -replace('dc=','') -replace(',','.')) + $_.Parent_canonicalName.SubString($_.Parent_canonicalName.IndexOf('/'))
                    }
                    else {
                        $_.Parent_canonicalName = ([adsi]'LDAP://RootDSE').defaultNamingContext -replace('dc=','') -replace(',','.')
                    }    
                    $_.Parent_distinguishedName = $_.Parent_distinguishedName.SubString(0,$_.Parent_distinguishedName.ToUpper().IndexOf('DC=')) + ([adsi]"LDAP://RootDSE").defaultNamingContext
                    $_ | Set-GpoPermission -Force -Verbose:$VerbosePreference
                }
        }

        if ($IncludeWmiFilters -or $WmiFiltersOnly) {
            Import-Csv -Path (Join-Path -Path $Path -ChildPath 'wmifilter.config.csv') | 
                ForEach-Object {
                    if ($_.WmiFilterDescription.Length -lt 1) {
                        $_.WmiFilterDescription = $null
                    }
                    if ($_.WmiFilterQueryList.Length -lt 1) {
                        $_.WmiFilterQueryList = $null
                    }        
                    $_ | Set-GpoWmiFilter -Verbose:$VerbosePreference
                }   
        }

        if ($IncludeLinks -or $LinksOnly) {
            Import-Csv -Path (Join-Path -Path $Path -ChildPath 'link.config.csv') | 
                ForEach-Object {        
                    $_.LinkTarget = $_.LinkTarget.SubString(0,$_.LinkTarget.ToUpper().IndexOf('DC=')) + ([adsi]"LDAP://RootDSE").defaultNamingContext
                    $_ | Set-GpoLink -Verbose:$VerbosePreference
                }
        }
    }
    end {
    }
}