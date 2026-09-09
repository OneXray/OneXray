; Fastforge renders this template; EXE and ZIP share one Flutter build.
[Setup]
AppId={{APP_ID}}
AppName={{DISPLAY_NAME}}
AppVersion={{APP_VERSION}}
AppPublisher={{PUBLISHER_NAME}}
AppPublisherURL={{PUBLISHER_URL}}
AppSupportURL=https://github.com/OneXray/OneXray/issues
AppUpdatesURL=https://onexray.com
DefaultDirName={{INSTALL_DIR_NAME}}
DisableProgramGroupPage=yes
OutputDir=.
OutputBaseFilename={{OUTPUT_BASE_FILENAME}}
Compression=lzma2
SolidCompression=yes
SetupIconFile={{SETUP_ICON_FILE}}
UninstallDisplayIcon={app}\{{EXECUTABLE_NAME}}
WizardStyle=modern
PrivilegesRequired={{PRIVILEGES_REQUIRED}}
ArchitecturesAllowed={{ARCHITECTURES_ALLOWED}}
ArchitecturesInstallIn64BitMode={{ARCHITECTURES_INSTALL_IN_64BIT_MODE}}
MinVersion=10.0.19042
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: {% if CREATE_DESKTOP_ICON != true %}unchecked{% else %}checkedonce{% endif %}

[Files]
Source: "{{SOURCE_DIR}}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{{DISPLAY_NAME}}"; Filename: "{app}\{{EXECUTABLE_NAME}}"; WorkingDir: "{app}"
Name: "{autodesktop}\{{DISPLAY_NAME}}"; Filename: "{app}\{{EXECUTABLE_NAME}}"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Classes\onexray"; ValueType: string; ValueName: ""; ValueData: "URL:OneXray Protocol"
Root: HKCU; Subkey: "Software\Classes\onexray"; ValueType: string; ValueName: "URL Protocol"; ValueData: ""
Root: HKCU; Subkey: "Software\Classes\onexray\DefaultIcon"; ValueType: string; ValueName: ""; ValueData: """{app}\{{EXECUTABLE_NAME}}"",0"
Root: HKCU; Subkey: "Software\Classes\onexray\shell\open\command"; ValueType: string; ValueName: ""; ValueData: """{app}\{{EXECUTABLE_NAME}}"" ""%1"""

[Run]
Filename: "{app}\{{EXECUTABLE_NAME}}"; Description: "{cm:LaunchProgram,{{DISPLAY_NAME}}}"; Flags: nowait postinstall skipifsilent

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
  ExpectedTarget := ExpandConstant('{app}\{{EXECUTABLE_NAME}}');
  ShortcutPath := ExpandConstant('{userstartup}\{{DISPLAY_NAME}}.lnk');
  if StartupShortcutTargetsCurrentInstall(ShortcutPath, ExpectedTarget) and
     not DeleteFile(ShortcutPath) then
    Log('Unable to remove the OneXray startup shortcut.');
  { Never remove another installation's protocol registration. }
  if RegQueryStringValue(HKCU, 'Software\Classes\onexray\shell\open\command',
      '', CurrentCommand) and
     (CompareText(CurrentCommand, '"' + ExpectedTarget + '" "%1"') = 0) then
    RegDeleteKeyIncludingSubkeys(HKCU, 'Software\Classes\onexray');
end;
