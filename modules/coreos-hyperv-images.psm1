############################
#### Protected Functions ###
############################
<#
.SYNOPSIS
    Gets a coreos image to use for coreos vms.
.DESCRIPTION
    Gets a coreos image to use for coreos vms. Checks if the release required is available locally.
    If it isn't available loacally the image will be downloaded and uncompressed. If no release is
    specified then the current version will be queried and downloaded.
.PARAMETER ImagesDir
    The directory to download the images to.
.PARAMETER Channel
    The coreos channel to download the image from. The possible values are Alpha, Beta or Stable.
.PARAMETER Release
    The release to get. If none is specified then the current version will be retrieved.
.OUTPUTS
    Outputs an object with the release number ($_.Release) and the image path ($_.ImagePath).
#>
Function Get-CoreosImage {
    [CmdletBinding()]
    Param (
        [Parameter (Mandatory=$true)]
        [String] $ImagesDir,

        [Parameter (Mandatory=$true)]
        [ValidateSet("Alpha","Beta","Stable")] 
        [String] $Channel,

        [Parameter (Mandatory=$false)]
        [String] $Release = ""
    )

    PROCESS {
        if ($Release -eq "" -or $Release.ToLower -eq "current") {
            $Release = Get-CurrentVersion -Channel:$Channel
        }

        $r = New-Object PSObject
        $r | Add-Member Release $Release

        $localPath = Get-ReleaseLocalPath -ImagesDir:$ImagesDir -Release:$Release
        $r | Add-Member ImagePath $localPath

        if (Test-Path $localPath) {
            Write-Output $r
            return
        }

        if (!(Test-BzipInPath)) {
            throw "Bzip not in PATH. Bzip is required to decompress images"
            return
        }

        Get-CoreosImageFromSite -ImageSavePath:$localPath -Channel:$Channel -Release:$Release

        Write-Output $r
    }
}

<#
.SYNOPSIS
    Gets the base config drive vhd to build config drives off.
.PARAMETER ModuleFilesDir
    The directory conatining files for the module.
.PARAMETER ImagesDir
    The directory that images are saved to.
#>
Function Get-BaseConfigDrive {
    [CmdletBinding()]
    Param (        
        [Parameter (Mandatory=$true)]
        [String] $ModuleFilesDir,

        [Parameter (Mandatory=$true)]
        [String] $ImagesDir
    )

    PROCESS {
        $vhd = Join-Path -Path $ImagesDir "config2_base.vhdx"

        if (Test-Path $vhd) {
            Write-Output $vhd
            return
        }

        $base = Join-Path -Path $ModuleFilesDir "config2_base.vhdx.bz2"

        if (!(Test-BzipInPath)) {
            throw "Bzip not in PATH. Bzip is required to decompress images"
            return
        }

        Invoke-Bunzip -Target:$base -Destination:$vhd

        Write-Output $vhd
    }
}

############################
#### Private Functions #####
############################
Function Get-CurrentVersion {
    [CmdletBinding()]
    Param (
        [Parameter (Mandatory=$true)]
        [ValidateSet("Alpha","Beta","Stable")] 
        [String] $Channel
    )

    PROCESS {
        $release = ""

        $uri = "http://$($Channel.ToLower()).release.core-os.net/amd64-usr/current/version.txt"
        $release = ((Invoke-WebRequest -Uri:$uri).Content -split('[\r\n]')) | foreach { if ($_ -like "COREOS_VERSION*") { Write-Output $(($_ -split('='))[1]) }} | Select-Object -First 1

        if ($release -eq "") {
            throw "Release does not exist in channel $Channel"
            return
        }

        Write-Output $release
    }
}

Function Get-ReleaseLocalPath {
    [CmdletBinding()]
    Param (
        [Parameter (Mandatory=$true)]
        [String] $ImagesDir,

        [Parameter (Mandatory=$true)]
        [String] $Release
    )

    PROCESS {
        $r = $Release -replace "\.", "_"
        Write-Output $(Join-Path -Path $ImagesDir "coreos-hyperv_$r.vhd")
    }
}

Function Test-BzipInPath {
    [CmdletBinding()]
    Param (
    )

    PROCESS {
        try {
            Get-Command bunzip2 -ErrorAction:Stop
        } catch {
            Write-Output $false
            return
        }

        Write-Output $true
    }
}

Function Get-CoreosImageFromSite {
    [CmdletBinding()]
    Param (
        [Parameter (Mandatory=$true)]
        [String] $ImageSavePath,

        [Parameter (Mandatory=$true)]
        [ValidateSet("Alpha","Beta","Stable")] 
        [String] $Channel,

        [Parameter (Mandatory=$true)]
        [String] $Release
    )

    PROCESS {
        $tmp = "$ImageSavePath.bz2"

        if (Test-Path $tmp) {
            Remove-Item -Force $tmp
        }

        $uri = "http://$($Channel.ToLower()).release.core-os.net/amd64-usr/$Release/coreos_production_hyperv_image.vhd.bz2"

        try {
            Invoke-WebRequest -Uri $uri -OutFile $tmp    
        } catch {
            throw "Release $Release not found on $Channel channel. $url"
            return
        }

        Invoke-Bunzip -Target:$tmp -Destination:$ImageSavePath

        if (!(Test-Path $ImageSavePath)) {
            throw "Failed to uncompress image."
            return
        }
    }
}

Function Invoke-Bunzip {
    [CmdletBinding()]
    Param (
        [Parameter (Mandatory=$true)]
        [String] $Target,

        [Parameter (Mandatory=$true)]
        [String] $Destination
    )

    PROCESS {
        Write-Verbose "Bunzipping $Target to $Destination"
        & cmd /C "bunzip2 -c -k `"$Target`" > `"$Destination`"" | Out-Null
    }
}