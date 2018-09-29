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