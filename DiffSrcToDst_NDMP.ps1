<#

.SYNOPSIS
    Script to reduce the amount of manual input required to run the manual process of restoring a VM from snapshot with ndmpcopy
    using Netapp Powershell Toolkit v4.4
	This script is designed to do the copy from controllerA to controllerB and/or volumeA to volumeB

.DESCRIPTION
    Acquires user input to fill in the values of source controller, virtual machine to recover, netapp volume, and snapshot name,
	destination controller, destination volume.
    Assembles the correct path to pass to the cmdlet, and with user approval, executes the cmdlet to run ndmpcopy.
	It is using encrypted credentials to connect to the filer(s).

.INPUTS
    None

.OUTPUTS
    Restored Virtual Machine image files

.NOTES
    Version:         1.1
    Author:          Gergely "Geri" Laszlo gergely.laszlo@cognizant.com
                     Marc Galloway mgalloway@evtcorp.com
    Creation Date:   Aug 25, 2017
    Change Date:     September 19, 2017
    Purpose/Change:  The "try-catch" pair did not work for the import-module cmdlet, changed it to set an error variable.
.EXAMPLE
    PS D:\Scripts> .\DiffSrcToDst_NDMP_Copy.ps1

.EXAMPLE
    D:\Scripts>Powershell.exe -Executionpolicy RemoteSigned -File D:\Scripts\DiffSrcToDst_NDMP_Copy.ps1
#>

#############################
#----- Initialisations -----#
#############################
# This is an existing filer with existing server/volume/snapshot, but we can safely use it for testing, as the server is a test server.
$DefController = "usctnv608a"
$DefServer = "test"
$DefVolume = "vctv608a_c246_vm_01"
$DefSnapshot = "SP_2_3804940_1498516809"


<# Attempt to import the Netapp required module and exit the script if it fails
   This module is required to run the ndmpcopy. No need to continue if loading fails #>

    Import-Module DataONTAP -ErrorAction SilentlyContinue -ErrorVariable DonTapError

if ($DonTapError){
    Write-Host "Error loading module, aborting script"
    write-host $DonTapError -ForegroundColor Red
    exit 9999
}

