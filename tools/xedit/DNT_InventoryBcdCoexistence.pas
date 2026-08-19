unit DNT_InventoryBcdCoexistence;

uses SysUtils, Classes;

const
  BcdBaseName = 'Better Carriage Destinations.esp';
  BcdCftoName = 'Better Carriage Destinations - CFTO.esp';
  BcdWciiName = 'Better Carriage Destinations - Wait Carriage in Inns Patch.esp';

var
  SkyrimFile, CftoFile, BcdBaseFile, BcdCftoFile, BcdWciiFile: IInterface;
  ReportLines, SeenForms: TStringList;
  StatusPath, ErrorPath, ReportPath: string;

procedure WriteTextFile(const Path, TextValue: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := TextValue;
    Lines.SaveToFile(Path);
  finally
    Lines.Free;
  end;
end;

function FileByPluginName(const PluginName: string): IInterface;
var
  i: Integer;
begin
  Result := nil;
  for i := 0 to Pred(FileCount) do
    if LowerCase(GetFileName(FileByIndex(i))) = LowerCase(PluginName) then begin
      Result := FileByIndex(i);
      Exit;
    end;
end;

function DefinedRecordByObjectID(
  PluginFile: IInterface;
  ObjectID: Cardinal
): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(PluginFile) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
end;

function RequireRecord(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const ExpectedSignature: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(PluginFile, ObjectID);
  if not Assigned(Result) or (Signature(Result) <> ExpectedSignature) then
    raise Exception.Create(
      'Could not resolve ' + ExpectedSignature + ' object ' +
      IntToHex(ObjectID, 6) + ' in ' + GetFileName(PluginFile)
    );
end;

function InfoScriptNames(InfoRecord: IInterface): string;
var
  Scripts, ScriptEntry: IInterface;
  i: Integer;
  ScriptName: string;
begin
  Result := '';
  Scripts := ElementByPath(InfoRecord, 'VMAD\Scripts');
  if not Assigned(Scripts) then
    Exit;
  for i := 0 to Pred(ElementCount(Scripts)) do begin
    ScriptEntry := ElementByIndex(Scripts, i);
    ScriptName := GetElementEditValues(ScriptEntry, 'ScriptName');
    if ScriptName = '' then
      Continue;
    if Result <> '' then
      Result := Result + ',';
    Result := Result + ScriptName;
  end;
end;

function IsBcdDialogueScript(const ScriptNames: string): Boolean;
var
  Normalized: string;
begin
  Normalized := LowerCase(ScriptNames);
  Result :=
    (Pos('bcd_dialogscript', Normalized) > 0) or
    (Pos('bcd_cftoferrydialogscript', Normalized) > 0) or
    (Pos('bcd_wcii_dialogscript', Normalized) > 0);
end;

procedure AddInfoRecord(InfoRecord: IInterface);
var
  Winner, MasterRecord: IInterface;
  FormKey, SourceScripts, WinnerScripts: string;
begin
  if not Assigned(InfoRecord) or (Signature(InfoRecord) <> 'INFO') then
    Exit;
  FormKey := IntToHex(FormID(InfoRecord), 8);
  if SeenForms.IndexOf(FormKey) >= 0 then
    Exit;

  Winner := WinningOverride(InfoRecord);
  if not Assigned(Winner) then
    Winner := InfoRecord;
  SourceScripts := InfoScriptNames(InfoRecord);
  WinnerScripts := InfoScriptNames(Winner);
  if not IsBcdDialogueScript(SourceScripts) and
    not IsBcdDialogueScript(WinnerScripts) then
    Exit;

  MasterRecord := MasterOrSelf(InfoRecord);
  SeenForms.Add(FormKey);
  ReportLines.Add(
    'BCD_INFO' +
    '|FORM=' + FormKey +
    '|MASTER_FILE=' + GetFileName(GetFile(MasterRecord)) +
    '|MASTER_LOCAL=' + IntToHex(FixedFormID(MasterRecord), 8) +
    '|SOURCE_FILE=' + GetFileName(GetFile(InfoRecord)) +
    '|WINNER_FILE=' + GetFileName(GetFile(Winner)) +
    '|EDID=' + GetElementEditValues(Winner, 'EDID') +
    '|PROMPT=' + GetElementEditValues(Winner, 'RNAM') +
    '|SOURCE_SCRIPTS=' + SourceScripts +
    '|WINNER_SCRIPTS=' + WinnerScripts
  );
end;

procedure ScanDialogueFile(PluginFile: IInterface);
var
  TopicGroup, TopicRecord, InfoGroup, InfoRecord: IInterface;
  i, j: Integer;
begin
  TopicGroup := GroupBySignature(PluginFile, 'DIAL');
  if not Assigned(TopicGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(TopicGroup)) do begin
    TopicRecord := ElementByIndex(TopicGroup, i);
    InfoGroup := ChildGroup(TopicRecord);
    if not Assigned(InfoGroup) then
      Continue;
    for j := 0 to Pred(ElementCount(InfoGroup)) do begin
      InfoRecord := ElementByIndex(InfoGroup, j);
      AddInfoRecord(InfoRecord);
    end;
  end;
end;

procedure AddMarker(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const LabelValue: string
);
var
  Marker: IInterface;
begin
  Marker := RequireRecord(PluginFile, ObjectID, 'REFR');
  ReportLines.Add(
    'MARKER' +
    '|LABEL=' + LabelValue +
    '|FILE=' + GetFileName(GetFile(MasterOrSelf(Marker))) +
    '|LOCAL=' + IntToHex(FixedFormID(MasterOrSelf(Marker)), 8) +
    '|EDID=' + GetElementEditValues(Marker, 'EDID') +
    '|X=' + GetElementEditValues(Marker, 'DATA\Position\X') +
    '|Y=' + GetElementEditValues(Marker, 'DATA\Position\Y') +
    '|Z=' + GetElementEditValues(Marker, 'DATA\Position\Z')
  );
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\bcd-coexistence-inventory.status';
  ErrorPath := ScriptsPath + '..\..\build\bcd-coexistence-inventory.error';
  ReportPath := ScriptsPath + '..\..\build\bcd-coexistence-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  SeenForms := TStringList.Create;
  try
    SeenForms.Sorted := True;
    SeenForms.Duplicates := dupIgnore;
    SkyrimFile := FileByPluginName('Skyrim.esm');
    CftoFile := FileByPluginName('CFTO.esp');
    BcdBaseFile := FileByPluginName(BcdBaseName);
    BcdCftoFile := FileByPluginName(BcdCftoName);
    BcdWciiFile := FileByPluginName(BcdWciiName);
    if not Assigned(SkyrimFile) or not Assigned(CftoFile) or
      not Assigned(BcdBaseFile) or not Assigned(BcdCftoFile) or
      not Assigned(BcdWciiFile) then
      raise Exception.Create('Required Skyrim, CFTO, or BCD plugin is missing');

    AddMarker(SkyrimFile, $033E45, 'Thalmor Embassy map marker');
    AddMarker(CftoFile, $0B6E54, 'CFTO Thalmor Embassy arrival');
    ScanDialogueFile(BcdBaseFile);
    ScanDialogueFile(BcdCftoFile);
    ScanDialogueFile(BcdWciiFile);
    ReportLines.Add('BCD_INFO_COUNT=' + IntToStr(SeenForms.Count));
    ReportLines.SaveToFile(ReportPath);
    WriteTextFile(StatusPath, 'success');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

function Finalize: Integer;
begin
  if Assigned(ReportLines) then
    ReportLines.Free;
  if Assigned(SeenForms) then
    SeenForms.Free;
  Result := 0;
end;

end.
