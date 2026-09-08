; Invoked directly by build_scripts; EXE and ZIP use the same Flutter bundle.
[Setup]
AppId=835d7bbd-85bb-4c73-97f8-ce0740f151a7
AppName=OneXray
AppVersion={#AppVersion}
AppPublisher=YuanDevLLC
AppPublisherURL=https://onexray.com
AppSupportURL=https://github.com/OneXray/OneXray/issues
AppUpdatesURL=https://onexray.com
DefaultDirName={autopf}\OneXray
DisableProgramGroupPage=yes
OutputDir={#OutputDir}
OutputBaseFilename={#OutputBaseFilename}
Compression=lzma2
SolidCompression=yes
SetupIconFile=..\..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\OneXray.exe
WizardStyle=modern
PrivilegesRequired=lowest
ArchitecturesAllowed={#Architecture}
ArchitecturesInstallIn64BitMode={#Architecture}
MinVersion=10.0.19042
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: checkedonce

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\OneXray"; Filename: "{app}\OneXray.exe"; WorkingDir: "{app}"
Name: "{autodesktop}\OneXray"; Filename: "{app}\OneXray.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\onexray"; ValueType: string; ValueName: ""; ValueData: "URL:OneXray Protocol"
Root: HKCU; Subkey: "Software\Classes\onexray"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\onexray\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\OneXray.exe"",0"
Root: HKCU; Subkey: "Software\Classes\onexray\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\OneXray.exe"" ""%1"""

[Run]
Filename: "{app}\OneXray.exe"; Description: "{cm:LaunchProgram,OneXray}"; Flags: nowait postinstall skipifsilent

[Code]
function StartupShortcutTargetsCurrentInstall(const ShortcutPath,
  ExpectedTarget: String): Boolean;
var
  Shell, Shortcut: Variant;
  TargetPath: String;
begin
  Result := False;
  if not FileExists(ShortcutPath) then
    Exit;
  try
    Shell := CreateOleObject('WScript.Shell');
    Shortcut := Shell.CreateShortcut(ShortcutPath);
    TargetPath := Shortcut.TargetPath;
    Result := (TargetPath <> '') and PathSame(TargetPath, ExpectedTarget);
  except
    Log('Unable to inspect the OneXray startup shortcut.');
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  ExpectedTarget, ShortcutPath, CurrentCommand: String;
begin
  if CurUninstallStep <> usUninstall then
    Exit;
  ExpectedTarget := ExpandConstant('{app}\OneXray.exe');
  ShortcutPath := ExpandConstant('{userstartup}\OneXray.lnk');
  if StartupShortcutTargetsCurrentInstall(ShortcutPath, ExpectedTarget) and
     not DeleteFile(ShortcutPath) then
    Log('Unable to remove the OneXray startup shortcut.');
  { Never remove another installation's protocol registration. }
  if RegQueryStringValue(HKCU, 'Software\Classes\onexray\shell\open\command',
      '', CurrentCommand) and
     (CompareText(CurrentCommand, '"' + ExpectedTarget + '" "%1"') = 0) then
    RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\onexray');
end;
