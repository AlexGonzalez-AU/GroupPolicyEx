function Get-GpoReport_GpoInheritanceBlockedOus {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
        [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
        [switch]$AsCsvFile
    )

    $sb = {
        Get-ADOrganizationalUnit -Filter * -Server $Domain -Properties canonicalName | 
            ForEach-Object {
                Write-Host ("Checking: '{0}'..." -f $_.canonicalName)
                $_ | Get-GPInheritance -Domain $Domain
            } | 
            Select-Object -Property Name, ContainerType, Path, GpoInheritanceBlocked, @{
                n = "GpoLinks"; e = {($_ | Select-Object -ExpandProperty GpoLinks | Sort-Object -Property Order | Select-Object -ExpandProperty DisplayName) -join "`n"}
            }, @{
                n = "InheritedGpoLinks"; e = {($_ | Select-Object -ExpandProperty InheritedGpoLinks | Sort-Object -Property Order | Select-Object -ExpandProperty DisplayName) -join "`n"}
            }
    }

    if ($AsCsvFile) {
        & $sb | 
            Export-Csv -NoTypeInformation -Path (".\{0} Get-GpoReport_GpoInheritanceBlockedOus.csv" -f $Domain.Split('.').ToUpper())   
    }
    else {
        & $sb
    }
}