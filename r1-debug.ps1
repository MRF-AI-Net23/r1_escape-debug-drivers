# Function to install Chocolatey if not installed
function Install-Chocolatey {
    if (-not (Test-Path "$env:ProgramData\chocolatey")) {
        $InstallDir='C:\ProgramData\chocoportable'
        $env:ChocolateyInstall="$InstallDir"
        Set-ExecutionPolicy Bypass -Scope Process -Force;
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
        iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))
    }
}

# Check if Chocolatey is installed
if (-not (Test-Path "$env:ProgramData\chocolatey")) {
    Install-Chocolatey
}

function Install-PackageIfNotInstalled {
    param (
        [string]$PackageName,
        [string]$InstallerScript
    )
    if (-not (Get-Command $PackageName -ErrorAction SilentlyContinue)) {
        Write-Output "Installing $PackageName..."
        Invoke-Expression $InstallerScript
    }
}

Install-PackageIfNotInstalled "git" "choco install git -y"
Install-PackageIfNotInstalled "python" "choco install python -y"
Install-PackageIfNotInstalled "virtualenv" "pip install virtualenv"

Install-PackageIfNotInstalled "adb" "choco install adb -y"
Install-PackageIfNotInstalled "fastboot" "choco install fastboot -y"

python -m venv venv
.\venv\Scripts\Activate.ps1

$repoUrl = "https://github.com/AgentFabulous/mtkclient"
$repoName = [System.IO.Path]::GetFileNameWithoutExtension($repoUrl)
git clone $repoUrl
Set-Location -Path $repoName
pip install -r requirements.txt



# Function to detect a newly connected USB device by comparing device lists before and after connection
function Detect-NewUsbDevice {
    param (
        [string]$OutputFilePathBefore = "$env:TEMP\devices_before.txt",  # Default path for saving the list before connection
        [string]$OutputFilePathAfter = "$env:TEMP\devices_after.txt"     # Default path for saving the list after connection
    )

    # Function to get the list of all connected devices
    function Get-AllDevices {
        # Retrieve and return all connected devices, sorted by their friendly name
        Get-PnpDevice | Sort-Object -Property FriendlyName
    }

    # Function to save the list of devices to a file
    function Save-DeviceListToFile {
        param (
            [string]$FilePath  # Path to the file where the device list will be saved
        )
        
        # Get the list of all devices and save to the specified file
        Get-AllDevices | Out-File -FilePath $FilePath
    }

    # Function to compare two device lists and display the differences
    function Compare-DeviceLists {
        param (
            [string]$FilePath1,  # Path to the first file (before new device)
            [string]$FilePath2   # Path to the second file (after new device)
        )

        # Compare the two files and show the differences
        $Differences = Compare-Object -ReferenceObject (Get-Content $FilePath1) -DifferenceObject (Get-Content $FilePath2)
        if ($Differences) {
            Write-Host "Differences found:"
            $Differences | ForEach-Object { $_.SideIndicator + " " + $_.InputObject }
        } else {
            Write-Host "No differences found."
        }
    }

    # Main function logic

    # Save the list of devices before plugging in the new device
    Write-Host "Listing all currently connected devices..."
    Save-DeviceListToFile -FilePath $OutputFilePathBefore

    # Prompt the user to plug in the new device
    Write-Host "Please plug in your USB device now."
    Read-Host -Prompt "Press Enter once the device is plugged in"

    # Wait for 3 seconds to allow the drivers to load
    Start-Sleep -Seconds 3

    # Save the list of devices after plugging in the new device
    Write-Host "Listing all devices after plugging in the new device..."
    Save-DeviceListToFile -FilePath $OutputFilePathAfter

    # Compare the two device lists and display the differences
    Write-Host "Comparing device lists..."
    Compare-DeviceLists -FilePath1 $OutputFilePathBefore -FilePath2 $OutputFilePathAfter

    # Optionally, clean up the temporary files
    Remove-Item $OutputFilePathBefore, $OutputFilePathAfter -Force
}

# Example usage:
# To call the function from another script, simply use:
# Detect-NewUsbDevice

# If you want to specify custom file paths, call it like this:
# Detect-NewUsbDevice -OutputFilePathBefore "C:\path\to\before.txt" -OutputFilePathAfter "C:\path\to\after.txt"












clear
Write-Host "If the device is in the correct state, it should show:"
Write-Host "MediaTek PreLoader USB VCOM (Android) COMx"
Write-Host ""
Write-Host "In some states, the device can be on but display nothing on the screen, which can be confusing, so make sure it's off."
Write-Host "If that is not what shows up, stop, unplug, and use the hidden reset button in the SIM compartment. Push for 30 seconds."
Write-Host ""
Write-Host "If the R1 powers on, beeps a few times, and then shows the rabbit running in a wheel, wait until the display turns off, then press the power button for 3 seconds and wait."
Write-Host ""
Write-Host "If you know you're already in an odd state, it should be safe to go ahead, as you already have problems."
Write-Host ""
Write-Host "If things are working it should pause of a long time be pashint and wait."
Write-Host " "
Write-Host "xflashext - DA version anti-rollback patched......takes upto  5 minuetts"
Write-Host "DAXFlash - Uploading stage 2......................takes upto 10 minuetts"
Write-Host "DA_handler - Requesting available partitions......takes upto 15 minuetts"

Read-Host "[*] Power off the device, press ENTER, and then plug the device in"
Detect-NewUsbDevice
Write-Host " "


Write-Host "Now we are going to read the FPR from the device and wright it to frp.bin"
Write-Host "if this step fails then when we try and wright it back in the next stage will fail with a file not found"
Write-Host " "
python mtk r frp frp.bin --serialport
Write-Host "FPR stage 1 finished unsure if it worked for you or not"
Detect-NewUsbDevice
Write-Host " "


$currentDir = Get-Location
$frpBinPath = Join-Path -Path $currentDir -ChildPath "frp.bin"
$frpBinBytes = [System.IO.File]::ReadAllBytes($frpBinPath)
if ($frpBinBytes[-1] -eq 0x00) {
    $frpBinBytes[-1] = 0x01
    [System.IO.File]::WriteAllBytes($frpBinPath, $frpBinBytes)
}

Read-Host "[*] Unplug the device, press ENTER, and then plug the device in"
Detect-NewUsbDevice


python mtk w frp frp.bin --serialport

Set-Location -Path $PSScriptRoot

Read-Host "[*] Unplug the device, press ENTER, and then plug the device in"
Detect-NewUsbDevice

Start-Process -Wait -FilePath python -ArgumentList "mtkbootcmd.py FASTBOOT"

Write-Output "[*] Waiting for fastboot..."

do {
    Start-Sleep -Seconds 1
    $fastbootDevices = fastboot devices
} while (-not $fastbootDevices)

fastboot flashing unlock
fastboot -w
fastboot flash --disable-verity --disable-verification vbmeta vbmeta.img
fastboot reboot-fastboot
fastboot flash system system.img
fastboot reboot
