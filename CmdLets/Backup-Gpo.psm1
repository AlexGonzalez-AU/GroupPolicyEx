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
            $InputObject | 
                Get-GpoWmiFilter |
                Export-Csv -Append -NoTypeInformation -Path (Join-Path -Path $Path -ChildPath 'wmifilter.config.csv')                                 
        }
    }
    end {
        Get-ADObject -SearchBase ('CN=Partitions,CN=Configuration,' + ([adsi]'LDAP://RootDSE').defaultNamingContext) -Filter * -Properties netbiosname | 
            Select-Object -ExpandProperty netbiosname |
            Out-File -FilePath (Join-Path -Path $Path -ChildPath 'netbiosname')

        Import-Csv -Path (Join-Path -Path $Path -ChildPath 'policy.config.csv') | 
            Select-Object -ExpandProperty DisplayName |
            New-GpoMigrationTable -Path $Path
    }
}