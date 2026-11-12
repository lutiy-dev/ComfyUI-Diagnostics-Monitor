# ComfyUI Diagnostics v0.9 LAB: single-window WPF shell, local read-only telemetry.
# The existing collector/evidence engines are reused without altering ComfyUI or 3ds Max.
[CmdletBinding()]
param(
 [ValidateSet('HOME','WORK')][string]$Machine='HOME',
 [string]$DataDir=(Join-Path $env:LOCALAPPDATA 'ComfyUI-Diagnostics'),
 [string]$ComfyLog='',
 [string]$ComfyUrl='http://127.0.0.1:8188',
 [switch]$SelfTest
)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName PresentationFramework,PresentationCore,WindowsBase,System.Xaml
. (Join-Path $PSScriptRoot 'lib\ComfyWs.ps1')
. (Join-Path $PSScriptRoot 'lib\Updates.ps1')
$uri=[uri]$ComfyUrl
if ($uri.Scheme -ne 'http' -or $uri.Host -notin @('127.0.0.1','localhost','::1') -or $uri.UserInfo) {
 throw 'STOP: ComfyUI must use unauthenticated localhost HTTP'
}
$null=New-Item -Path $DataDir -ItemType Directory -Force
$xamlPath=Join-Path $PSScriptRoot 'ui\ControlCenter.xaml'
if (-not (Test-Path -LiteralPath $xamlPath -PathType Leaf)) { throw 'STOP: missing WPF interface XAML' }
$reader=[Xml.XmlReader]::Create($xamlPath)
try { $window=[Windows.Markup.XamlReader]::Load($reader) } finally { $reader.Dispose() }
$names=@('BrandTitle','BrandSubtitle','MachineBadge','CollectorBadge','MainTabs','MonitorTab','GenerationsTab','EvidenceTab','SettingsTab',
 'OverviewLabel','SourceStatus','GpuValue','VramValue','CpuValue','RamValue','GpuBar','VramBar','CpuBar','RamBar',
 'HistoryLabel','HistoryHint','GpuLine','VramLine','CpuLine','RamLine','AppsLabel','ComfyState','MaxState','MemoryDetail',
 'RecentIncidentsLabel','IncidentsList','GenerationTitle','GenerationState','GenerationTime','GenerationNode','GenerationBar','GenerationProgress',
 'GenerationNote','GenerationHistoryTitle','GenerationEvents','GenerationResultsTitle','GenerationPrivacy','OpenComfyButton',
 'EvidenceTitle','EvidenceHint','EvidenceHoursLabel','EvidenceHours','EvidenceWindows','EvidenceProcesses','EvidenceStorage',
 'EvidenceComfy','EvidenceRaw','CaptureEvidenceButton','OpenEvidenceButton','OpenLogsButton','EvidenceStatus',
 'SettingsTitle','LanguageLabel','LanguageSelect','MachineLabel','SettingsMachineValue','SettingsSafety','CheckUpdatesButton',
 'UpdatesStatus','FooterLeft','FooterRight')