######################################
#------ Function Defintions ---------#
######################################
# Function to load the ndmp toolkit library that contains some functions used in this script
Function Import-NDMP_Toolkit_Library ()
{
    # The myModule variable contains the path to the NDMP_Toolkit_Library.ps1 script
    # The .\ indicates the current working directory. This is useful for developing/testing
    #$myModule = ".\NDMP_Toolkit_Library.psm1"  
	# This is where the production library is. Don't forget to uncomment once you turn the script into prod!!!
	$myModule = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\NDMP_Toolkit_Library.psm1"
    
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








#############################
#-----   Main Script   -----#
#############################
Set-ZDrive
Import-NDMP_Toolkit_Library
#Confirm-ToolKit # Uncomment this line if you want to check the loaded module. This function only writes a line that it is loaded.

Write-Host "Do you need a list of controllers (y, any other key no)? " -NoNewline
$answer = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
$myChar=$answer.character
Write-Host "$myChar" -NoNewline
if ($answer.character -like "y")
{
    $myControllers = Get-ControllerList # The cmdlet is defined in the library
    Show-ControllerList -cList $myControllers
}

# Set the messages for the coming functions. With this method we can measure the length of the messages to have nice output.
# If the messages need to be changed, the output will be adjusted automatically.
$controllerMSG = "Enter the index number (if you retrieved a list of controllers) or the source controller name" # (if you retrieved a list of controllers) or the controller name 
$vmHostMSG = "Enter the Virtual Machine Name to recover"
$volNameMSG = "Enter the NetApp VolName that has the VM"
$snapshotMSG = "Enter the SnapShot Name of the volume"

$maxTxtLen = Set-MaxLength ("$controllerMSG$DefController", "$vmHostMSG$DefServer", "$volNameMSG$DefVolume", "$snapshotMSG$DefSnapshot")

# Getting the source Controller information
$SrcControllerName = Get-ControllerName $myControllers $DefController $controllerMSG $maxTxtLen # The cmdlet is defined in the library
$srcHostIP = Convert-HostnameToIP($SrcControllerName) # The cmdlet is defined in the library
#Write-Host = ''

# In the next few Read-Host command I did put in some error checking
# VolumeName, FilerName, SnapShot name cannot be "" and cannot contain " ".
$VMHostName = Get-Parameter $vmHostMSG $DefServer $maxTxtLen

$SrcVolumeName = Get-Parameter $volNameMSG $DefVolume $maxTxtLen

$SnapShotName = Get-Parameter $snapshotMSG $DefSnapshot $maxTxtLen


$controllerMSG = "Enter the destination controller name. You can use the previous indexes, if there were any." # (if you retrieved a list of controllers) or the controller name 
$volNameMSG = "Enter the destination NetApp VolName"
$maxTxtLen = Set-MaxLength ("$controllerMSG$DefController", "$volNameMSG$DefVolume")

$DstControllerName = Get-ControllerName $myControllers $SrcControllerName $controllerMSG $maxTxtLen
$dstHostIP = Convert-HostnameToIP($DstControllerName)
#Write-Host = ''

$DstVolumeName = Get-Parameter $volNameMSG $SrcVolumeName $maxTxtLen
$sourcepath,$destinationpath = Show-ResultsDiff $SrcControllerName $srcHostIP $SrcVolumeName $SnapShotName $VMHostName $DstControllerName $dstHostIP $DstVolumeName "Show"

	
#Uncomment the following line if you want more controll
#Confirm-Proceed

#############################


$srccred = Set-MerckCredential
$dstcred = Set-MerckCredential
	
# Display time and timezone information of the local machine to have proof. 
Get-LocalTimeAndTZOffset
	
# connect to the filer. The last parameter is an error message
$mySrcFiler,$NoDice = Connect-MerckFiler $srcHostIP $srccred "The standard credential is not good, please provide the correct UID/pwd for the filer $SrcControllerName!"

# During the recovery, there were 3 different credentials. In case the standard does not work, the script asks for another cred.
if ($NoDice) {
	Start-Sleep 3
	$srccred = Get-Credential -Message "Please input the UID/password for the filer $SrcControllerName" 
	# connect to the filer
	$myFiler,$NoDice = Connect-MerckFiler $srcHostIP $srccred "The provided UID/password is not good!`nPlease find the correct credential for the filer $SrcControllerName!"
	# If the interactively provided UID/password is still not good, we exit
	if ($NoDice) {
		Write-Host "The provided UID/password is incorrect for $SrcControllerName, exiting..." -ForegroundColor Red -BackgroundColor Black
		Exit 14
	}
}


$myDstFiler,$NoDice = Connect-MerckFiler $dstHostIP $dstcred "The standard credential is not good, please provide the correct UID/pwd for the filer $DstControllerName!"

if ($NoDice) {
	Start-Sleep 3
	$dstcred = Get-Credential -Message "Please input the UID/password for the filer $DstControllerName" 
	# connect to the filer
	$myDstFiler,$NoDice = Connect-MerckFiler $dstHostIP $dstcred "The provided UID/password is not good!`nPlease find the correct credential for the filer $DstControllerName!"
	# If the interactively provided UID/password is still not good, we exit
	if ($NoDice) {
		Write-Host "The provided UID/password is incorrect for $DstControllerName, exiting..." -ForegroundColor Red -BackgroundColor Black
		Exit 14
	}
}
	
#Display the timezone info of the source filer
	if ($SrcControllerName -ne $DstControllerName) {
		$myMessage = " source"
	}

	Get-NaFilerTimeAndTZ $myMessage $mySrcFiler $SrcControllerName
	
	if ($SrcControllerName -ne $DstControllerName) {
		$myMessage = " destination"
		# This part runs only if the sourca and destination filer different
		Get-NaFilerTimeAndTZ $myMessage $myDstFiler $DstControllerName
	}


#Check if the snapshot is from before the deadline, $SrcControllerName
	#Confirm-ToolKit
try {	Confirm-NaSnapshotDate $SrcVolumeName $mySrcFiler $SnapShotName	}
catch { 
	Write-Host "There was a problem with the " -NoNewline
	Write-Host "$SrcVolumeName" -NoNewline -ForegroundColor Red
	Write-Host "/" -NoNewline
	Write-Host "$SnapShotName" -ForegroundColor Red -NoNewline
	Write-Host " names, exiting..."
	Exit 15
}

#Enable NDMP on controllers
Enable-NaNdmp -Controller $mySrcFiler
Enable-NaNdmp -Controller $myDstFiler

		
#Display snap list of the volume
	Get-NaSnaplistOfVolume $SrcVolumeName $mySrcFiler $SnapShotName

#Display the content of the VM directory from the snapshot
	Get-VMDirectory $sourcepath $mySrcFiler

# Check if everything is OK before starting ndmpcopy
# DO NOT comment out the following line, otherwise the ndmp copy will be initiated without a confirmation!!
Confirm-Proceed
			
Write-Host "Starting ndmpcopy..."

#Start NDMPCopy as background process
Start-NaNdmpCopy -SrcController $srcHostIP -SrcPath $sourcepath -DstController $dstHostIP -DstPath $destinationpath -SrcCredential $srccred -SrcAuthType md5 -DstCredential $dstcred -DstAuthType md5

#Get Status of NDMPCopy job
#Write-Host 'Getting NDMPCopy Status... Please wait' -ForegroundColor Green
#Get-NaNdmpCopy | Format-List
Write-Host "`nDo not worry about the" -NoNewline
Write-Host " yellow " -ForegroundColor yellow -backgroundcolor Black -NoNewline
Write-Host "warning message. The ndmpcopy is running non-interactively, so you do not need to keep this powershell window open."
Write-Host "If you keep this window open, you can query the status of the copy issuing a Get-NaNdmpCopy command."

######################################################
#                End of script                       #
######################################################

<# Change Log
09/19/2017 - Geri 
			- The "try-catch" pair did not work for the "import-module dataontap" command, changed it to set an error variable.
			With that it is working correctly.
			- Displaying the key pressed where the user asked if they want a filer list.
09/12/2017 - Geri
	- unfortunately I did not focus on the maintenance of the change log. The script went through 
	a few changes, I developed it together with the ndmptoolkit.ps1. Once I introduced 
	Functions, I created the NDMP_Toolkit_Library.psm1 library, and placed everything
	possible there. As the purpose of the two script is slightly different, but the 
	main steps are the same, it made sense to reuse the functions. 
	Later Kevin Ayers stepped in, and "functionalized" the whole ndmptoolkit.ps1 script.
	Once he done that, I moved all the functions to the library possible.
	The last change I did was on 09/13/2017. I removed everything unnecessary.
	
	About the design. This script does not take parameters. The original script was 
	the ndmptoolkit.ps1, and it was interactive, so the user can verify the steps. I 
	did not want to change it, and there was no need for bulk ndmp copies. If necessary,
	it is not to complicated to check the parameters, and pass them to the appropriate 
	variables and not to call the functions to read from the console. 
	
	If you have any questions, please contact me on the email address in the header.
#>