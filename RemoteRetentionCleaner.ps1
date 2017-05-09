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

Write-Host "folderPath = $folderPath"
Write-Host "retentionDays = $retentionDays"
Write-Host "minimumToKeep = $minimumToKeep"
Write-Host "remoteComputer = $remoteComputer"
Write-Host "userName = $userName"
Write-Host "password = $password"

$script = { 
		  
			 $folderPath = $args[0]
			 $retentionDays = $args[1]
			 $minimumToKeep = $args[2]

	$folderlist = Get-ChildItem $folderPath | sort @{Expression={$_.LastWriteTime}; Ascending=$false}

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
   
foreach($computer in $computers)
{
	Write-Host "Start process. Computer nam : $($computer)."
	$credential = New-Object System.Management.Automation.PSCredential($userName, (ConvertTo-SecureString -String $password -AsPlainText -Force));
	$session = New-PSSession -ComputerName $computer -Credential $credential;
	Invoke-Command -Session $session -ScriptBlock $script -ArgumentList $folderPath, $retentionDays ,$minimumToKeep
	Remove-PSSession -Session $session
}



