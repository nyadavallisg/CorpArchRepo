function Get-ADDirectReports {
    [CmdletBinding()]
    PARAM (
        [Parameter(Mandatory)]
        [String[]]$Identity
    )
        foreach ($Account in $Identity) {
            
            
                    # Get the DirectReports
                    Write-Verbose -Message "[PROCESS] Account: $Account (Recursive)"
                    Get-Aduser -identity $Account -Properties directreports |
                        ForEach-Object -Process {
                            $_.directreports | ForEach-Object -Process {
                                # Output the current object with the properties Name, SamAccountName, Mail and Manager
                                Get-ADUser -Identity $PSItem -Properties manager,directreports | Select-Object -Property samaccountname,enabled,manager,directreports, @{ Name = "ManagerAccount"; Expression = { (Get-Aduser -identity $psitem.manager).samaccountname } }
                                # Gather DirectReports under the current object and so on...
                                Get-ADDirectReports -Identity $PSItem
                            }
                        }
                }
}
# if output is needed, Remove "mesure-object #"
Get-ADDirectReports -Identity "UserSAMAccountName"  | Where-Object -filter {($_.enabled -eq $true) -and ($_.SamAccountName -notlike "svc.*")}  | Measure-Object # export-csv .\directreport.csv -notypeinformation -append