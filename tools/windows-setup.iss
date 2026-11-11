; ComfyUI Diagnostics - unsigned Windows LAB bootstrap installer.
; The verified PowerShell installer is the only code allowed to mutate program files.
#ifndef SourceRoot
  #error SourceRoot is required: /DSourceRoot=<validated package staging directory>
#endif

[Setup]
AppId={{6E6E095C-25FA-486E-A00D-3C9A2D6AF0EA}
AppName=ComfyUI Diagnostics Monitor
AppVersion=0.8.0
AppVerName=ComfyUI Diagnostics Monitor v0.8 LAB CANDIDATE
AppPublisher=OVizLAB
DefaultDirName={localappdata}\Programs\ComfyUI-Diagnostics
CreateAppDir=no
DisableDirPage=yes
DisableProgramGroupPage=yes
Uninstallable=no
PrivilegesRequired=lowest
WizardStyle=modern
OutputBaseFilename=ComfyUI-Diagnostics-Setup-v0.8-LAB
Compression=lzma2
SolidCompression=yes
ArchitecturesAllowed=x64
MinVersion=10.0.17763
SetupIconFile=
DisableWelcomePage=no

[Files]
Source: "{#SourceRoot}\*"; DestDir: "{tmp}\ComfyUI-Diagnostics-LAB"; Flags: ignoreversion recursesubdirs createallsubdirs

[Code]
var
  MachinePage: TInputOptionWizardPage;

procedure InitializeWizard;
begin
  MachinePage := CreateInputOptionPage(
    wpWelcome,
    'Choose computer',
    'Select the machine profile for this installation',
    'The profile is stored locally. This installer does not modify drivers, models or ComfyUI.',
    True, False);
  MachinePage.Add('HOME  - RTX 3070 Ti');
  MachinePage.Add('WORK  - RTX 4090');
  MachinePage.SelectedValueIndex := 0;
end;

function MachineName: String;
begin
  if MachinePage.SelectedValueIndex = 1 then Result := 'WORK'
  else Result := 'HOME';
end;

procedure CurStepChanged(CurStep: TSetupStep);
var
  ExitCode: Integer;
  Executable: String;
  Args: String;
begin
  if CurStep <> ssPostInstall then Exit;
  Executable := ExpandConstant('{sys}\WindowsPowerShell\v1.0\powershell.exe');
  Args := '-NoProfile -STA -ExecutionPolicy Bypass -File "' +
    ExpandConstant('{tmp}\ComfyUI-Diagnostics-LAB\install.ps1') +
    '" -Machine ' + MachineName + ' -Upgrade';
  if not Exec(Executable, Args, '', SW_SHOW, ewWaitUntilTerminated, ExitCode) then
    RaiseException('Installer could not launch PowerShell.');
  if ExitCode <> 0 then
    RaiseException('Installation failed (exit code ' + IntToStr(ExitCode) + '). Diagnostic data were not removed.');
end;
