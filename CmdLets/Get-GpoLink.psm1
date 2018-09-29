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