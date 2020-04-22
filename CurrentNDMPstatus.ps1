#Import NetApp DataONTAP modules
Import-Module DataONTAP

#Define variables
#$controller =  Read-Host -Prompt 'Enter controller Name or IP'

#Connect to NetApp Controller
#Connect-NaController $controller -Credential (Get-Credential)

#Get Status of NDMPCopy job
Write-Host 'Getting NDMPCopy Status... Please wait' -ForegroundColor Green
Get-NaNdmpCopy | Format-List
