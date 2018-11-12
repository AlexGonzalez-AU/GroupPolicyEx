[string[]]$module = @()

Get-Content -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\Modules\GroupPolicyEx.psd1') |
    Select-String  -SimpleMatch '..\CmdLets\' |
    Select-Object -ExpandProperty Line |
    ForEach-Object {
        $module += Get-Content -Path $_.Trim().Trim(",").Trim("'").ToLower().Replace('..\cmdlets\','..\GroupPolicyEx\CmdLets\')
        $module += ""
    }

$module += @'

# This check is not ideal, need to replace with a propper .psd1 manifest
if (-not (Get-Module -Name ActiveDirectory)) {
    Import-Module ActiveDirectory
}
if (-not (Get-Module -Name GroupPolicy)) {
    Import-Module GroupPolicy
}
'@    

if (-not (Test-Path (Join-Path -Path $PSScriptRoot -ChildPath '..\tmp'))) {
    New-Item -ItemType Directory -Path (Join-Path -Path $PSScriptRoot -ChildPath '..\tmp') 
}

$module |
    Out-File -FilePath (Join-Path -Path $PSScriptRoot -ChildPath '..\tmp\GroupPolicyEx.psm1')