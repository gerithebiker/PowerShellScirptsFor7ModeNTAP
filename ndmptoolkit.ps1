<#

.SYNOPSIS
    Script to reduce the amount of manual input required to run the manual process of restoring a VM from snapshot with ndmpcopy
    using Netapp Powershell Toolkit v4.4

.DESCRIPTION
    Acquires user input to fill in the values of source controller, virtual machine to recover, netapp volume, and snapshot name.
    Assembles the correct cmdlet to execute and with user approval, executes the cmdlet to run ndmpcopy.

.INPUTS
    None

.OUTPUTS
    Restored Virtual Machine image files

.NOTES
    Version:         2.5
    Author:          Kevin Ayers kevin.ayers@cognizant.com
                     Gergely "Geri" Laszlo gergely.laszlo@cognizant.com
                     Kelly Alexander alex@netapp.com
                     Julie Andreacola juandrea@microsoft.com
    Creation Date:   July 5, 2017
    Change Date:     September 19, 2017
    Purpose/Change:  The "try-catch" pair did not work for the import-module cmdlet, changed it to set an error variable.
                     SEE CHANGELOG AT BOTTOM OF SCRIPT FOR MORE INFORMATION
.EXAMPLE
    PS D:\Scripts> .\ndmptoolkit.ps1

.EXAMPLE
    D:\Scripts>Powershell.exe -Executionpolicy RemoteSigned -File D:\Scripts\ndmptoolkit.ps1
#>

#############################
#----- Initialisations -----#
#############################

# This is an existing filer with existing server/volume/snapshot, but we can safely use it for testing, as the server is a test server.
[string]$defaultFilerHostname = "usctnv608a"
$VMHostName = "test" 
$VolumeName = "vctv608a_c246_vm_01"
$SnapShotName = "SP_2_3804940_1498516809"

<# Attempt to import the Netapp required module and exit the script if it fails
   This module is required to run the ndmpcopy. No need to continue if loading fails #>
#try {
    Import-Module DataONTAP -ErrorAction SilentlyContinue -ErrorVariable DonTapError
#}

if ($DonTapError) {

    Write-Host "Error loading module, aborting script"
    write-host $DonTapError -ForegroundColor Red
    exit 9999
}

<#catch { finally {Write-Host "$DonTapError finally......."}

Write-Host "$a alma"
#>

######################################
#------ Function Defintions ---------#
######################################
# Function to load the ndmp toolkit library that contains some functions used in this script
Function Import-NDMP_Toolkit_Library ()
{
    # The myModule variable contains the path to the NDMP_Toolkit_Library.ps1 script
    # The .\ indicates the current working directory. This is useful for developing/testing
    $myModule = ".\NDMP_Toolkit_Library.psm1"  
	# This is where the production library is. Don't forget to uncomment once you turn the script into prod!!!
	#$myModule = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\NDMP_Toolkit_Library.psm1"
    
    # Test to ensure the NDMP_Toolkit_Library.ps1 script exists, if not, script exits. If it does, load the script into the current running environment.
    if (!(Test-Path $myModule)) {
        Write-Host $myModule " not found. Aborting script."
        exit 9999
    } else {
        try {# Attempt to import the script defined by myModule
	        Import-Module $myModule # -verbose # Verbose needed for tshooting
			# Confirm-ToolKit # Uncomment this line if you want a confirmation the toolkit was loaded. 
			# "Tried to load module...."
			
        }
        catch { # Catch any errors thrown by an unsuccessful dot source of myModule
	        Write-Host "`nFile not found" -ForegroundColor Red -BackgroundColor Black -NoNewline 
	        Write-Host " $myModule" -ForegroundColor Yellow -BackgroundColor Black -NoNewline
	        Write-Host "!!!                                                                             " -ForegroundColor Red -BackgroundColor Black
	        Write-Host "If you copied me locally, please ensure, that $myModule is copied also to the same folder, where I live." -ForegroundColor Cyan -BackgroundColor Black
            Write-Host $error[0].Exception -ForegroundColor Red
	        Write-Host "Exiting... " -ForegroundColor Red -BackgroundColor Black
	        Exit 1
        }
    }
} # End of Function Import-NDMP_Toolkit_Library

