function Get-GpoReport_GpoAcls {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
        [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
        [switch]$AsCsvFile
    )

    $sb = {
        Get-GPO -All -Domain $Domain | 
            ForEach-Object {
                $gpo = $_
                $gpo | Get-GPPermission -All -Domain $Domain | foreach {
                    $ace = $_
                    New-Object -TypeName psobject -Property @{
                        Gpo_DisplayName = $gpo.DisplayName
                        Gpo_Id = $gpo.Id
                        Trustee_Domain = $ace.Trustee.Domain
                        Trustee_Name = $ace.Trustee.Name
                        Trustee_Sid = $ace.Trustee.Sid
                        Trustee_SidType = $ace.Trustee.SidType
                        Permission = $ace.Permission
                        Inherited = $ace.Inherited
                    }
                }
            }
    }

    if ($AsCsvFile) {
        & $sb | 
            Export-Csv -NoTypeInformation -Path (".\{0} Get-GpoReport_GpoAcls.csv" -f $Domain.Split('.').ToUpper())   
    }
    else {
        & $sb
    }
}