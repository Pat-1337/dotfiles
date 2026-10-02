# Windows

`windows/setup.ps1` makes a few tweaks. It does not do what `setup.sh` does.

```powershell
powershell -ExecutionPolicy Bypass -File windows\setup.ps1
```

It asks for administrator rights and starts again elevated. Run it from your
own account: the elevated copy changes the `HKCU` keys of the account that
approves the prompt.

## Context menu

The Windows 10 right-click menu comes back through an empty
`InprocServer32` key under CLSID `{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}` in
`HKCU`. Explorer restarts at the end. If the old menu does not show, sign out
and back in. To undo:

```powershell
reg delete "HKCU\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}" /f
```

## OneDrive

- If OneDrive backs up Desktop, Documents, Pictures, Music, or Videos, those
  folders live inside it, and deleting it could delete your files. The script
  then skips OneDrive and says which folders to stop backing up first.
- Otherwise it stops OneDrive and runs every `OneDriveSetup.exe /uninstall`
  it finds, then `winget uninstall Microsoft.OneDrive`.
- It removes the OneDrive scheduled tasks and the program and cache folders.
- It deletes `~\OneDrive*` only when the folder holds no files besides
  `desktop.ini`. Otherwise it keeps the folder and says so. Files that were
  online-only are still on onedrive.com.
- Registry: `HKCU\Software\Microsoft\OneDrive`, the Explorer sidebar entry
  (`{018D5C66-4533-4307-9B53-224DE2ED1FE6}` in `HKCU` and `HKLM`), the `Run`
  entry, and the `OneDrive*` environment variables.
- New accounts: the `OneDriveSetup` entry in the default user's `Run` key.
- Policy `DisableFileSyncNGSC = 1` under
  `HKLM\SOFTWARE\Policies\Microsoft\Windows\OneDrive` keeps Windows from
  bringing OneDrive back. Delete that value to allow OneDrive again.

## DNS

Every physical adapter, connected or not, gets `1.1.1.1`, `1.0.0.1`,
`2606:4700:4700::1111`, and `2606:4700:4700::1001`. VPN and virtual adapters
are left alone. The old servers are printed first. To undo on one adapter:

```powershell
Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses
```

## Activation

Not included. With a license, run `slmgr /ipk <key>` and then `slmgr /ato`, or
sign in with the Microsoft account that holds the license.