# Function to map the Z drive for use of the network share
Function Set-ZDrive ()
{
	#Confirm-ToolKit
    if (!(Test-Path Z:)) {
		$myZ = New-PSDrive -Name "Z" -PSProvider "FileSystem" -Root "\\vsbrnlab001\incidentresponse" -Scope Global -Persist -ErrorAction SilentlyContinue -ErrorVariable MountError #
		if ($MountError) {
			Write-Host """Z"" drive does not exist. I tried, but there was an issue mounting it!" -ForegroundColor Red
			"Exiting..."
			Exit 12
		} else {
			Write-Host """Z"" drive has been mounted successfully."
		}
	} else {   
        Write-Host "Z: drive already in use"
    }
} # end of function Set-ZDrive

<# Function to display the results of the user input and the ndmpcopy command that will be used
Function Show-Results ($SController,$fIP,$volName,$snapName,$vmHost,$True)
{
	$srcpath = "/vol/$volName/.snapshot/$snapName/$vmHost"
	$dstpath = "/vol/$volName/$vmHost"
	Write-Host "`nHost Name`t`tFiler IP address: " -ForegroundColor Cyan
	Write-Host "$SController`t`t$fIP`n" -ForegroundColor Yellow
	Write-host "Command will be:" -ForegroundColor Cyan
	Write-Host "ndmpcopy $srcpath $dstpath`n" -ForegroundColor Yellow
	return $srcpath,$dstpath
} # end of function Show-Results
#>

##########################################
# ----- End of Function Definitions -----#
##########################################

################################################################################
# ------ Begin ndmptookit.ps1 body. Script execution begins here --------------#
################################################################################

Write-Host ""
Set-ZDrive
Import-NDMP_Toolkit_Library
# Confirm-ToolKit # Uncomment this line, if you want to test if the toolkit is loaded


Write-Host "Do you need a list of controllers (y, any other key no)? " -NoNewline
$answer = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
$myChar=$answer.character
Write-Host "$myChar" -NoNewline # Display what was the key pressed for the record
if ($answer.character -like "y")
{
    $myControllers = Get-ControllerList
    Show-ControllerList -cList $myControllers
}

# Set the messages for the coming functions. It it necessary to be able to measure the length of the messages, in case they need to be changed.
$controllerMSG = "Enter the index number (if you retrieved a list of controllers) or the controller name" # (if you retrieved a list of controllers) or the controller name 
$vmHostMSG = "Enter the Virtual Machine Name to recover"
$volNameMSG = "Enter the NetApp VolName that has the VM"
$snapshotMSG = "Enter the SnapShot Name of the volume"

$maxTxtLen = Set-MaxLength ("$controllerMSG$defaultFilerHostname", "$vmHostMSG$VMHostName", "$volNameMSG$VolumeName", "$snapshotMSG$SnapShotName")

# Get the information from the user what needs to be done
# These functions are part of the library
$SrcControllerName = Get-ControllerName $myControllers $defaultFilerHostname $controllerMSG $maxTxtLen
$FilerHostIP = 	Convert-HostnameToIP($SrcControllerName)
$VMHostName = 	Get-Parameter $vmHostMSG $VMHostName $maxTxtLen
$VolumeName = 	Get-Parameter $volNameMSG $VolumeName $maxTxtLen
$SnapShotName = Get-Parameter $snapshotMSG $SnapShotName $maxTxtLen

# The Show-Results function is not just shows the results, but sets the src and dst paths
$srcPath,$dstPath = Show-Results $SrcControllerName $FilerHostIP $VolumeName $SnapShotName $VMHostName "Show"

#Write-Host "Src: $srcPath, Dst: $dstPath"
#Confirm-Proceed

