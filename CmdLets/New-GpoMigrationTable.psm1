function New-GpoMigrationTable {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=0)]
        $Path,
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=1)]
        [string]
        $GpoDisplayName
    )

    begin {
        $netbiosname = Get-ADObject -SearchBase ('CN=Partitions,CN=Configuration,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) -Filter * -Properties netbiosname | 
            Select-Object -ExpandProperty netbiosname
        
        [string[]]$samAccountNames = @()
        
        [string[]]$migTable_mapN = '<?xml version="1.0" encoding="utf-16"?>'
        [string[]]$migTable_mapS = '<?xml version="1.0" encoding="utf-16"?>'
        [string[]]$migTable_mapR = '<?xml version="1.0" encoding="utf-16"?>'

        $migTable_mapN += '<MigrationTable xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations/MigrationTable">'
        $migTable_mapS += '<MigrationTable xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations/MigrationTable">'
        $migTable_mapR += '<MigrationTable xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations/MigrationTable">'
    }
    process {
        $r = Get-GPOReport -DisplayName $GpoDisplayName -ReportType Html
        [regex]::Matches($r,'(?xi) ' + $netbiosname + ' \\ [\w\s]+') |
            Select-Object -ExpandProperty value | 
            ForEach-Object {
                if (-not ($samAccountNames -contains $_)) {
                    $samAccountNames += $_
                    $o = Get-ADObject -LDAPFilter ("(samAccountName={0})" -f ($_ | Split-Path -Leaf))

                    switch ($o | Select-Object -ExpandProperty ObjectClass) {
                        'user'          {$type = 'User'}
                        'inetOrgPerson' {$type = 'User'}
                        'computer'      {$type = 'Computer'}
                        'group'         {
                                            $type = "{0}Group" -f ($o | Get-ADGroup | Select-Object -ExpandProperty GroupScope) -replace 'domain',''
                                        }
                        default         {$type = 'Unknown' }
                    }

                    $migTable_mapN += '<Mapping>'
                    $migTable_mapS += '<Mapping>'
                    $migTable_mapR += '<Mapping>'

                    $migTable_mapN += "<Type>{0}</Type>" -f $type
                    $migTable_mapS += "<Type>{0}</Type>" -f $type
                    $migTable_mapR += "<Type>{0}</Type>" -f $type

                    $migTable_mapN += "<Source>{0}</Source>" -f $_
                    $migTable_mapS += "<Source>{0}</Source>" -f $_
                    $migTable_mapR += "<Source>{0}</Source>" -f $_
                    
                    $migTable_mapN += '<DestinationNone />'
                    $migTable_mapS += '<DestinationSameAsSource />'
                    $migTable_mapR += '<DestinationByRelativeName />'

                    $migTable_mapN += '</Mapping>'
                    $migTable_mapS += '</Mapping>'
                    $migTable_mapR += '</Mapping>'
                }
            }
    }
    end {
        $migTable_mapN += '</MigrationTable>'
        $migTable_mapS += '</MigrationTable>'
        $migTable_mapR += '</MigrationTable>'
        
        $migTable_mapN | Out-File -FilePath (Join-Path -Path $Path -ChildPath 'destination.none.migtable')
        $migTable_mapS | Out-File -FilePath (Join-Path -Path $Path -ChildPath 'destination.sameassource.migtable')
        $migTable_mapR | Out-File -FilePath (Join-Path -Path $Path -ChildPath 'destination.byrelativename.migtable')
    }
}