; Windows installer for Carthage (Inno Setup 6). Built by packaging/build_windows.ps1 from
; the PyInstaller folder dist\Carthage:
;   iscc /DAppVersion=0.2.0 packaging\carthage.iss   →   dist\Carthage-0.2.0-setup.exe
;
; Installs for the current user only (no admin prompt), like most game launchers. Bare
; minimum on screen: no welcome, license, folder, shortcut or "ready" pages — it installs
; straight away and ends on "Launch Carthage". Installing over an older version updates it in
; place (same AppId, same folder); settings and keys live outside the app folder, so they stay.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppId={{6C1E9B0A-4F3D-4C2B-9A57-C4A7A1E0D2F1}
AppName=Carthage
AppVersion={#AppVersion}
AppPublisher=lopiksa
AppPublisherURL=https://github.com/lopiksaa/carthage
DefaultDirName={localappdata}\Programs\Carthage
DefaultGroupName=Carthage
DisableProgramGroupPage=yes
DisableWelcomePage=yes
DisableDirPage=yes
DisableReadyPage=yes
PrivilegesRequired=lowest
OutputDir=..\dist
OutputBaseFilename=Carthage-{#AppVersion}-setup
SetupIconFile=carthage.ico
UninstallDisplayIcon={app}\Carthage.exe
UninstallDisplayName=Carthage
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Qt 6.11 needs 64-bit Windows 10 1809 or later. Everything else ships inside the app:
; its own Visual C++ runtime, the Universal CRT and a software OpenGL fallback.
MinVersion=10.0.17763
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
CloseApplications=force
RestartApplications=no

[Files]
Source: "..\dist\Carthage\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[InstallDelete]
; An update replaces the whole bundle, so files dropped from a newer build don't linger.
Type: filesandordirs; Name: "{app}\_internal"

[Icons]
; Same AppUserModelID as app.py sets, so a pinned taskbar icon and the running window match.
Name: "{autoprograms}\Carthage"; Filename: "{app}\Carthage.exe"; AppUserModelID: "lopiksa.Carthage"

[Run]
Filename: "{app}\Carthage.exe"; Description: "{cm:LaunchProgram,Carthage}"; Flags: nowait postinstall skipifsilent
; Carthage's own update ("Restart Now") runs this installer silently with /RELAUNCH: open it again.
Filename: "{app}\Carthage.exe"; Flags: nowait skipifnotsilent; Check: WantsRelaunch

[Messages]
WinVersionTooLowError=Carthage needs 64-bit Windows 10 (version 1809) or later.

[Code]
function WantsRelaunch(): Boolean;
begin
  Result := Pos('/RELAUNCH', Uppercase(GetCmdTail)) > 0;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  // The app can't start without these; a broken copy is better caught here than at launch.
  if (CurStep = ssPostInstall) and not (FileExists(ExpandConstant('{app}\Carthage.exe'))
      and FileExists(ExpandConstant('{app}\_internal\PySide6\Qt6Core.dll'))
      and DirExists(ExpandConstant('{app}\_internal\carthage\qml'))) then
    MsgBox('Some of Carthage''s files are missing after installing. Please download the installer again.',
           mbError, MB_OK);
end;
