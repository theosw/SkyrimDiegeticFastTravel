unit DNT_GateLegacyDialogue;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravel.esp';
  GateEditorID = 'DNT_ShowLegacyTravelDialogue';
  EqualConditionType = $00;

var
  OutputFile, CftoFile: IInterface;
  StatusPath, ErrorPath, PluginOutputPath: string;
  GatedWizardCount, GatedCarriageCount, GatedFerryCount: Integer;

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
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve ' + ExpectedSignature + ' object ' +
      IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      'Object ' + IntToHex(ObjectID, 6) + ' is not ' + ExpectedSignature
    );
end;

function FindRecordByEditorID(
  PluginFile: IInterface;
  const RecordSignature, EditorIDValue: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(PluginFile, RecordSignature);
  if not Assigned(RecordGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(RecordGroup)) do begin
    Candidate := ElementByIndex(RecordGroup, i);
    if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

function FindInfoByEditorID(
  PluginFile: IInterface;
  const EditorIDValue: string
): IInterface;
var
  TopicGroup, TopicRecord, InfoGroup, Candidate: IInterface;
  i, j: Integer;
begin
  Result := nil;
  TopicGroup := GroupBySignature(PluginFile, 'DIAL');
  if not Assigned(TopicGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(TopicGroup)) do begin
    TopicRecord := ElementByIndex(TopicGroup, i);
    InfoGroup := ChildGroup(TopicRecord);
    if not Assigned(InfoGroup) then
      Continue;
    for j := 0 to Pred(ElementCount(InfoGroup)) do begin
      Candidate := ElementByIndex(InfoGroup, j);
      if (Signature(Candidate) = 'INFO') and
        (GetElementEditValues(Candidate, 'EDID') = EditorIDValue) then begin
        Result := Candidate;
        Exit;
      end;
    end;
  end;
end;

function EnsureLegacyDialogueGlobal: IInterface;
var
  TemplateGlobal: IInterface;
begin
  Result := FindRecordByEditorID(OutputFile, 'GLOB', GateEditorID);
  if Assigned(Result) then
    Exit;

  TemplateGlobal := RequireRecord(CftoFile, $00AA12, 'GLOB');
  Result := wbCopyElementToFile(TemplateGlobal, OutputFile, True, False);
  if not Assigned(Result) then
    raise Exception.Create('Could not create legacy dialogue compatibility global');
  SetElementEditValues(Result, 'EDID', GateEditorID);
  SetElementNativeValues(Result, 'FLTV', 0.0);
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
    if not Assigned(ConditionData) then
      Continue;
    if GetElementEditValues(ConditionData, 'Function') <> 'GetGlobalValue' then
      Continue;
    ParameterRecord := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
    if Assigned(ParameterRecord) and
      (FormID(ParameterRecord) = FormID(GateGlobal)) then
      Inc(Result);
  end;
end;

procedure AddLegacyDialogueGate(
  InfoRecord, GateGlobal: IInterface;
  const LabelValue: string
);
var
  Conditions, ConditionEntry, ConditionData, ParameterElement,
    ReadBackParameter: IInterface;
begin
  if GateConditionCount(InfoRecord, GateGlobal) <> 0 then
    raise Exception.Create(LabelValue + ' already has a legacy dialogue gate');

  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then begin
    Add(InfoRecord, 'Conditions', True);
    Conditions := ElementByPath(InfoRecord, 'Conditions');
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create conditions for ' + LabelValue);

  ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create(LabelValue + ' gate has no CTDA');
  SetElementNativeValues(ConditionData, 'Type', EqualConditionType);
  SetElementNativeValues(ConditionData, 'Comparison Value - Float', 1.0);
  SetElementEditValues(ConditionData, 'Function', 'GetGlobalValue');
  SetElementNativeValues(ConditionData, 'Run On', 0);
  ParameterElement := ElementByPath(ConditionData, 'Parameter #1');
  SetEditValue(ParameterElement, Name(GateGlobal));
  ReadBackParameter := LinksTo(ParameterElement);
  if not Assigned(ReadBackParameter) or
    (FormID(ReadBackParameter) <> FormID(GateGlobal)) then
    raise Exception.Create(LabelValue + ' gate did not read back');
  if GateConditionCount(InfoRecord, GateGlobal) <> 1 then
    raise Exception.Create(LabelValue + ' gate count did not read back as one');
end;

procedure GateOutputInfo(
  InfoRecord, GateGlobal: IInterface;
  const LabelValue: string
);
begin
  if not Assigned(InfoRecord) then
    raise Exception.Create('Could not resolve output INFO ' + LabelValue);
  if GetFile(InfoRecord) <> OutputFile then
    raise Exception.Create(LabelValue + ' is not owned by the output plugin');
  AddLegacyDialogueGate(InfoRecord, GateGlobal, LabelValue);
end;

procedure GateCftoInfo(
  SourceInfo, GateGlobal: IInterface;
  const LabelValue: string
);
var
  OverrideInfo: IInterface;
begin
  if not Assigned(SourceInfo) or (Signature(SourceInfo) <> 'INFO') then
    raise Exception.Create('Could not resolve CFTO INFO ' + LabelValue);
  OverrideInfo := wbCopyElementToFile(SourceInfo, OutputFile, False, True);
  if not Assigned(OverrideInfo) then
    raise Exception.Create('Could not override CFTO INFO ' + LabelValue);
  GateOutputInfo(OverrideInfo, GateGlobal, LabelValue);
end;

procedure GateFerryTopic(
  TopicObjectID: Cardinal;
  GateGlobal: IInterface;
  const LabelValue: string
);
var
  SourceTopic, InfoGroup, SourceInfo: IInterface;
  i, TopicCount: Integer;
begin
  SourceTopic := RequireRecord(CftoFile, TopicObjectID, 'DIAL');
  InfoGroup := ChildGroup(SourceTopic);
  if not Assigned(InfoGroup) then
    raise Exception.Create(LabelValue + ' has no INFO child group');
  TopicCount := 0;
  for i := 0 to Pred(ElementCount(InfoGroup)) do begin
    SourceInfo := ElementByIndex(InfoGroup, i);
    if Signature(SourceInfo) <> 'INFO' then
      Continue;
    GateCftoInfo(
      SourceInfo,
      GateGlobal,
      LabelValue + ' INFO ' + IntToHex(FixedFormID(SourceInfo), 8)
    );
    Inc(TopicCount);
    Inc(GatedFerryCount);
  end;
  if TopicCount = 0 then
    raise Exception.Create(LabelValue + ' contains no INFO records');
end;

procedure SaveGeneratedPlugin;
var
  OutputStream: TFileStream;
begin
  OutputStream := TFileStream.Create(PluginOutputPath, fmCreate);
  try
    FileWriteToStream(OutputFile, OutputStream, False);
  finally
    OutputStream.Free;
  end;
end;

function Initialize: Integer;
var
  GateGlobal, WizardHub: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\legacy-dialogue-gate.status';
  ErrorPath := ScriptsPath + '..\..\build\legacy-dialogue-gate.error';
  PluginOutputPath := ScriptsPath +
    '..\..\build\release\DiegeticTravel.esp';
  WriteTextFile(StatusPath, 'running');

  try
    OutputFile := FileByPluginName(OutputPluginName);
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(OutputFile) or not Assigned(CftoFile) then
      raise Exception.Create('Consolidated output or CFTO is not loaded');

    GatedWizardCount := 0;
    GatedCarriageCount := 0;
    GatedFerryCount := 0;
    GateGlobal := EnsureLegacyDialogueGlobal;
    if Abs(GetElementNativeValues(GateGlobal, 'FLTV')) > 0.001 then
      raise Exception.Create('Legacy dialogue compatibility global is not zero');

    WizardHub := FindInfoByEditorID(OutputFile, 'DNT_WG_Request_Phinis');
    GateOutputInfo(WizardHub, GateGlobal, 'obsolete College wizard hub');
    Inc(GatedWizardCount);

    GateCftoInfo(
      RequireRecord(CftoFile, $09D8C7, 'INFO'),
      GateGlobal,
      'CFTO paid carriage request'
    );
    Inc(GatedCarriageCount);
    GateCftoInfo(
      RequireRecord(CftoFile, $0DA634, 'INFO'),
      GateGlobal,
      'CFTO free carriage request'
    );
    Inc(GatedCarriageCount);

    GateFerryTopic($019DC4, GateGlobal, 'CFTO Lake Honrich request');
    GateFerryTopic($02E1DD, GateGlobal, 'CFTO Lake Ilinalta request');
    GateFerryTopic($00AA0E, GateGlobal, 'CFTO north-coast request');
    GateFerryTopic($0383FE, GateGlobal, 'CFTO Solstheim request');

    SaveGeneratedPlugin;
    WriteTextFile(StatusPath, 'success');
    AddMessage(
      '[DNT] Gated legacy travel dialogue behind ' + GateEditorID +
      ': wizard=' + IntToStr(GatedWizardCount) +
      ' carriage=' + IntToStr(GatedCarriageCount) +
      ' ferry=' + IntToStr(GatedFerryCount)
    );
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
