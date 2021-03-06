function Get-PsAzureDevOps {
    Param(
        [switch] $Force
    )
    Write-Output "Welcome to the PsAzureDevOps Module installer!"
    if(Check-Chocolatey -Force:$Force){
        Write-Output "Chocolatey installed, Installing PsAzureDevOps Modules."
        cinst PsAzureDevOps
        $Message = "PsAzureDevOps Module Installer completed"
    }
    else {
        $Message = "Did not detect Chocolatey and unable to install. Installation of PsAzureDevOps has been aborted."
    }
    if($Force) {
        Write-Host $Message
    }
    else {
        Read-Host $Message
    }
}

function Check-Chocolatey {
    Param(
        [switch] $Force
    )
    if(-not $env:ChocolateyInstall -or -not (Test-Path "$env:ChocolateyInstall")){
        $message = "Chocolatey is going to be downloaded and installed on your machine. If you do not have the .NET Framework Version 4 or greater, that will also be downloaded and installed."
        Write-Host $message
        if($Force -OR (Confirm-Install)){
            $exitCode = Enable-Net40
            if($exitCode -ne 0) {
                Write-Warning ".net install returned $exitCode. You likely need to reboot your computer before proceeding with the install."
                return $false
            }
            $env:ChocolateyInstall = "$env:programdata\chocolatey"
            New-Item $env:ChocolateyInstall -Force -type directory | Out-Null
            $url="http://chocolatey.org/api/v2/package/chocolatey/"
            $wc=new-object net.webclient
            $wp=[system.net.WebProxy]::GetDefaultProxy()
            $wp.UseDefaultCredentials=$true
            $wc.Proxy=$wp
            iex ($wc.DownloadString("http://chocolatey.org/install.ps1"))
            $env:path="$env:path;$env:ChocolateyInstall\bin"
        }
        else{
            return $false
        }
    }
    return $true
}

function Confirm-Install {
    $caption = "Installing Chocolatey"
    $message = "Do you want to proceed?"
    $yes = new-Object System.Management.Automation.Host.ChoiceDescription "&Yes","Yes";
    $no = new-Object System.Management.Automation.Host.ChoiceDescription "&No","No";
    $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes,$no);
    $answer = $host.ui.PromptForChoice($caption,$message,$choices,0)

    switch ($answer){
        0 {return $true; break}
        1 {return $false; break}
    }
}