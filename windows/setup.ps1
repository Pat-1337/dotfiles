#Requires -Version 5.1
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`""
    exit
}

function Step($message) { Write-Host "`n==> $message" -ForegroundColor Cyan }

function Quiet([scriptblock]$command) {
    $ErrorActionPreference = 'Continue'
    & $command 2>&1 | Out-Null
}

function Remove-Path($path) {
    if (Test-Path $path) { Remove-Item -Path $path -Recurse -Force -ErrorAction SilentlyContinue }
}

function Remove-Value($path, $name) {
    if (Get-ItemProperty -Path $path -Name $name -ErrorAction SilentlyContinue) {
        Remove-ItemProperty -Path $path -Name $name -Force
    }
}

Step 'Windows 10 context menu'
reg.exe add 'HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32' /f /ve | Out-Null

Step 'OneDrive'
$profileRoot = $env:USERPROFILE
$shellFolders = Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
$redirected = 'Desktop', 'Personal', 'My Pictures', 'My Music', 'My Video' | Where-Object {
    $folder = $shellFolders.$_
    $folder -and [Environment]::ExpandEnvironmentVariables($folder) -like "$profileRoot\OneDrive*"
}

if ($redirected) {
    Write-Warning "OneDrive backs up these folders, so they live inside it: $($redirected -join ', ')."
    Write-Warning 'Stop the backup first: OneDrive settings > Sync and backup > Manage back up. Then run this again.'
}
else {
    Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force

    $installers = @(
        "$env:SystemRoot\System32\OneDriveSetup.exe"
        "$env:SystemRoot\SysWOW64\OneDriveSetup.exe"
        Get-ChildItem "$env:LOCALAPPDATA\Microsoft\OneDrive\*\OneDriveSetup.exe" -ErrorAction SilentlyContinue | ForEach-Object FullName
    ) | Where-Object { $_ -and (Test-Path $_) }
    foreach ($installer in $installers) {
        Start-Process $installer -ArgumentList '/uninstall' -Wait
    }
    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        Quiet { winget.exe uninstall --id Microsoft.OneDrive --exact --silent --accept-source-agreements }
    }

    Get-ScheduledTask -TaskName 'OneDrive*' -ErrorAction SilentlyContinue | Unregister-ScheduledTask -Confirm:$false

    foreach ($dir in "$env:LOCALAPPDATA\Microsoft\OneDrive", "$env:ProgramData\Microsoft OneDrive", "$env:SystemDrive\OneDriveTemp") {
        Remove-Path $dir
    }
    foreach ($dir in Get-ChildItem $profileRoot -Directory -Filter 'OneDrive*' -ErrorAction SilentlyContinue) {
        $files = Get-ChildItem $dir.FullName -File -Force -Recurse -ErrorAction SilentlyContinue | Where-Object Name -ne 'desktop.ini'
        if ($files) {
            Write-Warning "$($dir.FullName) still holds files, so it was kept. Move them out, then delete the folder."
        }
        else {
            Remove-Path $dir.FullName
        }
    }

    $sidebar = '{018D5C66-4533-4307-9B53-224DE2ED1FE6}'
    Remove-Path 'HKCU:\Software\Microsoft\OneDrive'
    Remove-Path "HKCU:\Software\Classes\CLSID\$sidebar"
    Remove-Path "HKCU:\Software\Classes\Wow6432Node\CLSID\$sidebar"
    Remove-Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\$sidebar"
    Remove-Path "HKLM:\SOFTWARE\Classes\CLSID\$sidebar"
    Remove-Path "HKLM:\SOFTWARE\Classes\Wow6432Node\CLSID\$sidebar"
    Remove-Value 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run' 'OneDrive'
    Remove-Value 'HKCU:\Environment' 'OneDrive'
    Remove-Value 'HKCU:\Environment' 'OneDriveConsumer'
    Remove-Value 'HKCU:\Environment' 'OneDriveCommercial'

    $policy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive'
    New-Item -Path $policy -Force | Out-Null
    Set-ItemProperty -Path $policy -Name 'DisableFileSyncNGSC' -Value 1 -Type DWord

    $defaultHive = "$env:SystemDrive\Users\Default\NTUSER.DAT"
    if (Test-Path $defaultHive) {
        Quiet { reg.exe load 'HKU\DefaultUser' $defaultHive }
        Quiet { reg.exe delete 'HKU\DefaultUser\Software\Microsoft\Windows\CurrentVersion\Run' /v OneDriveSetup /f }
        Quiet { reg.exe unload 'HKU\DefaultUser' }
    }
}

Step 'Cloudflare DNS'
$cloudflare = '1.1.1.1', '1.0.0.1', '2606:4700:4700::1111', '2606:4700:4700::1001'
foreach ($adapter in Get-NetAdapter -Physical) {
    $before = (Get-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex).ServerAddresses -join ', '
    Write-Host "  $($adapter.Name) (was: $(if ($before) { $before } else { 'automatic' }))"
    Set-DnsClientServerAddress -InterfaceIndex $adapter.ifIndex -ServerAddresses $cloudflare
}
Clear-DnsClientCache

Step 'Restarting Explorer'
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2
if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }

Write-Host "`nDone. Sign out and back in if the old context menu does not show yet." -ForegroundColor Green