$script:ui=@{}
foreach($name in $names) {
 $control=$window.FindName($name)
 if($null -eq $control){ throw "STOP: required control absent: $name" }
 $script:ui[$name]=$control
}
$script:ui.MachineBadge.Text=$Machine
$script:ui.SettingsMachineValue.Text=$Machine
$script:ui.FooterRight.Text="v0.9 LAB · $Machine"
$script:configPath=Join-Path $DataDir 'ui-settings.json'
$script:lang='ru'
if(Test-Path -LiteralPath $script:configPath -PathType Leaf){
 try {
  $prefs=Get-Content -LiteralPath $script:configPath -Raw -ErrorAction Stop | ConvertFrom-Json
  if($prefs.language -in @('ru','en')){$script:lang=[string]$prefs.language}
 } catch { Write-Warning 'UI language settings invalid; using Russian' }
}
$script:strings=@{
 ru=@{
  MonitorTab='Монитор'; GenerationsTab='Генерации'; EvidenceTab='Диагностика'; SettingsTab='Настройки'
  OverviewLabel='Обзор системы'; HistoryLabel='История ресурсов'; HistoryHint='Последние 120 записей · GPU / VRAM / CPU / RAM'
  AppsLabel='Приложения';RecentIncidentsLabel='Последние события';GenerationTitle='Текущая генерация'
  GenerationHistoryTitle='История событий';GenerationResultsTitle='Результаты / промпты'
  GenerationPrivacy='Для защиты личных данных промпты и изображения не собираются автоматически. В v0.9 доступна нормализованная история событий.'
  GenerationNote='Прогресс отображается только при наличии достоверных данных WebSocket. ETA не рассчитывается без статистики.'
  OpenComfyButton='Открыть ComfyUI (localhost)'
  EvidenceTitle='Центр диагностики';EvidenceHint='Отчёт создаётся локально и не отправляется в облако.'
  EvidenceHoursLabel='Период событий (часы)';EvidenceWindows='События Windows / WER';EvidenceProcesses='Процессы и память'
  EvidenceStorage='Диски и свободное место';EvidenceComfy='ComfyUI API и сигнатуры логов'
  EvidenceRaw='Включить приватный RAW-лог (только с подтверждением)'
  CaptureEvidenceButton='Собрать отчёт';OpenEvidenceButton='Папка отчётов';OpenLogsButton='Папка логов'
  SettingsTitle='Настройки приложения';LanguageLabel='Язык интерфейса';MachineLabel='Профиль компьютера'
  SettingsSafety='Монитор запускает один скрытый Collector. Данные остаются на компьютере. Никаких драйверов, моделей, проектов и настроек Windows он не изменяет.'
  CheckUpdatesButton='Проверить обновления'
  FooterLeft='ЛОКАЛЬНО · ДАННЫЕ НЕ ОТПРАВЛЯЮТСЯ'
  offline='Не подключён';notrunning='Не запущен';nodata='Нет данных';collectactive='СБОР: АКТИВЕН';collectwaiting='СБОР: ОЖИДАНИЕ'
  genidle='Ожидание ComfyUI';genrunning='Генерация';genfinished='Завершено';generror='Ошибка';node='Активная нода'
  steps='Шаги';ready='Ожидание команды';capturing='Создаётся локальный отчёт…';updatefound='Доступна новая версия'
  updateidle='Проверка новых версий через GitHub Release';updateunavailable='Сведения о релизах недоступны'
  }
 en=@{
  MonitorTab='Monitor';GenerationsTab='Generations';EvidenceTab='Diagnostics';SettingsTab='Settings'
  OverviewLabel='System overview';HistoryLabel='Resource history';HistoryHint='Last 120 samples · GPU / VRAM / CPU / RAM'
  AppsLabel='Applications';RecentIncidentsLabel='Recent incidents';GenerationTitle='Current generation'
  GenerationHistoryTitle='Event history';GenerationResultsTitle='Results / prompts'
  GenerationPrivacy='For privacy, prompts and images are not collected automatically. v0.9 shows normalized event history.'
  GenerationNote='Progress is shown only when reliable WebSocket data is available. No estimated ETA without history.'
  OpenComfyButton='Open ComfyUI (localhost)'
  EvidenceTitle='Diagnostics center';EvidenceHint='Evidence stays on this computer; there is no automatic upload.'
  EvidenceHoursLabel='Event window (hours)';EvidenceWindows='Windows Events / WER';EvidenceProcesses='Processes and memory'
  EvidenceStorage='Storage capacity';EvidenceComfy='ComfyUI API and log signatures'
  EvidenceRaw='Include private RAW log (requires confirmation)'
  CaptureEvidenceButton='Capture evidence';OpenEvidenceButton='Evidence folder';OpenLogsButton='Logs folder'
  SettingsTitle='Application settings';LanguageLabel='Interface language';MachineLabel='Computer profile'
  SettingsSafety='One hidden Collector is launched with the application. All data stays local. No drivers, models, projects or Windows configuration are modified.'
  CheckUpdatesButton='Check for updates'
  FooterLeft='LOCAL · NO DATA UPLOAD'
  offline='Offline';notrunning='Not running';nodata='No data';collectactive='COLLECTOR: ACTIVE';collectwaiting='COLLECTOR: WAITING'
  genidle='Waiting for ComfyUI';genrunning='Generating';genfinished='Completed';generror='Error';node='Active node'
  steps='Steps';ready='Ready';capturing='Capturing local evidence…';updatefound='Update available'
  updateidle='Check for official GitHub releases';updateunavailable='Release information unavailable'
 }
}
function S([string]$key){ return [string]$script:strings[$script:lang][$key] }
function Apply-Language {
 foreach($key in @($script:strings.ru.Keys)) {
  if($key -notin $script:ui.Keys){ continue }
  $item=$script:ui[$key]
  $property=if($item -is [System.Windows.Controls.TabItem]){'Header'}
            elseif($item -is [System.Windows.Controls.Button] -or $item -is [System.Windows.Controls.CheckBox]){'Content'}
            else{'Text'}
  $item.$property=S $key
 }
 $script:ui.LanguageSelect.SelectedIndex=if($script:lang -eq 'ru'){0}else{1}
}
Apply-Language
$script:ui.LanguageSelect.Add_SelectionChanged({
 $wanted=if($script:ui.LanguageSelect.SelectedIndex -eq 1){'en'}else{'ru'}
 if($wanted -eq $script:lang){return}
 $script:lang=$wanted
 $out=@{schema=1;language=$script:lang}|ConvertTo-Json -Compress
 [IO.File]::WriteAllText($script:configPath,$out,[Text.UTF8Encoding]::new($false))
 Apply-Language
})
function To-Number($v){
 if($null -eq $v){return $null}
 [double]$number=0
 if([double]::TryParse([string]$v,[Globalization.NumberStyles]::Float,[Globalization.CultureInfo]::InvariantCulture,[ref]$number)){return $number}
 return $null
}
function Set-Gauge([string]$name,$value,[string]$format='{0:0}%'){
 if($null -eq $value) {
  $script:ui[($name+'Value')].Text='—'
  $script:ui[($name+'Bar')].Value=0
 } else {
  $v=[math]::Max(0,[math]::Min(100,[double]$value))
  $script:ui[($name+'Value')].Text=($format -f [double]$value)
  $script:ui[($name+'Bar')].Value=$v
 }
}
function Refresh-Graph($samples){
 foreach($pair in @(@('Gpu','gpu'),@('Vram','vram'),@('Cpu','cpu'),@('Ram','ram'))){
  $points=New-Object System.Windows.Media.PointCollection
  $count=$samples.Count
  if($count -gt 0){
   for($i=0;$i -lt $count;$i++){
    $sample=$samples[$i]
    $v=$null
    switch($pair[1]){
     gpu {
      if($sample.gpu.status -eq 'OK' -and @($sample.gpu.gpus).Count -gt 0){$v=To-Number $sample.gpu.gpus[0].util_pct}
     }
     vram {
      if($sample.gpu.status -eq 'OK' -and @($sample.gpu.gpus).Count -gt 0){
       $g=$sample.gpu.gpus[0];$used=To-Number $g.vram_used_mib;$total=To-Number $g.vram_total_mib
       if($null -ne $used -and $total -gt 0){$v=100*$used/$total}
      }
     }
     cpu {if($sample.cpu.status -eq 'OK'){$v=To-Number $sample.cpu.util_pct}}
     ram {
      $used=To-Number $sample.ram.used_mib;$total=To-Number $sample.ram.total_mib
      if($null -ne $used -and $total -gt 0){$v=100*$used/$total}
     }
    }
    if($null -ne $v){
     $x=if($count -gt 1){940*$i/($count-1)}else{0}
     $y=162-([math]::Min(100,[math]::Max(0,$v))*1.58)
     $points.Add([Windows.Point]::new([double]$x,[double]$y))
    }
   }
  }
  $script:ui[($pair[0]+'Line')].Points=$points
 }
}
$script:lastTelemetry=''
function Refresh-Telemetry {
 $paths=@(Get-ChildItem -LiteralPath $DataDir -Filter ('telemetry_'+$Machine+'_*.jsonl') -File -ErrorAction SilentlyContinue|
  Sort-Object LastWriteTimeUtc -Descending)
 if($paths.Count -eq 0){
  $script:ui.CollectorBadge.Text=S 'collectwaiting'
  return
 }
 $data=@()
 foreach($line in @(Get-Content -LiteralPath $paths[0].FullName -Tail 120 -ErrorAction SilentlyContinue)){
  try{$data+=ConvertFrom-Json -InputObject $line -ErrorAction Stop}catch{}
 }
 if($data.Count -eq 0){return}
 $sample=$data[-1]
 $stale=$true
 try{$stale=(([datetime]::UtcNow-[datetime]::Parse([string]$sample.timestamp_utc).ToUniversalTime()).TotalSeconds -gt 20)}catch{}
 $script:ui.CollectorBadge.Text=if($stale){'СБОР: STALE'}else{S 'collectactive'}
 $script:ui.CollectorBadge.Foreground=if($stale){[Windows.Media.Brushes]::Orange}else{[Windows.Media.Brushes]::LightGreen}
 $g=$null
 if($sample.gpu.status -eq 'OK' -and @($sample.gpu.gpus).Count -gt 0){$g=$sample.gpu.gpus[0]}
 $gPct=if($null -ne $g){To-Number $g.util_pct}else{$null}
 $vPct=$null
 if($null -ne $g){
  $used=To-Number $g.vram_used_mib;$total=To-Number $g.vram_total_mib
  if($null -ne $used -and $total -gt 0){$vPct=100*$used/$total}
 }
 Set-Gauge 'Gpu' $gPct
 Set-Gauge 'Vram' $vPct '{0:0.0}%'
 $cpuPct=if($sample.cpu.status -eq 'OK'){To-Number $sample.cpu.util_pct}else{$null}
 Set-Gauge 'Cpu' $cpuPct '{0:0.0}%'
 $ramUsed=To-Number $sample.ram.used_mib;$ramTotal=To-Number $sample.ram.total_mib
 $ramPct=if($null -ne $ramUsed -and $ramTotal -gt 0){100*$ramUsed/$ramTotal}else{$null}
 Set-Gauge 'Ram' $ramPct '{0:0.0}%'
 $max=if($sample.max_memory.status -eq 'OK'){
  $m=To-Number $sample.max_memory.working_set_mib
  if($null -ne $m){('{0:0.0} GiB' -f ($m/1024))}else{'—'}
 }elseif($sample.max_memory.status -eq 'NOT_RUNNING'){S 'notrunning'}else{S 'nodata'}
 $script:ui.MaxState.Text='3ds Max: '+$max
 $script:ui.ComfyState.Text='ComfyUI: '+$(if($sample.comfy.status -eq 'ONLINE'){'ONLINE'}else{S 'offline'})
 $script:ui.MemoryDetail.Text=if($null -ne $ramPct){('RAM {0:0.1} / {1:0.1} GiB' -f ($ramUsed/1024),($ramTotal/1024))}else{S 'nodata'}
 $script:ui.SourceStatus.Text=('GPU: {0}  ·  ComfyUI: {1}' -f $(if($null -ne $g){'OK'}else{'NO DATA'}),[string]$sample.comfy.status)
 Refresh-Graph $data
 $events=@()
 $eventFiles=@(Get-ChildItem -LiteralPath $DataDir -Filter ('events_'+$Machine+'_*.jsonl') -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 2)
 foreach($file in $eventFiles){
  foreach($line in @(Get-Content -LiteralPath $file.FullName -Tail 18 -ErrorAction SilentlyContinue)){
   try{
    $e=ConvertFrom-Json $line
    $events+=([pscustomobject]@{time=[string]$e.event_utc;label=([string]$e.provider+' / '+[string]$e.code)})
   }catch{}
  }
 }
 $script:ui.IncidentsList.Items.Clear()
 foreach($e in @($events|Sort-Object time -Descending|Select-Object -First 7)){
  [void]$script:ui.IncidentsList.Items.Add(($e.time+' · '+$e.label))
 }
}
$script:ws=$null
$script:wsTask=$null
$script:wsReceive=$null
$script:wsCts=$null
$script:wsBuffer=New-Object byte[] 65536
$script:wsMessage=New-Object IO.MemoryStream
$script:wsSkip=$false
$script:wsLast=[datetime]::MinValue
$script:activeNode='-'
$script:step=0
$script:total=0
$script:session='Idle'
$script:sessionStart=$null
$script:queue=$null
function Close-Ws {
 if($null -ne $script:wsCts){try{$script:wsCts.Cancel()}catch{};try{$script:wsCts.Dispose()}catch{}}
 if($null -ne $script:ws){try{$script:ws.Abort()}catch{};try{$script:ws.Dispose()}catch{}}
 $script:wsCts=$null;$script:ws=$null;$script:wsTask=$null;$script:wsReceive=$null
 $script:wsMessage.SetLength(0);$script:wsSkip=$false
}
function Record-Event($ev) {
 $record=[ordered]@{
  schema=1;machine=$Machine;source='ComfyUI';time_utc=[DateTime]::UtcNow.ToString('o')
  type=$ev.type;node=$ev.node;prompt_id=$ev.prompt_id;current=$ev.current;total=$ev.total
  error_code=$ev.error_code;queue_remaining=$ev.queue_remaining
 }
 $path=Join-Path $DataDir ('live_'+$Machine+'_'+(Get-Date -Format yyyyMMdd)+'.jsonl')
 if((Test-Path -LiteralPath $path) -and (Get-Item -LiteralPath $path).Length -ge 5MB){return}
 [IO.File]::AppendAllText($path,((ConvertTo-Json $record -Compress -Depth 4)+[Environment]::NewLine),[Text.UTF8Encoding]::new($false))
}
function Handle-Event($ev) {
 if($null -eq $ev){return}
 switch($ev.type){
  'execution_start' {$script:session='Running';$script:sessionStart=Get-Date;$script:step=0;$script:total=0;$script:activeNode='-'}
  'executing' {
   if([string]::IsNullOrEmpty($ev.node)){$script:session='Idle';$script:activeNode='-'}
   else {$script:session='Running';$script:activeNode=$ev.node}
   $script:step=0;$script:total=0
  }
  'progress' {$script:step=$ev.current;$script:total=$ev.total;$script:session='Running'}
  'execution_success' {$script:session='Completed';$script:activeNode='-'}
  'execution_error' {$script:session='ERROR';$script:activeNode='-'}
  'execution_interrupted' {$script:session='Interrupted';$script:activeNode='-'}
  'status' {$script:queue=$ev.queue_remaining}
 }
 if($ev.type -ne 'status' -or $null -ne $ev.queue_remaining){Record-Event $ev}
}
function Poll-Ws {
 if($null -eq $script:ws){
  if(((Get-Date)-$script:wsLast).TotalSeconds -lt 6){return}
  $script:wsLast=Get-Date
  try{
   $script:ws=[Net.WebSockets.ClientWebSocket]::new()
   $script:wsCts=[Threading.CancellationTokenSource]::new([TimeSpan]::FromSeconds(3))
   $endpoint='ws://'+$uri.Authority+'/ws?clientId='+[guid]::NewGuid().ToString()
   $script:wsTask=$script:ws.ConnectAsync([uri]$endpoint,$script:wsCts.Token)
  }catch{Close-Ws}
  return
 }
 if($null -ne $script:wsTask){
  if(-not $script:wsTask.IsCompleted){return}
  try{
   $script:wsTask.GetAwaiter().GetResult()
   $script:wsTask=$null
   $script:wsCts.Dispose();$script:wsCts=$null
  }catch{Close-Ws;return}
 }
 if($script:ws.State -ne [Net.WebSockets.WebSocketState]::Open){Close-Ws;return}
 if($null -eq $script:wsReceive){
  try{$script:wsReceive=$script:ws.ReceiveAsync([ArraySegment[byte]]::new($script:wsBuffer),[Threading.CancellationToken]::None)}catch{Close-Ws}
  return
 }
 if(-not $script:wsReceive.IsCompleted){return}
 try{
  $r=$script:wsReceive.GetAwaiter().GetResult()
  $script:wsReceive=$null
  if($r.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Close){Close-Ws;return}
  if($r.MessageType -eq [Net.WebSockets.WebSocketMessageType]::Binary){$script:wsSkip=$true}
  if(-not $script:wsSkip -and $r.Count -gt 0){
   if(($script:wsMessage.Length+$r.Count) -gt 131072){$script:wsSkip=$true}
   else{$script:wsMessage.Write($script:wsBuffer,0,$r.Count)}
  }
  if($r.EndOfMessage){
   if(-not $script:wsSkip){
    $json=[Text.Encoding]::UTF8.GetString($script:wsMessage.ToArray())
    Handle-Event (ConvertFrom-ComfyWsEvent -Json $json)
   }
   $script:wsMessage.SetLength(0);$script:wsSkip=$false
  }
 }catch{Close-Ws}
}
function Refresh-Generation {
 $state=switch($script:session){
  'Running' {S 'genrunning'}
  'Completed' {S 'genfinished'}
  'ERROR' {S 'generror'}
  default {S 'genidle'}
 }
 $script:ui.GenerationState.Text=$state
 $script:ui.GenerationNode.Text=(S 'node')+': '+$script:activeNode
 if($null -ne $script:sessionStart){
  $elapsed=(Get-Date)-$script:sessionStart
  $script:ui.GenerationTime.Text=('{0:00}:{1:00}' -f [math]::Floor($elapsed.TotalMinutes),$elapsed.Seconds)
 }else{$script:ui.GenerationTime.Text='--:--'}
 $pct=if($script:total -gt 0){[math]::Min(100,[math]::Max(0,100*$script:step/$script:total))}else{0}
 $script:ui.GenerationBar.Value=$pct
 $script:ui.GenerationProgress.Text=(S 'steps')+': '+$(if($script:total -gt 0){"$($script:step)/$($script:total) · $([math]::Round($pct,1))%"}else{'—'})
 $script:ui.GenerationEvents.Items.Clear()
 $files=@(Get-ChildItem -LiteralPath $DataDir -Filter ('live_'+$Machine+'_*.jsonl') -ErrorAction SilentlyContinue|Sort-Object LastWriteTime -Descending|Select-Object -First 2)
 $items=@()
 foreach($file in $files){
  foreach($line in @(Get-Content -LiteralPath $file.FullName -Tail 25 -ErrorAction SilentlyContinue)){
   try{
    $e=ConvertFrom-Json $line
    if($e.type -notin @('execution_start','execution_success','execution_error','execution_interrupted','executing')){continue}
    $items+=([pscustomobject]@{time=[string]$e.time_utc;text=([string]$e.type+' · '+[string]$e.node)})
   }catch{}
  }
 }
 foreach($item in @($items|Sort-Object time -Descending|Select-Object -First 14)){
  [void]$script:ui.GenerationEvents.Items.Add(($item.time+'  '+$item.text))
 }
}
function Open-Folder([string]$path){
 if(-not (Test-Path -LiteralPath $path -PathType Container)){$null=New-Item -Path $path -ItemType Directory -Force}
 [void][Diagnostics.Process]::Start('explorer.exe',('"'+$path+'"'))
}
$script:ui.OpenLogsButton.Add_Click({Open-Folder $DataDir})
$script:ui.OpenEvidenceButton.Add_Click({Open-Folder (Join-Path $DataDir 'evidence')})
$script:ui.OpenComfyButton.Add_Click({[void][Diagnostics.Process]::Start($ComfyUrl)})
$script:evidenceJob=$null
$script:ui.CaptureEvidenceButton.Add_Click({
 if($null -ne $script:evidenceJob){return}
 if($script:ui.EvidenceRaw.IsChecked){
  $ans=[Windows.MessageBox]::Show(
   'RAW ComfyUI log may contain private prompts, filenames and secrets. Save locally only?',
   'Private evidence confirmation','YesNo','Warning')
  if($ans -ne [Windows.MessageBoxResult]::Yes){return}
 }
 $script:ui.CaptureEvidenceButton.IsEnabled=$false
 $script:ui.EvidenceStatus.Text=S 'capturing'
 $hrs=[int]$script:ui.EvidenceHours.SelectedItem.Content
 $args=@{
  Machine=$Machine;DataRoot=$DataDir;ComfyLog=$ComfyLog;Hours=$hrs
  SkipWindows=(-not [bool]$script:ui.EvidenceWindows.IsChecked)
  SkipProcesses=(-not [bool]$script:ui.EvidenceProcesses.IsChecked)
  SkipStorage=(-not [bool]$script:ui.EvidenceStorage.IsChecked)
  SkipComfy=(-not [bool]$script:ui.EvidenceComfy.IsChecked)
  ArchiveComfyLog=[bool]$script:ui.EvidenceRaw.IsChecked
 }
 $script:evidenceJob=Start-Job -ScriptBlock{
  param($path,$arguments)
  $ErrorActionPreference='Stop'
  & $path @arguments
 } -ArgumentList (Join-Path $PSScriptRoot 'evidence.ps1'),$args
})
$script:updateJob=$null
$script:updateAvailable=$null
function Start-Updates {
 if($null -ne $script:updateJob){return}
 $v='0.9.0-LAB-CANDIDATE'
 $manifest=Join-Path $PSScriptRoot 'installation.json'
 if(Test-Path -LiteralPath $manifest){
  try{$v=[string](Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json).version}catch{}
 }
 $script:updateJob=Start-Job -ScriptBlock{
  param($file,$version)
  . $file
  Get-DiagnosticsReleaseStatus -CurrentVersion $version
 } -ArgumentList (Join-Path $PSScriptRoot 'lib\Updates.ps1'),$v
 $script:ui.UpdatesStatus.Text=S 'updateidle'
}
$script:ui.CheckUpdatesButton.Add_Click({
 if($script:updateAvailable -and $script:updateAvailable.url){
  $ans=[Windows.MessageBox]::Show('Open official GitHub release page? No automatic download or installation.',
   'ComfyUI Diagnostics','YesNo','Information')
  if($ans -eq [Windows.MessageBoxResult]::Yes){[void][Diagnostics.Process]::Start([string]$script:updateAvailable.url)}
 }else{Start-Updates}
})
$script:ui.EvidenceStatus.Text=S 'ready'
$script:ui.UpdatesStatus.Text=S 'updateidle'
if($SelfTest){
 if($script:ui.MainTabs.Items.Count -ne 4 -or $script:lang -notin @('ru','en')){throw 'FAIL: WPF control center invalid tabs / settings'}
 $window.Close()
 Write-Host 'PASS: v0.9 WPF control center loaded; 4 tabs and RU/EN settings ready'
 return
}
# Single visible application instance per Windows user/profile (explicit profile namespace).
$mutexName='Local\ComfyUIDiagnosticsControlCenter_'+$Machine
$script:uiMutex=New-Object Threading.Mutex($false,$mutexName)
$gotMutex=$false
try{$gotMutex=$script:uiMutex.WaitOne(0,$false)}catch{}
if(-not $gotMutex){
 $script:uiMutex.Dispose()
 [void][Windows.MessageBox]::Show('Diagnostics Monitor is already open for this profile.','Diagnostics Monitor')
 return
}
$script:collectorChild=$null
$script:timer=New-Object Windows.Threading.DispatcherTimer
$script:timer.Interval=[TimeSpan]::FromSeconds(2)
$script:timer.Add_Tick({
 try{
  Refresh-Telemetry
  Poll-Ws
  Refresh-Generation
  if($null -ne $script:evidenceJob -and $script:evidenceJob.State -in @('Completed','Failed','Stopped')){
   $message=if($script:evidenceJob.State -eq 'Completed'){'PASS: saved locally'}else{'FAIL: evidence job did not complete'}
   try{Receive-Job -Job $script:evidenceJob -ErrorAction Stop|Out-Null}catch{$message='FAIL: '+$_.Exception.Message}
   $script:ui.EvidenceStatus.Text=$message
   Remove-Job -Job $script:evidenceJob -Force -ErrorAction SilentlyContinue
   $script:evidenceJob=$null
   $script:ui.CaptureEvidenceButton.IsEnabled=$true
  }
  if($null -ne $script:updateJob -and $script:updateJob.State -in @('Completed','Failed','Stopped')){
   try{
    $response=Receive-Job -Job $script:updateJob -ErrorAction SilentlyContinue
    if($response.status -eq 'UPDATE_AVAILABLE'){
     $script:updateAvailable=$response
     $script:ui.UpdatesStatus.Text=(S 'updatefound')+': '+[string]$response.version
     $script:ui.CheckUpdatesButton.Content=S 'updatefound'
    }else{$script:ui.UpdatesStatus.Text=S 'updateunavailable'}
   }finally{
    Remove-Job -Job $script:updateJob -Force -ErrorAction SilentlyContinue
    $script:updateJob=$null
   }
  }
 }catch{
  $script:ui.SourceStatus.Text='UI WARNING: '+$_.Exception.GetType().Name
 }
})
$window.Add_Closed({
 $script:timer.Stop()
 Close-Ws
 $script:wsMessage.Dispose()
 if($null -ne $script:updateJob){Remove-Job -Job $script:updateJob -Force -ErrorAction SilentlyContinue}
 if($null -ne $script:evidenceJob){Remove-Job -Job $script:evidenceJob -Force -ErrorAction SilentlyContinue}
 if($null -ne $script:collectorChild -and -not $script:collectorChild.HasExited){
  # Only stop the specific child launched by this window; never an external Collector.
  try{Stop-Process -Id $script:collectorChild.Id -Force -ErrorAction Stop}catch{}
 }
 try{$script:uiMutex.ReleaseMutex()}catch{}
 $script:uiMutex.Dispose()
})
# Background collector cannot open a console and uses an independent named mutex.
try{
 $powershell=Join-Path $PSHOME 'powershell.exe'
 $collectorFile=Join-Path $PSScriptRoot 'collector.ps1'
 $arguments='-NoProfile -ExecutionPolicy Bypass -File "'+$collectorFile+'" -Machine '+$Machine+' -DataDir "'+$DataDir+'"'
 if($ComfyLog){$arguments+=' -ComfyLog "'+$ComfyLog.Replace('"','')+'"'}
 $script:collectorChild=Start-Process -FilePath $powershell -ArgumentList $arguments -WindowStyle Hidden -PassThru -ErrorAction Stop
}catch{
 $script:ui.CollectorBadge.Text='СБОР: ОШИБКА'
}
Start-Updates
$script:timer.Start()
[void]$window.ShowDialog()
