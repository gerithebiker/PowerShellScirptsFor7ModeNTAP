if ($myInvocation.InvocationName -like "NDMP_Toolkit_Library.ps1") {
	Write-Host "`nI was not designed to run as an interactive script. Exiting...`n"
	Exit 1
	}
	
$myVersion = "1.2"

# Test Function
Function Confirm-ToolKit ()
{
	"`nVersion $myVersion NDMP_Toolkit_Library is loaded!!!`n"
}

Function Get-LocalTimeAndTZOffset
	{
		#Time and timezone information of the local machine to have proof. 
		$t = Get-Date
		# $tz=[System.TimeZoneInfo]::local | select-object -expandproperty DisplayName # This line shows the name of the timezone. Could be misleading
		$tzm = get-item "HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation"
		$offset = $tzm.GetValue("ActiveTimeBias")/60*-1 # The key ActiveTimeBias keeps how much you need to add to the current local time to get UTC in minutes in Windows
														# I want to display the "offset", how many hours needs to be added to UTC to get the local time, that is why the 
														# division by 60 and than multiplication by -1.
		
		
		
		write-host "`nCurrent time on the local machine: " -ForegroundColor Cyan -NoNewline
		Write-Host $t -ForegroundColor Yellow -NoNewline
		Write-Host ", offset to UTC: " -ForegroundColor Cyan -NoNewline
		Write-Host $offset -ForegroundColor Yellow -NoNewline
		Write-Host " hour(s)." -ForegroundColor Cyan
	}

Function Get-NaSnaplistOfVolume ($VolumeName, $Controller, $snapshot)
	{
		# Display snap list of the volume
		Write-Host "`nDetails of the selected SnapShot of the volume " -ForegroundColor Cyan -NoNewline
		Write-Host "$VolumeName" -ForegroundColor Yellow -NoNewline 
		Write-Host ":" -ForegroundColor Cyan # -NoNewline
		Get-NaSnapshot  -TargetName $VolumeName -Controller $Controller | Where-Object name -eq $snapshot | Select-Object name,created,dependency | Format-Table
	}


Function Get-VMDirectory ($SourcePath, $Controller)
	{
		Write-Host "`nFiles in $ErrorVariable" -ForegroundColor Cyan -NoNewline
		Write-Host "$sourcepath" -ForegroundColor Yellow -NoNewline
		Write-Host " folder:" -ForegroundColor Cyan
		Read-NaDirectory -path "$SourcePath" -Controller $Controller -ErrorAction SilentlyContinue -ErrorVariable MFReadError| Format-Table  
		if ($MFReadError) {
			Write-Host "$MFReadError" -ForegroundColor Red
			Write-Host "Exiting..." -ForegroundColor Red
			Exit 17
		}
	}
	
	
Function Get-NaFilerTimeAndTZ ($FilerType, $Controller, $myFilerName)
	{
		Write-Host "`nTime zone information and current time from the$FilerType filer " -ForegroundColor Cyan -NoNewline
		Write-Host "$myFilerName" -ForegroundColor Yellow -NoNewline 
		Write-Host ":" -ForegroundColor Cyan #-NoNewline
		Write-Host "Offset to UTC: "-NoNewline
		$((Get-NaTimezone).TimezoneUTC)
		#-Controller $Controller | select-object timezone,timezoneutc | Export-CSV output.cvs #,timezoneutc 
		#(Get-Content .\output.cvs) -replace '"','' | Foreach-Object {$_ -replace ',',"`t"} | Select-String -Pattern Timezone -NotMatch
		#Get-NaTime | Select-Object LocalTimeDT 
		$(Get-NaTime).LocalTimeDT 
		# Remove-Item output.cvs
	}


