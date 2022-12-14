param(
    [Parameter(Mandatory=$False)][string]$RunMode = "Collect"   
    )

# Common options
$basedir="C:\log-collector"
$instanceid = Invoke-RestMethod -uri http://169.254.169.254/latest/meta-data/instance-id
$curtime = Get-Date -Format FileDateTimeUniversal
$outfilename = "eks_" + $instanceid + "_" + $curtime + ".zip"
$infodir="$basedir\collect"
$info_system="$infodir\system"


# Common functions
# ---------------------------------------------------------------------------------------

Function is_elevated{
    If (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
    [Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Write-warning "This script requires elevated privileges to copy registry keys to the EKS logs collector folder."
        Write-Host "Please re-launch as Administrator." -foreground "red" -background "black"
        break
    }
}


Function create_working_dir{
    try {
        Write-Host "Creating temporary directory"
        New-Item -type directory -path $info_system -Force >$null
        New-Item -type directory -path $info_system\containerd -Force >$null
        New-Item -type directory -path $info_system\containerd_log -Force >$null
        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Host "Unable to create temporary directory"
        Write-Host "Please ensure you have enough permissions to create directories"
        Write-Error "Failed to create temporary directory"
        Break
    }
}

Function is_diskfull{
    $threshold = 30
    try {
        Write-Host "Checking free disk space"
        $drive = Get-WmiObject Win32_LogicalDisk -Filter "DeviceID='C:'"
        $percent = ([math]::round($drive.FreeSpace/1GB, 0) / ([math]::round($drive.Size/1GB, 0)) * 100)
        Write-Host "C: drive has $percent% free space"
        Write-Host "OK" -ForegroundColor "green"
    }
    catch {
        Write-Error "Unable to Determine Free Disk Space" 
        Break
    }
    if ($percent -lt $threshold){
        Write-Error "C: drive only has $percent% free space, please ensure there is at least $threshold% free disk space to collect and store the log files" 
        Break
    }
}

Function get_containerd_info{
    try {
        Write-Host "Collecting containerd daemon information"
        ctr version > $info_system\containerd\containerd-version.txt 2>&1
        ctr -n k8s.io tasks list > $info_system\containerd\containerd-tasks-list.txt 2>&1
        ctr -n k8s.io container list > $info_system\containerd\containerd-list.txt 2>&1
        ctr -n k8s.io image list > $info_system\containerd\containerd-images.txt 2>&1 
        Write-Host "OK" -foregroundcolor "green"
    }
    catch{
        Write-Error "Unable to collect containerd daemon information"
        Break
    }
}

Function get_containerd_logs{
    try {
        Write-Host "Collecting containerd daemon logs"
        copy C:\ProgramData\containerd\root\panic.log $info_system/containerd_log\
        Write-Host "OK" -foregroundcolor "green"
    }
    catch {
        Write-Error "Unable to collect containerd daemon logs"
        Break
    }
}

Function cleanup{
    Write-Host "Cleaning up directory"
    Remove-Item -Recurse -Force $basedir -ErrorAction Ignore
    Write-Host "OK" -foregroundcolor green
}

Function pack{
    try {
        Write-Host "Archiving gathered data"
        Compress-Archive -Path $infodir\* -CompressionLevel Optimal -DestinationPath $basedir\$outfilename
        Remove-Item -Recurse -Force $infodir -ErrorAction Ignore
        Write-Host "Done... your bundled logs are located in " $basedir\$outfilename
    }
    catch {
        Write-Error "Unable to archive data"
        Break
    }
}

Function init{
    is_elevated
    create_working_dir
}
    
Function collect{
    init
    is_diskfull
    get_containerd_info
    get_containerd_logs

}

#--------------------------
#Main-function
Function main {   
    Write-Host "Running Default(Collect) Mode" -foregroundcolor "blue"
    cleanup
    collect
    pack 
}

#Entry point
main
