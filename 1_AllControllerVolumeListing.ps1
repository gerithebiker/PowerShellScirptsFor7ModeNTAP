<#
.SYNOPSIS
    Script collects all the root level objects from all controllers' all volume in the environment
    Tested on 
        PowerShell version 5.0 
        Netapp Powershell Toolkit v4.4

.DESCRIPTION
    Acquires user input to fill in the values of source controller, virtual machine to recover, netapp volume, and snapshot name.
    Assembles the correct cmdlet to execute and with user approval, executes the cmdlet to run ndmpcopy.

.PARAMETER test
    Postional parameter in postion 0. Optional parameter that runs a df on the filer instead of the ndmpcopy

.INPUTS
    None

.OUTPUTS
    Restored Virtual Machine image files

.NOTES
    Version:         2.0
    Author:          Kelly Alexander alex@netapp.com
                     Julie Andreacola juandrea@microsoft.com
    Creation Date:   July 5, 2017
    Change Date:     August 31, 2017
    Purpose/Change:  Convert to functionalized script for easier reading and commenting.
                     Body of script execution occurs after function definitions.
                     SEE CHANGELOG AT BOTTOM OF SCRIPT FOR MORE INFORMATION
.EXAMPLE
    From the PowerShell console window:
        PS D:\Scripts> .\ndmptoolkit.ps1
        PS D:\Scripts> .\ndmptoolkit.ps1 -test
    From the Windows command prompt:
        D:\Scripts>Powershell.exe -Executionpolicy RemoteSigned -File D:\Scripts\ndmptoolkit.ps1
        D:\Scripts>Powershell.exe -Executionpolicy RemoteSigned -File D:\Scripts\ndmptoolkit.ps1 -Args "-test"
#>


#----- Initialisations -----
<# Attempt to import the Netapp required module and exit the script if it fails
   This module is required to run the ndmpcopy. No need to continue if loading it fails #>
try
{
    Import-Module DataONTAP 
}
catch
{
    Write-Host "Error loading module, aborting script..."
    write-host $error[0].Exception -ForegroundColor Red
    Exit 10
}

# Log file
$VolListLog = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\log\VolObjErr.log"

# Location of filer lists
$ListContainer = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\FilerLists"

$etc = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\etc"


#------ Function Defintions ---------

# Function to set the credentials for the given filer. UID/PWD differs regarding the type of filer
Function Set-MerckCredentials ($keyFile, $credFile, $userName) { #($UserID, $Password) {
	#$keyFile = ".\naroot.key"
	#$credFile = ".\naroot.cred"
	#$userName = "root"

#retrieve key
#$key = Get-Content $keyFile
#create credential object to pass
$myCredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $userName, (Get-Content $credFile | ConvertTo-SecureString -Key (Get-Content $keyFile)) # $key)
	
	
	#Write-Host "$UserID"
	#Write-Host	"$Password"
#	$ssPassword = ConvertTo-SecureString -String $Password -AsPlainText -Force
#	$myCredential = New-Object System.Management.Automation.PSCredential $UserID,$ssPassword
	Return $myCredential
} # End of Function Set-MerckCredentials

# Function is to collect the top level objects from all volume of all the filers in the current type
Function Get-TopLevelObjects ($myLog) {
	$myDestinationDir="Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\AllControllersVolumeListingPowerShell"
	# Getting the source information
	foreach ($filer in $myFilers){
		Write-Host "Started working on the filer $filer..."
		Remove-Item $ENV:TEMP\$filer -ErrorAction silentlycontinue
		$HostData = [System.Net.Dns]::GetHostAddresses($filer)[0]
		$HostIP = $HostData.IPAddressToString
		# connect to the filer
		try {
			$myConnectedFiler = Connect-NaController -Name $HostIP -Credential $Credential -HTTP
		}
		catch {
			"There was an issue connecting to $filer filer" | Tee-Object $myLog -Append
			Continue
		}
		try {
			$myVols = Get-NaVol | ?{$_.state -eq "online"} | Select-String .* | Select-String vol0 -notmatch
		}
		catch {
			"There was an issue getting the directories from $filer filer" | Tee-Object $myLog -Append
			Continue
		}
		
		foreach ($vol in $myVols) {
			Write-Host "$vol"
			try {
				$myObjects=Read-NaDirectory -path /vol/$vol | Select-String .* | Select-String \.$ -notmatch
			}
			catch {
				"There was an issue reading directory /vol/$vol from $filer filer" | Tee-Object $myLog -Append
				Continue
			}
		
			foreach ($object in $myObjects){
				#Write-Host "$vol`:$object"
				Add-Content $ENV:TEMP\$filer "$vol`:$object" 
			}
		}
		try {
			Copy-Item $ENV:TEMP\$filer $myDestinationDir\$filer
		}
		catch {
			"There was an issue copying the file $filer to Z: drive" | Tee-Object $myLog -Append
		}
		Write-Host ""
	}
} # End of Function Get-TopLevelObjects


# ----- End of Function Definitions -----

# ----- Begin body. Script execution begins here --------------


$startTime=Get-Date 
"Script started at $startTime" | Tee-Object $VolListLog -Append 

$myFilers=Get-Content $ListContainer\filers
$Credential = Set-MerckCredentials "$etc\naroot.key" "$etc\naroot.cred" "root" #Get-Credential -Message "Password for the `"root`" filers" -UserName root
Get-TopLevelObjects $VolListLog

$myFilers=Get-Content $ListContainer\123Filers
$Credential = Set-MerckCredentials "$etc\123root.key" "$etc\123root.cred" "root" # Get-Credential -MessagePassword "Password for the 123 filers" -UserName root
Get-TopLevelObjects $VolListLog
	
$myFilers=Get-Content $ListContainer\AdministratorFilers
$Credential = Set-MerckCredentials "$etc\admin.key" "$etc\admin.cred" "Administrator"  # Get-Credential -Message "Password for the Admin filers" -UserName Administrator
Get-TopLevelObjects $VolListLog

$endTime=Get-Date 
"Script finished running at $endTime" | Tee-Object $VolListLog -Append 

<# Change Log
	0. Initial version by Geri. 08/14/2017
		Originally it was written in cygwin/bash. I realized that in some strange cases the controller does not give back the correct list of "ls" command to the command line. There were missing folders, so I decicded to rewrite the collection using the NetApp PowerShell Toolkit. 
	1. Kevinization of the script. Geri 08/31/2017
		Talked to Kevin Ayers today, he showed how he writes scripts. I wanted to standardize our scripts, so I reformatted the script.
	2. Moved the script from local machine to "Z drive". Geri 08/31/2017
		Originally I placed the script on my notebook. As it did not show any issues, I moved it to the network drive. That meant it is running, or can run directly from the network, so I had to ensure the temp files are written locally, otherwise the runtime would be much longer. Also, it reads the filer lists from the network drive.
#>
	
