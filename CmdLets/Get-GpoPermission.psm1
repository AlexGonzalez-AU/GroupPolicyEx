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