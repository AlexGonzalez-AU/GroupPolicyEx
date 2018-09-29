break 

param (
    [Parameter(Mandatory=$false,ValueFromPipeline=$true,Position=0)]    
    [string]$Domain = (New-Object system.directoryservices.directoryentry).distinguishedname.tolower().replace('dc=','').replace(',','.')
)

Import-Module GroupPolicy

Get-GPO -All -Domain $Domain | 
    ForEach-Object {
        Write-Host ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Enterprise Admins' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        Write-Output ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Enterprise Admins' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        $_ | Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Enterprise Admins' -TargetType Group -DomainName $Domain  
    
        Write-Host ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Domain Admins' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        Write-Output ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Domain Admins' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        $_ | Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'Domain Admins' -TargetType Group -DomainName $Domain
    
        Write-Host ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'SYSTEM' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        Write-Output ("[{0}] Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'SYSTEM' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        $_ | Set-GPPermissions -PermissionLevel GpoEditDeleteModifySecurity -TargetName 'SYSTEM' -TargetType Group -DomainName $Domain
    
        Write-Host ("[{0}] Set-GPPermissions -PermissionLevel GpoRead -TargetName 'Authenticated Users' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        Write-Output ("[{0}] Set-GPPermissions -PermissionLevel GpoRead -TargetName 'Authenticated Users' -TargetType Group -DomainName $Domain" -f $_.DisplayName)
        $_ | Set-GPPermissions -PermissionLevel GpoRead -TargetName 'Authenticated Users' -TargetType Group -DomainName $Domain

        Write-Host ("[{0}] Set-GPPermissions -PermissionLevel GpoRead -TargetName 'ENTERPRISE DOMAIN CONTROLLERS' -TargetType Group -DomainName $Domain " -f $_.DisplayName)
        Write-Output ("[{0}] Set-GPPermissions -PermissionLevel GpoRead -TargetName 'ENTERPRISE DOMAIN CONTROLLERS' -TargetType Group -DomainName $Domain " -f $_.DisplayName)
        $_ | Set-GPPermissions -PermissionLevel GpoRead -TargetName 'ENTERPRISE DOMAIN CONTROLLERS' -TargetType Group -DomainName $Domain 
    } | 
    Out-File -FilePath ".\ADH-GPPermissions_$($Domain).txt"