Function Confirm-NaSnapshotDate ($VolName, $Controller, $SnapShotName)
	{
		# This is the deadline in UTC!!! It is 4 hours ahead of Eastern DAYLIGHT Saving Time !
		$DeadLineStringUTC = "27/06/2017 03:59:59".toString()
		$DeadLineUTC = ([datetime]::ParseExact($DeadLineStringUTC,"dd/MM/yyyy HH:mm:ss",$null))
		
		# Get the snapshot creation time. It is stored in the filer's local time
		# Write-Host "Hiba: $VolName, $Controller, $SnapShotName"
		if ($Controller -eq "none") { # On some reason if you are connected to only one controller, and you call the Get-NaSnapshot with a controller, it throws an error message
									  # This why I implemented this "if".
			$SnapShotCreationTime = Get-NaSnapshot $VolName -ErrorAction SilentlyContinue | where-Object {$_.name -eq "$SnapShotName" } | select created
		} else {
			$SnapShotCreationTime=Get-NaSnapshot $VolName -Controller $Controller -ErrorAction SilentlyContinue | where-Object {$_.name -eq "$SnapShotName" } | select created
		}
		$SnapShotCreationTime=$SnapShotCreationTime.created
		
		# Get the timezone offset. It is a string, the format is +0000, where + shows if it is ahead of ahead of UTC, - is behind
		# The second and third character shows the hours, the 4th and 5th the minutes, which are usually 0.
		# I pars the string to hour and minute numbers, then add them together. If the mintues > 0, then it will be like 4.5 hours
		# If the number is negative, then we need to multiple by -1
		$offs=(Get-NaTimezone).TimezoneUTC
		# $offs # For troubleshooting
		$offsHours=[int]($offs.remove(3,2)).remove(0,1)
		$offsMins=[int]$offs.remove(0,3)
		$elojel=$offs.remove(1,4)
		
		$offsHours=$offsHours+$offsMins/60
		
		if ( $elojel -eq "-" ) { $offsHours=$offsHours*-1}
		
		# For tshooting
		# $DeadLineUTC
		# $SnapShotCreationTime
		
		# Snapshot creation time in UTC
		$SnapShotCreationTimeUTC=$SnapShotCreationTime.addhours(-($offsHours))
		# $SnapShotCreationTime

		if ($SnapShotCreationTimeUTC -lt $DeadLineUTC) {
			Write-Host "`nThe snapshot " -ForegroundColor Cyan -NoNewline
			Write-Host "$SnapShotName" -ForegroundColor Yellow -NoNewline
			Write-Host " was created before the deadline, we can continue!"  -ForegroundColor Cyan 
			Write-Host "Snapshot Creation Time in UTC: " -NoNewline
			$SnapShotCreationTimeUTC
			Write-Host "Deadline in UTC:               " -NoNewline
			$DeadLineUTC
			Write-Host "Deadline in EDT:               " -NoNewline
			$($DeadLineUTC.addhours(-4))
		} else {
			Write-Host "`n                                                                 " -ForegroundColor Red -BackgroundColor Black
			Write-Host "                           Warning!!!                            " -ForegroundColor Red -BackgroundColor Black
			Write-Host "The snapshot " -ForegroundColor Red -BackgroundColor Black -NoNewline
			Write-Host "$SnapShotName " -ForegroundColor Yellow -BackgroundColor Black -NoNewline
			Write-Host "was created AFTER the deadline!! Exiting! " -ForegroundColor Red -BackgroundColor Black
			Write-Host "                                                                 " -ForegroundColor Red -BackgroundColor Black
			Write-Host "Snapshot Creation Time in UTC: " -NoNewline -ForegroundColor Yellow
			$SnapShotCreationTimeUTC
			Write-Host "Deadline in UTC:               " -NoNewline -ForegroundColor Yellow
			$DeadLineUTC
			Write-Host "Deadline in EDT:               " -NoNewline -ForegroundColor Yellow
			$($DeadLineUTC.addhours(-4)) 
			Exit 10
		}
	} # End Function Confirm-NaSnapshotDate