$Password = Set-MerckCredential

# Connect to the filer. The last parameter is an error message, displayed only if there was something wrong
$myFiler,$NoDice = Connect-MerckFiler $FilerHostIP $Password "The standard credential is not good, please provide the correct UID/pwd for the filer $SrcControllerName!"

# If the connection is initiated to a filer that does not get the standard UID/password, then we try to get it from the user
if ($NoDice) {
	Start-Sleep 3
	$Password = Get-Credential -Message "Please input the UID/password for the filer $SrcControllerName" 
	# connect to the filer
	$myFiler,$NoDice = Connect-MerckFiler $FilerHostIP $Password "The provided UID/password is not good!`nPlease find the correct credential for the filer $SrcControllerName!"
	# If the interactively provided UID/password is still not good, we exit
	if ($NoDice) {
		Write-Host "The provided UID/password is incorrect, exiting..." -ForegroundColor Red -BackgroundColor Black
		Exit 14
	}
}

# Confirming if the snapshot was taken before the deadline
# Confirm-ToolKit

# We need to check if the snapshot was taken before the deadline. If not, script exits
try { Confirm-NaSnapshotDate $VolumeName "none" $SnapShotName } 
catch { 
	Write-Host "There was a problem with the " -NoNewline
	Write-Host "$VolumeName" -NoNewline -ForegroundColor Red
	Write-Host "/" -NoNewline
	Write-Host "$SnapShotName" -ForegroundColor Red -NoNewline
	Write-Host " names, exiting..."
	Exit 15
}

#Enable NDMP on controllers
Enable-NaNdmp -Controller $myFiler

#Enable NDMP connect logging on controllers
#Set-NaOption ndmpd.connectlog.enabled on-Controllers $myFiler 
	
#Time and timezone information of the local machine to have proof. 
Get-LocalTimeAndTZOffset
	
#Display the timezone info of the filer
Get-NaFilerTimeAndTZ "" $myFiler $SrcControllerName
		
#Display snap list of the volume
Get-NaSnaplistOfVolume $VolumeName $myFiler $SnapShotName 
	
#Display the content of the VM directory from the snapshot. Error handling is in the function
Get-VMDirectory $srcPath $myFiler 


# Dont comment out the following line! Without this the ndmp copy will be initiated without a confirmation!!
Confirm-Proceed

#Start NDMCOPY as background process
Write-Host "Doing NDMPCopy...."
Start-NaNdmpCopy -DstController $FilerHostIP -DstCredential $Password -DstAuthType Md5 -DstPath $dstPath -SrcController $FilerHostIP -SrcCredential $Password -SrcAuthType Md5 -SrcPath "$srcPath"

#Get NDMPcopy status
Get-NaNdmpCopy | Format-List
Write-Host "`nDo not worry about the" -NoNewline
Write-Host " yellow " -ForegroundColor yellow -backgroundcolor Black -NoNewline
Write-Host "warning message. The ndmpcopy is running non-interactively, so you do not need to keep this powershell window open."
Write-Host "If you keep this window open, you can query the status of the copy issuing a Get-NaNdmpCopy command."
Write-Host "Command complete"
Write-Host "Do you want to do another restore (y/Y to perform another, any other key to exit) ? " -NoNewline
	

############################################################
#---------------- End of ndmptoolkit.ps1 ------------------#
############################################################

<# Change Log
09/19/2017 - Geri 
			- The "try-catch" pair did not work for the "import-module dataontap" command, changed it to set an error variable.
			With that it is working correctly.
			- Displaying the key pressed where the user asked if they want a filer list.
