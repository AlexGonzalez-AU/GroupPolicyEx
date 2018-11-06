function Get-GpoWmiFilter {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        [Microsoft.GroupPolicy.Gpo]
        $InputObject
    )

    begin {
    }
    process {
        if ($InputObject.WmiFilter) {
            $wmiFilterGuid = $InputObject.WmiFilter.Path.Split("{")[1].Split("}")[0]

            $objWmiFilter = ActiveDirectory\Get-ADObject -LDAPFilter "(&(objectClass=msWMI-Som)(Name={$wmiFilterGuid}))" `
                -Properties "msWMI-Name", "msWMI-Parm1", "msWMI-Parm2"

            $wmiFilterName        = $objWmiFilter | Select-Object -ExpandProperty "msWMI-Name"
            $wmiFilterDescription = $objWmiFilter | Select-Object -ExpandProperty "msWMI-Parm1"
            $wmiFilterQueryList   = $objWmiFilter | Select-Object -ExpandProperty "msWMI-Parm2"            

            New-Object -TypeName psobject -Property @{
                'Id' = $InputObject.GpoId
                'DisplayName' = $InputObject.DisplayName
                'wmiFilterName' = $wmiFilterName
                'WmiFilterDescription' = $wmiFilterDescription
                'wmiFilterQueryList' = $wmiFilterQueryList
             }
        }
    }
    end {
    }
}