<#

.SYNOPSIS
    This script checks the status of ndmpcopy of the given filer.
    using Netapp Powershell Toolkit v4.4
	
.DESCRIPTION
    Acquires user input to fill in the value of controller.

.INPUTS
    None

.OUTPUTS
    Displays the ndmpcopy status

.NOTES
    Version:         1.1
    Author:          Kevin Ayers kevin.ayers@cognizant.com
					 Gergely "Geri" Laszlo gergely.laszlo@cognizant.com
    Creation Date:   Aug 25, 2017
    Change Date:     September 19, 2017
    Purpose/Change:  Remove the local functions, use them from the library

	.EXAMPLE
    PS D:\Scripts> .\NDMPStatus.ps1

.EXAMPLE
    D:\Scripts>Powershell.exe -Executionpolicy RemoteSigned -File D:\Scripts\NDMPStatus.ps1
#>

<# Attempt to import the Netapp required module and exit the script if it fails
   This module is required to run the ndmpcopy. No need to continue if loading it fails #>

Import-Module DataONTAP -ErrorAction SilentlyContinue -ErrorVariable DonTapError

if ($DonTapError){
    Write-Host "Error loading module, aborting script"
    write-host $DonTapError -ForegroundColor Red
    exit 9999
}
#############################
#----- Initialisations -----#
#############################
# This is an existing filername.
$DefController = "usctnv608a"




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


Write-Host "The script will query the ndmp copy status of the filer you pass to it."
Write-Host "Do you need a list of controllers (y, any other key no)? " -NoNewline
$answer = $host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
$myChar=$answer.character
Write-Host "$myChar" -NoNewline
if ($answer.character -like "y")
{
    $myControllers = Get-ControllerList # The cmdlet is defined in the library
    Show-ControllerList -cList $myControllers
}

$controllerMSG = "Enter the index number (if you retrieved a list of controllers) or the controller name"
$maxTxtLen = Set-MaxLength ("$controllerMSG$DefController")

$SrcControllerName = Get-ControllerName $myControllers $DefController $controllerMSG $maxTxtLen # The cmdlet is defined in the library

Write-Host $SrcControllerName "selected" -ForegroundColor Yellow
$srcHostIP = Convert-HostnameToIP($SrcControllerName) # The cmdlet is defined in the library

$srccred = Set-MerckCredential
#Start-Sleep -Seconds 5

#Connect to NetApp Controller
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

$ndmpcopyStatus = Get-NaNdmpCopy  #| Format-List
if (-not $ndmpcopyStatus) {
	Write-Host "There is no ndmpcopy running on filer $SrcControllerName, exiting..." -ForegroundColor Yellow
	#Exit 3
}

$wWidth = [console]::windowWidth # to check the size of the window
#$wHeigth = [console]::windowHeight
$origCursor = $host.ui.rawui.CursorSize
$host.ui.rawui.CursorSize = 0 # We don't need the cursor for the funky wait signal
$position = $host.ui.rawui.cursorposition
$printY = $position.y
$printx = 0
$Characters = "/","-","\","|","/","-","\","•","*"
$ndmpcopyStatus = $true 
while ($ndmpcopyStatus)
{
	$waitTime = 75
    #Get Status of NDMPCopy job
	$position.y = $printY
	$host.ui.rawui.cursorposition=$position
    Write-Host "`nGetting NDMPCopy Status... Please wait" -ForegroundColor Green
    write-host "`tStatus command completed... Updating when the ""snake"" reaches the right side, in about $([math]::floor($waitTime*$wWidth*9/1000)) seconds..." -ForegroundColor Cyan
    Write-Host "`t(Hit CTRL-C to break out of this script...)" -ForegroundColor Cyan
	Get-NaNdmpCopy  #| Format-List
	$ndmpcopyStatus = Get-NaNdmpCopy
	$position.y =$printY + 4
	$position.x = $printx
	$host.ui.rawui.cursorposition=$position
	$blank = " " * $wWidth
	Write-Host $blank
	
    for ($i=0;$i -lt $wWidth+6;$i++)
	{
		<#$position.y =$printY + 6
		$position.x = 0
		$host.ui.rawui.cursorposition=$position
		Write-Host "I: $i"#>
		$snake=6
		$position.y = $printY + 4
		if ($i -lt $wWidth){
			foreach ($myChar in $Characters) {
				$position.x = $i
				$host.ui.rawui.cursorposition=$position
				Write-Host "$myChar  " -NoNewline -ForegroundColor Cyan
				if ($i -gt $snake){
					$position.x = $position.x - $snake - 1
					$host.ui.rawui.cursorposition=$position
					Write-Host " " -NoNewline
				}
				Start-Sleep -MilliSeconds $waitTime
			}
		} else {
			$position.x = $i - $snake -1
			$host.ui.rawui.cursorposition=$position
			Write-Host " " -NoNewline
			Start-Sleep -MilliSeconds ($waitTime*5)
		}
		$already = $true
		Start-Sleep -MilliSeconds ($waitTime)
	}
	

}

$host.ui.rawui.CursorSize = $origCursor
Write-Host ""


#---------------- End of NDMPstatus_Kevin.ps1 ------------------
<# Change Log
09/19/2017 Geri
	1. Added the header
	2. Formatted the script to use the library's functions
	3. Re-wrote the wait cycle. I am not sure if it is correct, as there is no copy running currently, 
		more testing is necessary. The wait cycle is writing to the same place over and over again, so the 
		window is not going to scroll.
08/31/2017 Geri
	1.
		#In the function "Get-SourceController" there was a check, if the typed in string is "number" or "string":
		$check = $SName.GetType() # The type is string, even if you type in 104<enter>
		#The TryParse method tries to convert the string to int. If it is successfull, $check will be "True" otherwise "False"
		#This why I changed the setting of $change, and also the "if" after that. Now it checks if the TryParse was successfull or not?
	2.
		Added "-Message "Please input the Password for the filer $SrcControllerName" -UserName root" to the "Get-Credential" command
	3. 
		Commented out the 5 second wait, I am impatient :-)
	

#>