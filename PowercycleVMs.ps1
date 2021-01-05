<#
  .SYNOPSIS
  PowerCli script to powercycle Virtual Machines to simplify CPU Vulnerability Remediation.

  .DESCRIPTION
  PowerCli script to powercycle Virtual Machines to simplify CPU Vulnerability Remediation.

  .PARAMETER filename
  Specifies the path to the input file list of servers.

  .PARAMETER log
  Specifies the name and path of the generate log file. By default,
  a Powercycle%date%.log file gets created.

  .EXAMPLE
  C:\PS> .\PowercycleVMs.ps1 DEVbatch1.txt DEVbatch1.log
  
  .LINK
  https://github.com/nagten/PowerCycleVMs
  
  .NOTES
  Author: Nico Agten
  Last Edit: 24-May-2018
  Version 1.0 - initial release
#>


param (
[string]$filename = "ToPowerCycleVMs.txt", 
[string]$log = "Powercyle" + (get-date -uformat %Y-%m-%d) + ".log"
)

Set-StrictMode -Version 1.0

$scriptstartTime = (get-date).TimeofDay

if (Test-Path $filename)
{
	$powercycleVMList = Get-Content -Path $filename
}
else
{
	#No input file stop
	Write-Host "Can't find source file $filename `n" -ForegroundColor Red 
	exit
}

$logFile = $PSScriptRoot + "\" + $log

$poweredOnVMs = $PSScriptRoot + "\VMsThatHaveBeenShutdown.txt"
$vmwaretoolsNotRunning =  $PSScriptRoot + "\NoVMwareToolsRunning.txt"

$vmsPoweringDown = new-object system.collections.arraylist

function main()
{
	ShutdownPowercycleVMs
	sleep 5
	StartupPowercycleVMs
}

function ShutdownPowercycleVMs()
{
	Write-Host "Processing file $filename, actions will be logged to $logFile `n"
	Write-Host "Shutting down vitual machines:" -ForegroundColor Green 
	
	#Delete temporary file if it exists
	if (Test-Path $poweredOnVMs)
	{
		Remove-Item $poweredOnVMs
	}
	
	Foreach ($vmToShutdown in $powercycleVMList)
	{
		if ([string]::IsNullOrEmpty($vmToShutdown))
		{
			#Empty line do nothing
		}
		else
		{
			Try
			{
				$logTime = Get-Date

				#Get the VM-object filter out SRM servers
				$vm = Get-VM -name $vmToShutdown -ErrorAction Stop | where {$_.ExtensionData.Config.ManagedBy.extensionKey -notmatch 'com.vmware.vcDr'} 

				#Check if server is powered on, we will only powercyle poweredon vms
				if ($vm.PowerState -eq 'PoweredOn')
				{
					#check if vmwaretools is running, if not we can't cleanly shutdown the vm
					if($vm.Guest.Extensiondata.GuestState -eq 'notRunning')
					{
						$logTime.ToString('s') + ";VMware tools not running;" + $vm | Tee-Object -FilePath $logfile -Append
						#Store vms where VMware tools is not running
						Add-Content -path $vmwaretoolsNotRunning $vm.Name
					}
					else
					{
						#Store the powered on VMs that have vmware tools running
						Add-Content -path $poweredOnVMs $vm.Name
						
						#Shutdown the virtual machine via vmwaretools
						$logTime.ToString('s') + ';Shutdown-VMGuest;' + $vm | Tee-Object -FilePath $logfile -Append
						$result = Stop-VMGuest -VM $vm -Confirm:$false
						#$result = Stop-VMGuest -VM $vm -Confirm:$false -WhatIf
						
						$count = $vmsPoweringDown.add($vm)					
					}	
				}
			}
			Catch
			{
				$ErrorMessage = $_.Exception.Message
				Write-Host "Virtual machine $vmToShutdown was not found" -ForegroundColor Red
			}
		}
	}
	
	#Wait until all VMs are powered down or until we reach our timeout
	$waitMaxTime = 300 #300 seconds = 5 minutes
	$startTime = (get-date).TimeofDay
	
	Write-Host "`nChecking if vms are succefully powered down 0 seconds have passed, max wait time $waitMaxTime seconds" -ForegroundColor DarkGreen
	
	do
	{
		#Write-Host 'Sleep 60 and checking for running vms'
		#every 60 seconds we check if servers are powered down
		sleep 30

		for ($intI = 0; $intI -lt $vmsPoweringDown.count; $intI++)
		{
			#check all vms
			
			if (((Get-VM $vmsPoweringDown[$intI]).PowerState | where {$_.ExtensionData.Config.ManagedBy.extensionKey -notmatch 'com.vmware.vcDr'}) -eq 'PoweredOn')
			{
				continue
			}
			else
			{
				#Server is powered down remove form list
				$vmsPoweringDown.RemoveAt($intI)
				$intI--
			}
		}
		
		$timepassed = ((get-date).TimeofDay - $startTime).TotalSeconds
		Write-Host "Checking if vms are succefully powered down $([math]::Round($timepassed,2)) seconds have passed, max wait time $waitMaxTime seconds" -ForegroundColor DarkGreen		
	} while ( ($vmsPoweringDown.count -gt 0) -and ( ( (get-date).TimeofDay - $startTime).TotalSeconds -lt $waitMaxTime) )
	
	if ($vmsPoweringDown.count -gt 0)
	{
		#Force poweroff vm's?
		Write-Host "Force poweroff for running vms after $waitMaxTime seconds" -ForegroundColor DarkGreen
	
		foreach ($vmName in $vmsPoweringDown)
		{
			$vm = Get-VM -Name $vmName | where {$_.ExtensionData.Config.ManagedBy.extensionKey -notmatch 'com.vmware.vcDr'}
			
			if ($vm.PowerState -eq 'PoweredOn')
			{
				#Force power off of the virtual machine
				$logTime = Get-Date
				$logTime.ToString('s') + ';Stop-VM;' + $vm | Tee-Object -FilePath $logfile -Append
				
				$result = Stop-VM -VM $vm -confirm:$false
				#$result = Stop-VM -VM $vm -confirm:$false -WhatIf
			}
		}
	}
}

function StartupPowercycleVMs()
{
	#If we had previously had powered on virtual machines we will power them on again
	if (Test-Path $poweredOnVMs)
	{
		Write-Host "`nPowering on vitual machines that where previously shutdown:" -ForegroundColor Green
		$vmsToStart = Get-Content $poweredOnVMs

		Foreach ($vmToStart in $vmsToStart) #$powercycleVMList)
		{
			$logTime = Get-Date
			
			#Get the VM
			$vm = Get-VM -name $vmToStart | where {$_.ExtensionData.Config.ManagedBy.extensionKey -notmatch 'com.vmware.vcDr'}
			
			# Start the VM
			$logTime.ToString('s') + ';Start-VM;' + $vm | Tee-Object -FilePath $logfile -Append
			$result = Start-VM -VM $vm -Confirm:$false -RunAsync
			#$result = Start-VM -VM $vm -Confirm:$false -RunAsync -WhatIf
		}
		
		$ElapsedTime = (get-date).TimeofDay - $scriptstartTime
		Write-Host "`nVirtual machines power cycled, please check log $vmwaretoolsNotRunning for vm's without running vmwaretools they need to be manually powercycled" -ForegroundColor Green
		
		Write-Host "`nTotal script runtime: $($ElapsedTime.Minutes) min $($ElapsedTime.Seconds) sec"
	}
	else
	{
		Write-Host "No vitual machines to power on again" -ForegroundColor DarkGreen
	}
}

#Start script
main