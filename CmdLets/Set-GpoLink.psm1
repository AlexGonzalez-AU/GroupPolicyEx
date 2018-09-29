function Set-GpoLink {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject
    )

    begin {
    }
    process {
        Write-Verbose -Message ("[    ] Set-GpoLink : {0} -> {1}" -f $InputObject.DisplayName, $InputObject.LinkTarget)
            if (
                (Get-GPInheritance -Target $InputObject.LinkTarget |
                Select-Object -ExpandProperty GpoLinks |
                Select-Object -ExpandProperty DisplayName) -contains $InputObject.DisplayName
            ) {
                Set-GPLink -Name $_.DisplayName -Target $_.LinkTarget -Order $_.LinkOrder -LinkEnabled $_.LinkEnabled -Enforced $_.LinkEnforced 
            }
            else {
                New-GPLink -Name $_.DisplayName -Target $_.LinkTarget -Order $_.LinkOrder -LinkEnabled $_.LinkEnabled -Enforced $_.LinkEnforced 
            }
    }
    end {
    }
}