09/12/2017 - Geri
			Purpose of change: Finalized the format of the scrip. Better looking output.
			Removed the unused logic from the original script. It is more clear now.
			- Renamed Get-SourceController to Get-ControllerName. I want to use it for the Dst controller also...
			- Implemented the function Set-MerckCredential -> library
			- Changed the Show-Results function. Now it sets the src and dst paths. The two paths have " now, so if 
				the VM host name includes spaces, it will still work. (I ran into an issue like this)
			- Implemented the Set-MerckCredential function. Users don't need to provide UID/password from now on.
			- Implemented the Set-MaxLength function to be able to allign the input lines. If any of the variables overwritten,
				the input lines will be still alligned.
09/11/2017 - Geri
			Purpose of change: Moved the reuseable functions to the library.
			- Moved more functions to the library
			- Implemented the Get-Parameter function. As it just gets a string, it makes more sense to use the same function 3x
			- Automated the logon
09/06/2017 - Geri
			- Removed the already commented out Show-ControllerList and Get-SourceController functions that were already moved to the library
			- In the library I changed how to call Confirm-NaSnapshotDate function. Here I added "none" as the second parameter.
09/05/2017 - Geri
			- Moved Show-ControllerList function to the library. (Also changed the function to print out the list in multiple columns)
09/01/2017 - Kevin - Removed the -test examples from the EXAMPLE section of the header since the test parameter has been removed
                     Removed the test parameter from the PARAMETER section of the header since the test parameter has been removed
08/31/2017 Moved the content of Function Import-NDMP_Toolkit_Library to the main body
			The function is worked perfectly, except the result of it was local. Once the script is out of the function, 
			you cannot use the functions loaded... I need those functions globally.
			It is working now. Changed the . $myModule importing to "Import-Module $myModule" and is good now.
			
			I moved the Get-SourceController function to the NDMP_Toolkit_Library. It is running from there now.
			
			Commented out the Run-Test function and call. It is not needed anymore. I know Kevin just converted it to a function
				but no one is using it anymore. That was only for the initial script written by the NetApp/Microsoft guys.
			
			Removed the "giant do loop". First of all we don't run too many ndmp copies in the same time, no need for a loop.
				Once the copy started, we want to be able to monitor the progress. It is the easiest to just leave the session,
				and check the progress time-to-time. For that, we run only one ndmpcopy in one window. 
					
			Moved the function Confirm-Proceed to the ndmptoolkit library.
			
08/31/2017 - Kevin - Altered script to functionalized format for easier reading and commenting.
						Body of script execution occurs after function definitions.
                     added function Import-NDMP_Toolkit_Library
                        -load the ndmp toolkit library that contains some functions used in this script
                     added function Set-ZDrive
                        -map the Z drive for use of the network share
                     added function Get-ControllerList
                        -load the controller list from the Z drive
                     added function Show-ControllerList
                        -display the loaded controller list to the console
                     added function Get-SourceController
                        -get the source controller from the user using console input
                     added function Convert-HostnameToIP
                        -convert a hostname to an ip address
                     added function Get-VirtualMachineName
                        -retrieve the virtual machine name from the user using console input
                     added function Get-NetAppVolume
                        -retrieve the NetApp Volume name from the user using console input
                     added function Get-SnapshotName
                        -retrieve the Snapshot name from the user using console input                     
                     added function Confirm-ChangeCounter
                        -check the value of the change counter and exit script if there was not enough input from the user
                     added function Show-Results
                        -display the results of the user input and the ndmpcopy command that will be used
                     #added function Confirm-Proceed
                     #   -check if it is ok to proceed and exit the script if not ok
                     added function Run-Test
                        -run the test instead of actually performing the ndmpcopy
                     Added comments to describe the functions of each section.
08/11/2017 - Geri  - Changed the script to use filer names instead of IP addresses
                     Displaying the time zone info of the filer
                     Displaying the snapshot list of the given volume on the filer
                     Displaying the files of the VM on the SNAPSHOT
08/08/2017 - Geri  - Changed the Invoke-NaNdmpCopy to Start-NaNdmpCopy, so it disconnects the session.
                     Commented out the "clear-host" command.
07/26/2017 - Marc  - Added local time information to be displayed

End of Change Log #>