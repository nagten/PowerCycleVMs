# PowerCycleVMs
PowerCli script to powercycle Virtual Machines to simplify CPU Vulnerability (Spectre/Meltdown/...) Remediation

How to use:

1. Logon to your vCenter server(s): *Connect-VIServer –Server wildonion, wildcherry*
2. Run the script with the correct command line parameters e.g. in this case: 

**.\PowercycleVMs.ps1 DEVbatch1.txt DEVbatch1.log**

3. The script will run and process all servers in file DEVbatch1.txt and log output to log-file DEVbatch1.log

![Overview Image](https://github.com/nagten/PowerCycleVMs/blob/main/Images/Overview.png)

4. If for some reason a virtual machine can’t be cleanly shutdown e.g. because VMware tools is missing or it isn’t running the virtual machine’s name will be logged in following text file: NoVMwareToolsRunning.txt. After running the power cycle script one needs to check this file (if it exists) and power cycle these virtual machine manually. Afterwards delete the NoVMwareToolsRunning.txt because otherwise virtual machine names will be appended to it.

Since VMware ESXi 6.7 Update 3 released on 20-aug-2019 VMWare added an option vmx.reboot.PowerCycle to simplify CPU Vulnerability Remediations via vCenter itself
https://blogs.vmware.com/vsphere/2019/10/vmx-reboot-powercycle-makes-cpu-vulnerability-remediation-easy.html
