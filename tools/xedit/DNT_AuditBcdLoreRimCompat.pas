unit DNT_AuditBcdLoreRimCompat;

uses SysUtils, Classes;

const
  CompatPluginName = 'DiegeticTravelLoreRimBcdCompat.esp';
  GateEditorID = 'DNT_ShowBcdTravelDialogue';

var
  CompatFile, BcdBaseFile, WciiFile: IInterface;
  ReportLines: TStringList;
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

function OutputHasMaster(const MasterName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(MasterCount(CompatFile)) do
    if LowerCase(GetFileName(MasterByIndex(CompatFile, i))) =
      LowerCase(MasterName) then begin
      Result := True;
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
    raise Exception.Create('Could not resolve ' + ExpectedSignature + ' ' +
      IntToHex(ObjectID, 6));
end;

function RequireRecordByEditorID(
  PluginFile: IInterface;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(PluginFile, ExpectedSignature);
  if Assigned(RecordGroup) then
    for i := 0 to Pred(ElementCount(RecordGroup)) do begin
      Candidate := ElementByIndex(RecordGroup, i);
      if GetElementEditValues(Candidate, 'EDID') = ExpectedEditorID then begin
        Result := Candidate;
        Exit;
      end;
    end;
  raise Exception.Create('Could not resolve ' + ExpectedSignature +
    ' EditorID ' + ExpectedEditorID);
end;

function ScriptByName(
  RecordElement: IInterface;
  const ScriptNameValue: string
): IInterface;
var
  Scripts, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  Scripts := ElementByPath(RecordElement, 'VMAD\Scripts');
  if not Assigned(Scripts) then
    Exit;
  for i := 0 to Pred(ElementCount(Scripts)) do begin
    Candidate := ElementByIndex(Scripts, i);
    if LowerCase(GetElementEditValues(Candidate, 'ScriptName')) =
      LowerCase(ScriptNameValue) then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

function GateConditionCount(
  InfoRecord, GateGlobal: IInterface
): Integer;
var
  Conditions, Entry, ConditionData, ParameterRecord: IInterface;
  i: Integer;
begin
  Result := 0;
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then
    Exit;
  for i := 0 to Pred(ElementCount(Conditions)) do begin
    Entry := ElementByIndex(Conditions, i);
    ConditionData := ElementByPath(Entry, 'CTDA');
    if not Assigned(ConditionData) or
      (GetElementEditValues(ConditionData, 'Function') <> 'GetGlobalValue') then
      Continue;
    ParameterRecord := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
    if Assigned(ParameterRecord) and
      (FormID(ParameterRecord) = FormID(GateGlobal)) then
      Inc(Result);
  end;
end;

procedure AuditInfo(
  SourceRecord, GateGlobal: IInterface;
  const ExpectedScript, LabelValue: string
);
var
  Winner: IInterface;
begin
  Winner := WinningOverride(SourceRecord);
  if not Assigned(Winner) or (GetFile(Winner) <> CompatFile) then
    raise Exception.Create(LabelValue + ' is not won by the compatibility plugin');
  if not Assigned(ScriptByName(Winner, ExpectedScript)) then
    raise Exception.Create(LabelValue + ' lost ' + ExpectedScript);
  if GateConditionCount(Winner, GateGlobal) <> 1 then
    raise Exception.Create(LabelValue + ' does not have exactly one BCD gate');
  ReportLines.Add('PASS ' + LabelValue + '=gated');
end;

procedure AuditMasters;
var
  Required: TStringList;
  i: Integer;
begin
  Required := TStringList.Create;
  try
    Required.Add('Better Carriage Destinations.esp');
    Required.Add('Better Carriage Destinations - CFTO.esp');
    Required.Add('Better Carriage Destinations - Wait Carriage in Inns Patch.esp');
    Required.Add('CFTO.esp');
    Required.Add('WaitCarriageInns.esp');
    Required.Add('DiegeticTravel.esp');
    for i := 0 to Pred(Required.Count) do
      if not OutputHasMaster(Required[i]) then
        raise Exception.Create('Compatibility plugin is missing master ' + Required[i]);
    ReportLines.Add('PASS required_masters=6');
    ReportLines.Add('INFO total_masters=' + IntToStr(MasterCount(CompatFile)));
  finally
    Required.Free;
  end;
end;

function Initialize: Integer;
var
  GateGlobal, FileHeader: IInterface;
  NextObjectID: Cardinal;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\bcd-lorerim-compat-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\bcd-lorerim-compat-audit.error';
  ReportPath := ScriptsPath + '..\..\build\bcd-lorerim-compat-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CompatFile := FileByPluginName(CompatPluginName);
    BcdBaseFile := FileByPluginName('Better Carriage Destinations.esp');
    WciiFile := FileByPluginName('WaitCarriageInns.esp');
    if not Assigned(CompatFile) or not Assigned(BcdBaseFile) or
      not Assigned(WciiFile) then
      raise Exception.Create('Required compatibility, BCD, or WCI file is missing');

    AuditMasters;
    if not GetIsESL(CompatFile) or not CanBeESL(CompatFile) then
      raise Exception.Create('Compatibility plugin is not ESL-capable and flagged');
    FileHeader := ElementByIndex(CompatFile, 0);
    NextObjectID := GetElementNativeValues(FileHeader, 'HEDR\Next Object ID');
    if (NextObjectID <= $000800) or (NextObjectID > $001000) then
      raise Exception.Create(
        'Compatibility Next Object ID is outside ESL range: 0x' +
        IntToHex(NextObjectID, 6)
      );
    ReportLines.Add('PASS esl=true');
    ReportLines.Add('PASS next_object_id=0x' + IntToHex(NextObjectID, 6));

    GateGlobal := RequireRecordByEditorID(CompatFile, 'GLOB', GateEditorID);
    if Abs(GetElementNativeValues(GateGlobal, 'FLTV')) > 0.001 then
      raise Exception.Create('BCD dialogue gate must default to zero');
    ReportLines.Add('PASS gate_default=0');
    AuditInfo(
      RequireRecord(BcdBaseFile, $000015, 'INFO'),
      GateGlobal,
      'BCD_DialogScript',
      'bcd_carriage_info'
    );
    AuditInfo(
      RequireRecord(BcdBaseFile, $00001A, 'INFO'),
      GateGlobal,
      'BCD_CFTOFerryDialogScript',
      'bcd_cfto_ferry_info'
    );
    AuditInfo(
      RequireRecord(WciiFile, $000802, 'INFO'),
      GateGlobal,
      'BCD_WCII_DialogScript',
      'bcd_wci_info'
    );
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
  Result := 0;
end;

end.
