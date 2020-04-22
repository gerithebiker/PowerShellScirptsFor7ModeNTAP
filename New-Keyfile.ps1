<#
.SYNOPSIS
    Creates a keyfile to use with the encryption of credentials.

.DESCRIPTION
    Creates a keyfile to use in encrypting credentials. The keyfile can be stored in a secure location and
    used for automation of scripts.

.INPUTS
    None

.OUTPUTS
    *.key keyfile

.PARAMETER keyName
    The name of the key to be created.

.PARAMETER byteLength
    The length (in bytes) of the key to be created. Defaults to 32 bytes

.NOTES
    Version:         1.0
    Author:          Kevin Ayers kevin.ayers@cognizant.com
    Creation Date:   September 1, 2017
    Change Date:     September 1, 2017
    Purpose/Change:  The keyfile will be created in the path the script was executed from.
                     SEE CHANGELOG AT BOTTOM OF SCRIPT FOR MORE INFORMATION
.EXAMPLE
    Create a keyfile named Example.key in the current directory that uses the default 32 bytes in length.
    PS D:\> .\New-Keyfile.ps1 -keyName "Example"

.EXAMPLE
    Create a keyfile named Example2.key in the current directory that is 64 bytes in length.
    PS D:\> .\New-Keyfile.ps1 -keyName "Example2" -byteLength 64

.EXAMPLE
    Create a keyfile named Example3.key from the Windows command line in the current directory that uses the default 32 bytes in length.
    C:\>Powershell.exe -Executionpolicy RemoteSigned -File D:\New-Keyfile.ps1 -Args "Example3"
#>

param 
(
    [Parameter(Position=0)][string]$keyName = $null,
    [Parameter(Position=1)][int]$byteLength = 32
)

function Check-KeyNameExist($kName)
{
    $myFileName = ".\" + $kName + ".key"
    if (!(Test-Path $myFileName))
    {
        return $false
    }
    else
    {
        return $true
    }
}

function Get-KeyName()
{
    $done = $true
    do
    {
        $kName = Read-Host -Prompt "`nWhat do you want to name the new key (type quit to exit)? -> "
        if ($kName -like "quit")
        {
            Write-Host "Script cancelled by user" -ForegroundColor Red
            $done = $true
            Exit 1
        }
        elseif ($kName -eq "" -or $kName -eq $null)
        {
            Write-Host "You did not supply a name, Please try again" -ForegroundColor Yellow
            $done = $false
        }
        elseif (Check-KeyNameExist -kName $kName)
        {
            Write-Host "$kName.key already exists in the current working directory. Please supply a different name." -ForegroundColor Yellow
            $done = $false
        }
        else
        {
            Write-Host "You entered $kName. Is $kName.key what you want to name your key (yY/nN)? " -NoNewline
            $answer = $host.UI.RawUI.ReadKey("IncludeKeyDown")
            if ($answer.character -like "n")
            {
                Write-Host "Please enter a name you would like to use" -ForegroundColor Cyan
                $done = $false
            }
            else
            {
                Write-Host "`nUsing $kName.key for the keyfile to be generated" -ForegroundColor Green
                $done = $true
            }
        }
    }
    until ($done -eq $true)
    return $kName
}

function Create-Keyfile ($myKeyName,$bLength)
{
    try
    {
        $key = New-Object Byte[] $bLength
        [Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($key)
        $key | Out-File .\$myKeyName.key
    }
    catch
    {
        Write-Host "`n`tError creating keyfile!" -ForegroundColor Red
        Write-Host $error[0].Exception -ForegroundColor Red
        exit 9999
    }
    Write-Host "`n`tKeyfile $myKeyName.key created successfully." -ForegroundColor Green
}

if (!($keyName -eq $null -or $keyName -eq ""))
{
    if (!(Check-KeyNameExist -kName $keyName))
    {
        Create-Keyfile -myKeyName $keyName -bLength $byteLength
    }
    else
    {
        Write-Host "`n`t$keyName.key exists. Try a different keyname." -ForegroundColor Yellow
        $keyName = Get-KeyName
        Create-Keyfile -myKeyName $keyName -bLength $byteLength
    }
}
else
{
    $keyName = Get-KeyName
    Create-Keyfile -myKeyName $keyName -bLength $byteLength
}

Write-Host "`nNew-Keyfile.ps1 completed successfully" -ForegroundColor Blue
exit 0