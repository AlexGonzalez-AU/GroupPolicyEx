function Get-GpoReport_AllowLogonRights {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
        [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
        [switch]$AsCsvFile
    )

    Import-Module GroupPolicy

    $sb = {
        foreach ($gpo in (Get-GPO -All -Domain $Domain)) {
            if (!$gpo.displayname) {
                Write-Warning -Message ("GPO is missing from SYSVOL '{0}'" -f $gpo.id.guid)
                continue
            }
            Write-Host ("Searching: '{0}'..." -f $gpo.displayname)

            ($gpo | Get-GPOReport -ReportType Html -Domain $Domain).split("`n") |
                Select-String -CaseSensitive -Pattern @(
                    "^<tr><td>Access this computer from the network", 
                    "^<tr><td>Allow log on locally",
                    "^<tr><td>Allow log on through Terminal Services",
                    "^<tr><td>Log on as a batch job",
                    "^<tr><td>Log on as a service"
                ) |
                ForEach-Object {
                    foreach ($identity in ($_.line.replace("<tr><td>","").replace("</td><td>","`t").replace("</td></tr>","").split("`t")[1].replace(", ",",").split(","))) {
                        New-Object -TypeName psobject -Property @{ 
                            GpoDisplayName = $gpo.DisplayName
                            GpoGuid = $gpo.id.guid
                            UserRightsAssignment = $_.line.replace("<tr><td>","").replace("</td><td>","`t").replace("</td></tr>","").split("`t")[0]
                            Identity = $identity
                        }
                    }
                }
        }
    }

    if ($AsCsvFile) {
        & $sb |
            Export-Csv -NoTypeInformation -Path (".\{0} Get-GpoReport_AllowLogonRights.csv" -f $Domain.Split('.').ToUpper())    
    }
    else {
        & $sb
    }
}