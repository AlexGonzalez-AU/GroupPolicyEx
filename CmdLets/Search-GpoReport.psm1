function Search-GpoReport {
    [CmdletBinding()]

    param (
        [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
        [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.'),
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=1)]    
        [string]$SearchString
    )

    foreach ($gpo in (Get-GPO -All -Domain $Domain)) {
        Write-Host -ForegroundColor Green ("Searching: '{0}'..." -f $gpo.displayname)

        ($gpo | Get-GPOReport -ReportType Html -Domain $Domain).split("`n") |
            Select-String -CaseSensitive -Pattern $SearchString
    }
}