# function to check if it is ok to proceed and exit the script if not ok
Function Confirm-Proceed ()
{
    $goodEntry = $false
    do
    {
	    Write-Host "Do you want to proceed?" -ForegroundColor Cyan -NoNewline
	    Write-Host " (y/n)" -ForegroundColor Red -NoNewline
	    Write-Host " : " -ForegroundColor Cyan -NoNewline
        $answer = $host.UI.RawUI.ReadKey("IncludeKeyDown")
        if ($answer.character -like "n")
        {
            Write-Host "`nUser aborted. Exiting script. Start over...`n" -ForegroundColor Red
		    Exit 2
        }
        elseif ($answer.character -like "y")
        {
            Write-Host "`nContinuing operation..."
            $goodEntry = $true
        }
        else
        {
            Write-Host "`nPlease answer yY/nN" -ForegroundColor Red
            $goodEntry = $false
        }
    }
    until ($goodEntry -eq $true)
} # end of function Confirm-Proceed


# Function to load the controller list from the Z drive
Function Get-ControllerList()
{
    $controllerPath = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\AllControllersVolumeListing"
    if (Test-Path $controllerPath) {
        $controllerList = ls $controllerPath | where {$_.Name -notlike "_*"} | sort Name | select Name
    } else {
        "I cannot get the controller list, sorry..."
    }
	Start-Sleep -Milliseconds 100
    return $controllerList
} # end of function Get-ControllerList


Function Show-ControllerList($cList)
{
	cls
    $conIndex = 0
	$myCounter = 0
	$allCounter = 0
	$wWidth = [console]::windowWidth
	$wHeigth = [console]::windowHeight
	if ($wHeigth -gt 46) {$wHeigth = 46}
	$printy = 0
	$printx = 0
	Write-Host ""
    foreach ($controller in $cList)
    {
		if ($allCounter -lt 10) {$Spacer = "  "}
		if ($allCounter -lt 100 -and $allCounter -gt 9) {$Spacer = " "}
		if ($allCounter -gt 99) {$Spacer = ""}
		[Console]::SetCursorPosition($printx,$printy)
        Write-Host $Spacer $conIndex $controller.Name"`t" -NoNewline
		#Start-Sleep -Milliseconds 10
        ++$conIndex
		if ($myCounter -eq 7) {
			Write-Host ""
			$myCounter = 0
		} else {
			$myCounter ++
		}
		
		if ($printy -eq $wHeigth-7 ) { # -or $printy -eq 39
			#[Console]::SetCursorPosition(0,$wHeigth-6)
			#Write-Host "PrintY: $printy" -NoNewline
			#Start-Sleep -Milliseconds 100
			$printY = 0
			$printX = $printX + 18
		} else {
			$printY ++
		}
		$allCounter ++
    }
	[Console]::SetCursorPosition(0,$wHeigth-6)
} # end of function Show-ControllerList

# function to get the source controller from the user using console input
Function Get-ControllerName ($cList, $defaultFilerHostname, $ShowText, $maxLength)
{
	$maxLength = $maxLength - $ShowText.Length - $defaultFilerHostname.Length
	# Write-Host "Hossz: $MaxLength" # This line is for testing
	$Spacer = " " * $maxLength
 	Write-Host "`n$ShowText $Spacer[" -NoNewline #Enter the index number (if you retrieved a list of controllers) or the controller name
	Write-Host "$defaultFilerHostname" -NoNewline -ForegroundColor Yellow
	Write-Host "] -> : " -NoNewline
	$SName = Read-Host # -Prompt "`nEnter the index number (if you retrieved a list of controllers) or the controller name [$defaultFilerHostname] -> "
	if ($SName -eq ""){
		return $defaultFilerHostname
	} else {
		$check = [int]::TryParse($SName, [ref]0)
		if ($check) {
			return $cList[$SName].Name    
		} else { # { ($check.Name -eq "String")   
			return $SName
		}
	}
} # end of function Get-ControllerName

