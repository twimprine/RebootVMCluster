$VCenterServer = "rack-1-vc-4.vcf01.xula.local"


Connect-VIServer $VCenterServer

$Cluster = Get-Cluster

foreach ($VMHost in Get-VMHost) {
    
    # Let's make sure all the hosts are in a good connected state first
    $VMHosts = Get-VMHost | Where-Object {$_.ConnectionState -notlike "Connected"}
    if ($VMHosts) {
        Write-Host -ForegroundColor Red "Cluster is not in proper state. Check $VMhosts"
        break
    }

    Write-Host "Putting $VMHost into Maintenance Mode"
    
    Get-DrsRecommendation -Cluster $Cluster | Where-Object {$_.Reason -eq "Host is entering maintenance mode"} | Apply-DrsRecommendation
    Set-VMHost -VMHost $VMHost -State "Maintenance" 
    #Wait-Task -Task $Task

    # Check host to ensure it's in maint mode
    if (!(Get-VMHost $VMHost | Where-Object {$_.ConnectionState -like "Maintenance Mode"})) {
        Write-Host -ForegroundColor Red "Host is not in Maintenance mode as expected - Exiting"
        break
    }
    # Reboot Host
    Restart-VMHost -Confirm $false
    Start-Sleep -Seconds 600

    # Check host for boot up and if it doesn't come back within an hour exit
    do {
        Start-Sleep -Seconds 300
    } while (Get-VMHost $VMHost | Where-Object {$_.ConnectionState -notlike "Maintenance Mode"})

    # Take the host out of Maintenance mode
    Set-VMHost -VMHost $VMHost -State "Connected" -Confirm $false
}