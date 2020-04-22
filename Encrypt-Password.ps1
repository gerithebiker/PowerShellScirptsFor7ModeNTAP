<#
.SYNOPSIS
    Creates an encrypted password file.

.DESCRIPTION
    Creates an encrypted password file from user input and stores in the current working directory.

.INPUTS
    None

.OUTPUTS
    *.cred credential file.

.PARAMETER keyName
    The fully qualified path of the key file to be used to encrypt the password.

.PARAMETER credName
    The name of the encrypted password.

.NOTES
    Version:         1.0
    Author:          Kevin Ayers kevin.ayers@cognizant.com
    Creation Date:   September 1, 2017
    Change Date:     September 1, 2017
    Purpose/Change:  The credfile will be created in the path the script was executed from.
                     SEE CHANGELOG AT BOTTOM OF SCRIPT FOR MORE INFORMATION
.EXAMPLE
    Create a credfile named Example.cred in the current directory using keyfile .\Example.key.
    PS D:\> .\Encrypt-Password.ps1 -keyName ".\Example.key" -credName "myPassword"
#>

param 
(
    [Parameter(Position=0,Mandatory=$true)][string]$keyName,
    [Parameter(Position=1,Mandatory=$true)][string]$credName
)

function Check-NameExist($myName)
{
    if (!(Test-Path $myName))
    {
        return $false
    }
    else
    {
        return $true
    }
}

function Create-Credfile ($myKeyFile,$myCredFile)
{
    try
    {
        $key = Get-Content $myKeyFile
        $myCred = Get-Credential
        $myCred.Password | ConvertFrom-SecureString -Key $key | Out-File $myCredFile
    }
    catch
    {
        Write-Host "`n`tError creating credfile!" -ForegroundColor Red
        Write-Host $error[0].Exception -ForegroundColor Red
        exit 9999
    }
    Write-Host "`n`tCredfile $myCredFile created successfully." -ForegroundColor Green
}



Write-Host $keyName $credName
if (Check-NameExist -myName $keyName)
{
    $credFile = ".\" + $credName + ".cred"
    Write-Host $credFile
    if (!(Check-NameExist -myName $credFile))
    {
        Create-Credfile -myKeyFile $keyName -myCredFile $credFile
    }
    else
    {
        Write-Host "`n`t$credFile exists. Aborting script" -ForegroundColor Red
        exit 9999
    }
}
else
{
    Write-Host "`nKeyfile $keyName does not exist. Aborting..." -ForegroundColor Red
    exit 1
}

Write-Host "`nEncrypt-Password.ps1 completed successfully" -ForegroundColor Blue
exit 0