# Function to retrieve the [virtual machine name / NetApp volume name / snapshot name] from the user using console input
Function Get-Parameter ($ShowText, $defaultValue, $maxLength)
{
	$maxLength = $maxLength - $ShowText.Length - $defaultValue.Length
	#Write-Host "Hossz: $MaxLength" # This line is for testing
	$Spacer = " " * $maxLength
	Write-Host "$ShowText $Spacer[" -NoNewline
	Write-Host "$defaultValue" -NoNewline -ForegroundColor Yellow
	Write-Host "] -> : " -NoNewline
    [string]$parameter = Read-Host
    if ([string]::IsNullOrWhitespace($parameter))
    {
        return $defaultValue
    }
    else
    {
        return $parameter 
    }
} # end of function Get-VirtualMachineName

Function Connect-MerckFiler ($FilerHostIP, $Password, $ShowText)
{
	$NoDice = $False
	try
	{
		$myFiler = Connect-NaController -Name $FilerHostIP -Credential $Password -HTTP -ErrorAction stop
	}
	
	catch
	{
		Write-Host "$ShowText" -ForegroundColor Red
		Write-Host $Error[0].Exception -ForegroundColor Red
		$NoDice = $True
	}
	return $myFiler,$NoDice
}

# Function to convert a hostname to ip address
Function Convert-HostnameToIP ($myHostName)
{
    $srcHostData = [System.Net.Dns]::GetHostAddresses($myHostName)[0]
	$HostIP = $srcHostData.IPAddressToString
    return $HostIP
} # end of function Convert-HostnameToIP

# Function to get the standard credentials for the filer
Function Set-MerckCredential ()
{
	$etc = "Z:\Storage\VM_SNAP_RECOVERY_PROCEDURE\scripts\NDMP Toolkit\etc"
	$keyFile = "$etc\naroot.key" 
	$credFile = "$etc\naroot.cred"
	$Password = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList "root", (Get-Content $credFile | ConvertTo-SecureString -Key (Get-Content $keyFile))
	return $Password
}

# Function to find which is the longest given txt
Function Set-MaxLength ($TextList)
{
	$MaxLength = 0
	foreach ($member in $TextList) {
		#Write-Host "$member"
		if ($member.length -gt $maxLength) {
			$maxLength = $member.length
		}
	}
	return $MaxLength
}

Function Show-Results ($SController,$fIP,$volName,$snapName,$vmHost,$Dsp)
{
	$srcpath = "/vol/$volName/.snapshot/$snapName/$vmHost"
	$dstpath = "/vol/$volName/$vmHost"
	if ("$Dsp" -eq "Show"){
		Write-Host "`nHost Name`t`tFiler IP address: " -ForegroundColor Cyan
		Write-Host "$SController`t`t$fIP`n" -ForegroundColor Yellow
		Write-host "Command will be:" -ForegroundColor Cyan
		Write-Host "ndmpcopy $srcpath $dstpath`n" -ForegroundColor Yellow
	}
	return $srcpath,$dstpath
} # end of function Show-Results

Function Show-ResultsDiff ($SrcControllerName,$SrcHostIP,$volName,$snapName,$vmHost,$DstControllerName,$dstHostIP,$DstVolumeName,$Dsp)
{
	$srcpath = "/vol/$volName/.snapshot/$snapName/$vmHost"
	$dstpath = "/vol/$DstVolumeName/$vmHost"
	if ("$Dsp" -eq "Show"){
		if ($SrcControllerName -ne $DstControllerName){
			$showText = "Source"
		} else {
			$showText = "Src/Dst"
		}
		Write-Host "`n$showText Filer`t`tFiler IP address: " -ForegroundColor Cyan
		Write-Host "$SrcControllerName`t`t$SrcHostIP`n" -ForegroundColor Yellow
		Write-host "Source Path: " -ForegroundColor Cyan
		Write-Host "$srcpath`n" -ForegroundColor Yellow
		if ($SrcControllerName -ne $DstControllerName){
			Write-Host "`nDestination Filer`tFiler IP address: " -ForegroundColor Cyan
			Write-Host "$DstControllerName`t`t$dstHostIP`n" -ForegroundColor Yellow
		}
		Write-host "Destination Path: " -ForegroundColor Cyan
		Write-Host "$dstpath`n" -ForegroundColor Yellow
	}
	return $srcpath,$dstpath
} # end of function Show-Results



<#	Change Log
#>