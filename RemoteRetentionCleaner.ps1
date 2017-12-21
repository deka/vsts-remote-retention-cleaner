[CmdletBinding()]
param (
)

Trace-VstsEnteringInvocation $MyInvocation

[string]$folderPath = Get-VstsInput -Name "folderPath" -Require
[int]$retentionDays = Get-VstsInput -Name "retentionDays" -Require
[int]$minimumToKeep = Get-VstsInput -Name "minimumToKeep" -Require
[string]$remoteComputer = Get-VstsInput -Name "remoteComputer" -Require
[string]$userName = Get-VstsInput -Name "userName" -Require
[string]$password = Get-VstsInput -Name "password" -Require
[string]$excludes = (Get-VstsInput -Name "excludes").Trim().Replace("`n",",")
[string]$winRMProtocol = Get-VstsInput -Name "winRMProtocol"

Write-Host "Version 1.0.8"
Write-Host "remoteComputer = $remoteComputer"
Write-Host "folderPath = $folderPath"
Write-Host "retentionDays = $retentionDays"
Write-Host "minimumToKeep = $minimumToKeep"
Write-Host "userName = $userName"
Write-Host "password = $password"
Write-Host "excludes = $excludes"
Write-Host "winRMProtocol = $winRMProtocol"

$portNumber = 5985;
$sslArg = $false;

if([string]::IsNullOrWhiteSpace($folderPath) ) 
{  
    throw [System.ArgumentException] "Folder path required"
    exit
}

if([string]::IsNullOrWhiteSpace($retentionDays) ) 
{            
    throw [System.ArgumentException] "Rentention days required"
    exit
}


if([string]::IsNullOrWhiteSpace($minimumToKeep) ) 
{            
   throw [System.ArgumentException] "Minimum to keep is required"
    exit
}

if([string]::IsNullOrWhiteSpace($remoteComputer) ) 
{            
    throw [System.ArgumentException] "Remote computer is required"
    exit
}

if([string]::IsNullOrWhiteSpace($userName) ) 
{            
    throw [System.ArgumentException] "Username is required"
    exit
}

if([string]::IsNullOrWhiteSpace($password) ) 
{
  throw [System.ArgumentException] "Password is required"
  exit
}

if(-not [string]::IsNullOrWhiteSpace($winRMProtocol) ) 
{  
	if ($winRMProtocol -eq "Https") 
	{ 
		$portNumber = 5986;
		$sslArg = $true;
	}
}

$script = { 
		  
			 $folderPath = $args[0]
			 $retentionDays = $args[1]
			 $minimumToKeep = $args[2]
			 $excludes = $args[3]

	$folderlist = Get-ChildItem $folderPath -Exclude $excludes.Split(",") | sort @{Expression={$_.LastWriteTime}; Ascending=$false}
	Write-Host "Item list : "
	Write-Host $folderlist
	
	$keepDate = (Get-Date).AddDays(-$retentionDays)
	$keeping = 0
    $deleting = 0

	ForEach ($folder In $folderlist) {
		
		if($folder.LastWriteTime -lt $keepDate -And $minimumToKeep -le $keeping)
		{
		   Write-Host "Deleting $($folder.FullName)"
		   Remove-Item $folder.FullName -Recurse -Force
		   $deleting++
        }
		else
		{
			$keeping++
		}
	}

     Write-Host "Deleting $($deleting) files/folders."
	 Write-Host "Keeping $($keeping) files/folders."
}

$computers = $remoteComputer.split(',',[System.StringSplitOptions]::RemoveEmptyEntries)
if($computers.Count -eq 0)
  {  Write-Error "No remote computer"}
   
$errors =@()

foreach($computer in $computers)
{
	Try
	{
		Write-Host "Start process. Computer name : $($computer)."
		Write-Host "	- PSCredential"
		$credential = New-Object System.Management.Automation.PSCredential($userName, (ConvertTo-SecureString -String $password -AsPlainText -Force));
		Write-Host "	- Initialize New-PSSession"
		$session = New-PSSession -ComputerName $computer -Credential $credential -Port $portNumber -UseSSL:$sslArg;

		Write-Host "	- Invoke-Command"
		Invoke-Command -Session $session -ScriptBlock $script -ArgumentList $folderPath, $retentionDays ,$minimumToKeep, $excludes
		Write-Host "	- Remove-PSSession"
		Remove-PSSession -Session $session
	}
	Catch
	{			
		$errors += @($computer + " " + $_.Exception.Message)
	}		
}	

if($errors.Count -ne 0)
{
	foreach( $er in $errors)
	{
		Write-Warning $er
	}
	
	throw "$($errors.Count) errors in process. See logs"
}



