function Patch-GpoGptTmplFile_UserRightsAssignment {
    [CmdletBinding()]

    param(
        [Parameter(Mandatory=$true,ValueFromPipeline=$true,Position=0)]    
        [Microsoft.GroupPolicy.Gpo]$InputObject,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=1)]    
        [String]$PDCe,
        [Parameter(Mandatory=$true,ValueFromPipeline=$false,Position=2)]    
        [String]$BackupPath = "C:\Temp\Patch-GPOGptTmplFile"
    )

    begin {
        Set-StrictMode -Version 2
        $ErrorActionPreference = 'Stop'
        
        # Get the sids for groups to add to each user rights assignment below
        [array]$SidStrings = @()
        $SidStrings += (Get-ADGroup -Identity "Group 0").Sid.Value
        $SidStrings += (Get-ADGroup -Identity "Group 1").Sid.Value

        # This script should be run on the PDCe for best results
        if (-not (Get-WmiObject -ComputerName $PDCe -Query "Select * from Win32_ComputerSystem where DomainRole = 5")) {
            Write-Error -Message "This script is required to be run against the PDCe. The computer specified '{$PDCe}' is not the PDCe. Run 'netdom query fsmo' on any domain controller to find the PDCe."
            break
        }

        # Create a backup directory to copy the 'GptTmpl.inf' files to before patching them
        $backupDir = mkdir (Join-Path -Path $backupPath -ChildPath (Get-Date).ToString("yyyyMMdd HHmmss")) -force
        Write-Output ("Backup location: '{0}'`n" -f $backupDir.FullName)
    }

    process {
        $infPath = ("\\" + $PDCe + "\SYSVOL\" + $InputObject.DomainName + "\Policies\{"  + $InputObject.Id + "}\Machine\Microsoft\Windows NT\SecEdit\GptTmpl.inf" )
        
        if (Test-Path $infPath) {
            Copy-Item -Path $infPath -Destination (mkdir (Join-Path -Path $backupDir -ChildPath ("{" + $InputObject.Id + "}\Machine\Microsoft\Windows NT\SecEdit\")) -Force)
            $inf = Get-Content -Path $infPath -Encoding Unicode
    
            [array]$file = @()
            $section = $false
            $patched = $false
            for ($i = 0; $i -lt $inf.length; $i++) {
                $line = $inf[$i]
                if ($line.StartsWith('[')) {
                    $section = $false 
                }
                if ($section) {
                    if ($line.StartsWith('SeDenyBatchLogonRight') -or $line.StartsWith('SeDenyServiceLogonRight') -or $line.StartsWith('SeDenyInteractiveLogonRight') -or $line.StartsWith('SeDenyRemoteInteractiveLogonRight')) {
                        foreach ($SidString in $SidStrings) {
                            $match = $false
                            $line.Split("=")[1].trim().Split(",") |
                                ForEach-Object {
                                    if ($_.trim('*') -eq $SidString) {
                                        $match = $true
                                    }
                                }
                            if ($match) {
                                # Do nothing, the group is already there
                            }
                            else {
                                $patched = $true
                                # Append the sid to the line and save the file
                                if ($line.Split("=")[1].trim().Length -gt 0) {
                                    $line = $line + ',*' + $SidString
                                }
                                else {
                                    $line = $line + ' *' + $SidString
                                }
                            }
                        }
                        if ($patched) {
                            Write-Output ("Patching policy {0} '{1}'" -f $InputObject.Id, $InputObject.DisplayName)
                            Write-Output ("  [-] " + $inf[$i])
                            Write-Output ("  [+] " + $line)
                        }
                    }
                }
                if ($line -eq '[Privilege Rights]') {
                    $section = $true
                }
                $file += $line
            }
    
            if ($patched) {
                do {
                    $prompt = ""
                    Write-Host -NoNewline "Commit? [y/n]: "
                    $prompt = Read-Host 
                } while ($prompt.ToLower().Trim().Length -ne 1)

                if ($prompt.ToLower().Trim() -eq 'y') {
                    Write-Output "Commited by user!`n"
                    $file | Out-File -Encoding unicode -FilePath $infPath
                }
                else {
                    Write-Output "Aborted by user!`n"
                }
            }
        }
    }

    end {
    }
}