# Start tracnscript
## Objective of the script is to Verify if all user who left the company have there AD account disabled.

Start-Transcript -Path D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\Active_AD_accounts_Disabled_Users_$(((get-date).ToUniversalTime()).ToString("yyyyMMddTHHmmssZ")).txt -Append

#get- secret from vault



#$creds =  Get-Credential -UserName ISU_Headcount_SOX -Message "enterpassword"
#$a = import-csv .\WorkDirectory\WD_outputfile.csv 
#$url = "https://services1.myworkday.com/ccx/service/customreport2/twilio/ISU_Report_Owner/Twilio_Headcount_SOX_Report?Effective_as_of_Date=2022-04-11-07%3A00&format=csv"

$username = "ISU_Headcount_SOX"
$passwd = Get-Secret -Name wdc
# method 1 $req.UseDefaultCredentials = $true
$Credentials = New-Object System.Management.Automation.PSCredential($username, $passwd); 
$url = "https://services1.myworkday.com/ccx/service/customreport2/twilio/ISU_Report_Owner/Twilio_Headcount_SOX_Report?Effective_as_of_Date=" + $(get-date -Format yyyy-MM-dd) + "-07%3A00&format=csv"

try
{

    $op = Invoke-WebRequest -Uri $url -Credential $Credentials
    #save output to workdirectory
    ($op).content | out-file D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\WD_outputfile.csv
}
catch [System.Net.WebException]
{
    $res = $_.Exception.Response
}

#$int = [int]$res.StatusCode
#$status = $res.StatusCode
#return "$int $status"

$files = import-csv D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\WD_outputfile.csv 


$disabledusers = $files | Where-Object { $_.Currently_Active -EQ 0} 
 
foreach($f in $disabledusers){

$empid = $f.Employee_ID
#write-host  $f.employee_ID -foregroundcolor red 
#write-host $empid -foregroundcolor green
Get-ADUser -filter "employeeid -eq `"$empid`""  -Properties employeeid,employeeType | Where-Object {$_.enabled -eq $true}| select-object DistinguishedName,EmployeeID,Enabled,GivenName,Name,SID,Surname,UserPrincipalName,employeeType,samaccountname,@{ Name = 'Employee_ID';  Expression = {$_.employeeid}} | export-csv D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\active_users_.csv -NoTypeInformation -Append



}

$abc =  import-csv D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\active_users_.csv


$activeusers_wd = $files |  Where-Object { $_.Currently_Active -EQ 1} 


$compareresult = Compare-Object -ReferenceObject $activeusers_wd -DifferenceObject $abc -Property "Employee_ID"

#$compareresult | ogv

$Array = @()       
Foreach($R in $compareResult)
{
    If( $R.sideindicator -eq "=>" )
    {
        $Object = [pscustomobject][ordered] @{
 
            employee_ID = $R.employee_ID
            "Compare indicator" = $R.sideindicator
 
        }
        $Array += $Object
    }
}
 

 
#Display results in console
$final_users = $Array | select-object * -Unique 


foreach($fu in $final_users){

    $enumber =  $fu.employee_id
    Get-ADUser -filter "employeenumber -eq `"$enumber`""  -Properties employeeid,employeenumber | Where-Object {$_.enabled -eq $true} | Export-Csv D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\ad_export_issue_users.csv -NoTypeInformation -Append
}

#Get Date
$ReportDate = Get-Date -format "MM-dd-yyyy"
#send mail using the Send-MailMessage cmdlet
$emailpassword = Get-Secret emailpassword
$Creds = $(New-Object System.Management.Automation.PSCredential "svc.sysopssmtp@twilio.com", $emailpassword)
$From = "sysops-notifications@twilio.com"
$SMTPPort = "587"
$SMTPServer = "smtp.gmail.com"
$Subject = "Daily Active user check based on WD data retrived on : "+ $ReportDate
$To = "nyadavalli@twilio.com" ,"ccheung@twilio.com", "hcheng@twilio.com", "jbiddick@twilio.com","team-its@twilio.com","team_eso@twilio.com"


 
#Configuration Variables for E-mail

#HTML Template
$EmailBody = @"
<table style="width: 68%" style="border-collapse: collapse; border: 1px solid #008080;">
 <tr>
    <td colspan="2" bgcolor="#008080" style="color: #FFFFFF; font-size: large; height: 35px;">
        Active users verification - Daily Report on VarReportDate 
    </td>
 </tr>
 <tr style="border-bottom-style: solid; border-bottom-width: 1px; padding-bottom: 1px">
    <td style="width: 201px; height: 35px"> Number of User active who should be disabled</td>
    <td style="text-align: center; height: 35px; width: 233px;">
    <b>VarApproved</b></td>
 </tr>
  
</table>
"@
 
#Get Values for Approved & Rejected variables
$ApprovedCount= $((Import-Csv D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\ad_export_issue_users.csv | Measure-Object).count )

 
#Replace the Variables VarApproved, VarRejected and VarReportDate
$EmailBody= $EmailBody.Replace("VarApproved",$ApprovedCount)
$EmailBody= $EmailBody.Replace("VarReportDate",$ReportDate)




Send-MailMessage -From $From -to $To -Subject $Subject -Body $EmailBody -SmtpServer $SMTPServer -port $SMTPPort -UseSsl -Credential $Creds -Attachments "D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\ad_export_issue_users.csv", "D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory\WD_outputfile.csv" -BodyAsHtml -Priority High -Verbose
Get-ChildItem D:\Schuduled_Tasks\Active_AD_accounts_Disabled_Users\WorkDirectory -File | Remove-Item -Force
Stop-Transcript 