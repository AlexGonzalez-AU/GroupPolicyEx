function Get-GpoReport_GpoLinks {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
        [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
        [switch]$AsCsvFile
    )

    Set-StrictMode -Version 2
    $ErrorActionPreference = 'Stop'

    function Test-XmlProperty {
        [CmdletBinding()]

        param (
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            $XmlPath,
            [Parameter(Mandatory=$true,ValueFromPipeline=$true)]
            [string]$Property
        )

        [string[]]$properties = $XmlPath | 
            Get-Member -MemberType Properties | 
            Select-Object -ExpandProperty Name

        $properties -Contains($Property)
    }

    $sb = {
        foreach ($gpo in (Get-GPO -All -Domain $Domain)) {
            if (!$gpo.displayname) {
                Write-Warning -Message ("GPO is missing from SYSVOL '{0}'" -f $gpo.id.guid)
                continue
            }
            Write-Host ("Checking: '{0}'..." -f $gpo.displayname)

            [xml]$xmlReport = $gpo | Get-GPOReport -ReportType Xml -Domain $Domain

            if (!($xmlReport | Test-XmlProperty -Property 'GPO')) {
                continue
            }
            if (!($xmlReport.GPO | Test-XmlProperty -Property 'LinksTo')) {
                New-Object -TypeName psobject -Property @{
                    GpoDisplayName = $gpo.DisplayName
                    GpoGuid = $gpo.id.guid
                    LinkEnabled = $null
                    LinkEnforced = $null
                    LinkName = $null
                    LinkPath = $null
                }  
                continue
            }
            foreach ($link in $xmlReport.GPO.LinksTo) {
                New-Object -TypeName psobject -Property @{
                    GpoDisplayName = $gpo.DisplayName
                    GpoGuid = $gpo.id.guid
                    LinkEnabled = $link.Enabled
                    LinkEnforced = $link.NoOverride
                    LinkName = $link.SOMName
                    LinkPath = $link.SOMPath
                }       
            }    
        }
    }

    if ($AsCsvFile) {
        & $sb |
            Export-Csv -NoTypeInformation -Path (".\{0} Get-GpoLinks.csv" -f $Domain.Split('.').ToUpper())    
    }
    else {
        & $sb
    }
}