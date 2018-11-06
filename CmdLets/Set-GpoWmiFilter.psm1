function Set-GpoWmiFilter {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)] 
        $InputObject
    )

    begin {
    }
    process {
        Write-Verbose -Message ("[    ] Set-GpoWmiFilter : {0} -> {1}" -f $InputObject.WmiFilterName, $InputObject.DisplayName)

        $objWmiFilter = ActiveDirectory\Get-ADObject -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$($InputObject.WmiFilterName)))" `
                -Properties "msWMI-Name", "msWMI-Parm1", "msWMI-Parm2"

        if (($objWmiFilter | Measure-Object).Count -gt 1) {
            $wmiFilterName =  $objWmiFilter | Select-Object -ExpandProperty "msWMI-Name"
            Write-Error -Message "There are multiple WMI Filters named '$wmiFilterName'."
            break
        }
        elseif (($objWmiFilter | Measure-Object).Count -eq 1) {
            $wmiFilterName =  $objWmiFilter | Select-Object -ExpandProperty "msWMI-Name"
            $wmiFilterDescription =  $objWmiFilter | Select-Object -ExpandProperty "msWMI-Parm1"
            $wmiFilterQueryList =  $objWmiFilter | Select-Object -ExpandProperty "msWMI-Parm2"
            
            if (($wmiFilterQueryList -ne $InputObject.WmiFilterQueryList) -and ($wmiFilterDescription -ne $InputObject.WmiFilterDescription)) {
                Write-Error -Message "A WMI Filter named '$wmiFilterName' already exists with a different Query List and Description."
                break
            }
            elseif ($wmiFilterQueryList -ne $InputObject.WmiFilterQueryList) {
                Write-Error -Message "A WMI Filter named '$wmiFilterName' already exists with a different Query List."
                break
            }
            elseif ($wmiFilterDescription -ne $InputObject.WmiFilterDescription) {
                Write-Error -Message "A WMI Filter named '$wmiFilterName' already exists with a different Description."
                break
            }
        } 
        else {
            $defaultNamingContext = (Get-ADRootDSE).DefaultNamingContext

            $guid = [System.Guid]::NewGuid()
            $msWMICreationDate = (Get-Date).ToUniversalTime().ToString("yyyyMMddhhmmss.ffffff-000")
            
            $otherAttributes = @{
                "msWMI-Name" = $InputObject.wmiFilterName;
                "msWMI-Parm1" = $InputObject.WmiFilterDescription;
                "msWMI-Parm2" = $InputObject.wmiFilterQueryList;
                "msWMI-ID"= "{$guid}";
                "instanceType" = 4;
                "showInAdvancedViewOnly" = "TRUE";
                "distinguishedname" = "CN={$guid},CN=SOM,CN=WMIPolicy,CN=System,$defaultNamingContext";
                "msWMI-ChangeDate" = $msWMICreationDate; 
                "msWMI-CreationDate" = $msWMICreationDate
            }

            if ($InputObject.WmiFilterDescription -eq $null) { 
                $otherAttributes.Remove("msWMI-Parm1") 
            }
            if ($InputObject.wmiFilterQueryList -eq $null) {
                $otherAttributes.Remove("msWMI-Parm2") 
            }
                
            New-ADObject -Name "{$guid}" -Type "msWMI-Som" -Path ("CN=SOM,CN=WMIPolicy,CN=System,$defaultNamingContext") -OtherAttributes $otherAttributes -PassThru
        }

        $objWmiFilter = ActiveDirectory\Get-ADObject -LDAPFilter "(&(objectClass=msWMI-Som)(msWMI-Name=$($InputObject.wmiFilterName)))" `
            -Properties "msWMI-Name", "msWMI-Parm1", "msWMI-Parm2"

        $gpDomain = New-Object -Type Microsoft.GroupPolicy.GPDomain

        $gpo = Get-GPO -DisplayName $InputObject.DisplayName
        $gpo.WmiFilter = $gpDomain.GetWmiFilter('MSFT_SomFilter.ID="' + $objWmiFilter.Name + '",Domain="' + $gpDomain.DomainName +'"')
    }
    end {
    }
}