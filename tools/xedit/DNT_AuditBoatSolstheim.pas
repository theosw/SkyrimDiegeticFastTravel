unit DNT_AuditBoatSolstheim;

uses SysUtils, Classes;

const
  BoatPrompt = 'Could you show me your Solstheim route?';
  OnEndFragmentMask = $02;
  GoodbyeResponseFlagsMask = $0001;
  EqualConditionType = $00;

var
  BoatFile, DawnguardFile, CftoFile: IInterface;
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

function RequireRecord(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(PluginFile) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve ' + ExpectedSignature + ' ' +
      IntToHex(ObjectID, 6));
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(IntToHex(ObjectID, 6) + ' has wrong signature');
  if (ExpectedEditorID <> '') and
    (GetElementEditValues(Result, 'EDID') <> ExpectedEditorID) then
    raise Exception.Create(ExpectedEditorID + ' has wrong EditorID');
end;

function RequireBoatRecord(
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(BoatFile, ExpectedSignature);
  if Assigned(RecordGroup) then
    for i := 0 to Pred(ElementCount(RecordGroup)) do begin
      Candidate := ElementByIndex(RecordGroup, i);
      if GetElementEditValues(Candidate, 'EDID') = ExpectedEditorID then begin
        Result := Candidate;
        Break;
      end;
    end;
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve boat record ' + ExpectedEditorID);
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
    if GetElementEditValues(Candidate, 'ScriptName') = ScriptNameValue then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

function PropertyObject(
  ScriptEntry: IInterface;
  const PropertyNameValue: string
): IInterface;
var
  Properties, PropertyEntry: IInterface;
  i: Integer;
begin
  Result := nil;
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    Exit;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyEntry := ElementByIndex(Properties, i);
    if GetElementEditValues(PropertyEntry, 'propertyName') =
      PropertyNameValue then begin
      Result := LinksTo(ElementByPath(
        PropertyEntry,
        'Value\Object Union\Object v2\FormID'
      ));
      Exit;
    end;
  end;
end;

procedure AssertLinked(
  RecordElement: IInterface;
  const PathValue, DescriptionValue: string;
  ExpectedRecord: IInterface
);
var
  ActualRecord: IInterface;
begin
  ActualRecord := LinksTo(ElementByPath(RecordElement, PathValue));
  if not Assigned(ActualRecord) or
    (FormID(ActualRecord) <> FormID(ExpectedRecord)) then
    raise Exception.Create(DescriptionValue + ' does not match');
end;

procedure AssertCondition(
  InfoRecord: IInterface;
  Index: Integer;
  ParameterRecord: IInterface
);
var
  Conditions, ConditionData, ActualParameter: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (Index >= ElementCount(Conditions)) then
    raise Exception.Create('Missing boat INFO condition ' + IntToStr(Index));
  ConditionData := ElementByPath(ElementByIndex(Conditions, Index), 'CTDA');
  if GetElementEditValues(ConditionData, 'Function') <> 'GetInFaction' then
    raise Exception.Create('Boat INFO condition function mismatch');
  if GetElementNativeValues(ConditionData, 'Type') <> EqualConditionType then
    raise Exception.Create('Boat INFO condition type mismatch');
  if Abs(GetElementNativeValues(
    ConditionData,
    'Comparison Value - Float'
  ) - 1.0) > 0.001 then
    raise Exception.Create('Boat INFO condition comparison mismatch');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create('Boat INFO condition is not subject-scoped');
  ActualParameter := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ActualParameter) or
    (FormID(ActualParameter) <> FormID(ParameterRecord)) then
    raise Exception.Create('Boat INFO condition parameter mismatch');
end;

procedure AuditMasters;
var
  ExpectedMasters: TStringList;
  i: Integer;
begin
  ExpectedMasters := TStringList.Create;
  try
    ExpectedMasters.Add('Skyrim.esm');
    ExpectedMasters.Add('Update.esm');
    ExpectedMasters.Add('Dawnguard.esm');
    ExpectedMasters.Add('HearthFires.esm');
    ExpectedMasters.Add('Dragonborn.esm');
    ExpectedMasters.Add('CFTO.esp');
    if MasterCount(BoatFile) <> ExpectedMasters.Count then
      raise Exception.Create('Boat plugin master count does not match');
    for i := 0 to Pred(ExpectedMasters.Count) do
      if LowerCase(GetFileName(MasterByIndex(BoatFile, i))) <>
        LowerCase(ExpectedMasters[i]) then
        raise Exception.Create('Boat plugin master order mismatch');
    ReportLines.Add('PASS masters=6');
  finally
    ExpectedMasters.Free;
  end;
end;

procedure AuditDialogue(QuestRecord: IInterface);
var
  TopicRecord, BranchRecord, InfoGroup, InfoRecord, SharedInfo,
    DialogueFaction, RouteFaction, FragmentScript, Conditions,
    Fragments, Fragment: IInterface;
begin
  TopicRecord := RequireBoatRecord(
    'DIAL',
    'DNT_BoatSolstheimParchmentTopic'
  );
  BranchRecord := RequireBoatRecord(
    'DLBR',
    'DNT_BoatSolstheimParchmentBranch'
  );
  if GetElementEditValues(TopicRecord, 'FULL') <> BoatPrompt then
    raise Exception.Create('Solstheim topic prompt mismatch');
  if GetElementNativeValues(TopicRecord, 'TIFC') <> 1 then
    raise Exception.Create('Solstheim topic INFO count mismatch');
  AssertLinked(TopicRecord, 'QNAM', 'Topic quest', QuestRecord);
  AssertLinked(TopicRecord, 'BNAM', 'Topic branch', BranchRecord);
  AssertLinked(BranchRecord, 'QNAM', 'Branch quest', QuestRecord);
  AssertLinked(BranchRecord, 'SNAM', 'Branch start topic', TopicRecord);

  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 1) then
    raise Exception.Create('Solstheim topic does not contain exactly one INFO');
  InfoRecord := ElementByIndex(InfoGroup, 0);
  if GetElementEditValues(InfoRecord, 'EDID') <>
    'DNT_BoatSolstheimParchmentInfo' then
    raise Exception.Create('Solstheim INFO EditorID mismatch');
  if GetElementEditValues(InfoRecord, 'RNAM') <> BoatPrompt then
    raise Exception.Create('Solstheim INFO prompt mismatch');
  if GetElementNativeValues(InfoRecord, 'ENAM\Response Flags') <>
    GoodbyeResponseFlagsMask then
    raise Exception.Create('Solstheim INFO must be Goodbye');

  SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO', '');
  AssertLinked(InfoRecord, 'DNAM', 'Shared response', SharedInfo);
  DialogueFaction := RequireRecord(
    CftoFile,
    $00AA05,
    'FACT',
    'KmodFastTravelDialogueFaction'
  );
  RouteFaction := RequireRecord(
    CftoFile,
    $02E1E0,
    'FACT',
    'KmodFerryRoute4Faction'
  );
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 2) then
    raise Exception.Create('Solstheim INFO must have exactly two conditions');
  AssertCondition(InfoRecord, 0, DialogueFaction);
  AssertCondition(InfoRecord, 1, RouteFaction);

  FragmentScript := ScriptByName(
    InfoRecord,
    'DNT_SolstheimBoatParchmentFragment'
  );
  if not Assigned(FragmentScript) then
    raise Exception.Create('Solstheim INFO fragment script is missing');
  if FormID(PropertyObject(FragmentScript, 'Picker')) <>
    FormID(QuestRecord) then
    raise Exception.Create('Solstheim fragment Picker property mismatch');
  if GetElementEditValues(InfoRecord, 'VMAD\Script Fragments\FileName') <>
    'DNT_SolstheimBoatParchmentFragment' then
    raise Exception.Create('Solstheim fragment filename mismatch');
  if GetElementNativeValues(InfoRecord, 'VMAD\Script Fragments\Flags') <>
    OnEndFragmentMask then
    raise Exception.Create('Solstheim fragment must run on end');
  Fragments := ElementByPath(
    InfoRecord,
    'VMAD\Script Fragments\Fragments'
  );
  if not Assigned(Fragments) or (ElementCount(Fragments) <> 1) then
    raise Exception.Create('Solstheim INFO fragment count mismatch');
  Fragment := ElementByIndex(Fragments, 0);
  if (GetElementEditValues(Fragment, 'ScriptName') <>
    'DNT_SolstheimBoatParchmentFragment') or
    (GetElementEditValues(Fragment, 'FragmentName') <> 'Fragment_0') then
    raise Exception.Create('Solstheim INFO fragment binding mismatch');
  ReportLines.Add('PASS dialogue=route4_shared_voice_goodbye_on_end');
end;

function Initialize: Integer;
var
  QuestRecord, ServiceScript, PickerScript: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\boat-solstheim-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\boat-solstheim-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-solstheim-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    BoatFile := FileByPluginName('DiegeticTravelBoatSolstheim.esp');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(BoatFile) or not Assigned(DawnguardFile) or
      not Assigned(CftoFile) then
      raise Exception.Create('Required Solstheim audit plugin is missing');

    AuditMasters;
    QuestRecord := RequireBoatRecord('QUST', 'DNT_BoatSolstheimQuest');
    if GetElementNativeValues(QuestRecord, 'DNAM\Flags') <> 1 then
      raise Exception.Create('Solstheim quest is not Start Game Enabled');
    if GetElementNativeValues(QuestRecord, 'DNAM\Priority') <> 60 then
      raise Exception.Create('Solstheim quest priority mismatch');
    ServiceScript := ScriptByName(
      QuestRecord,
      'DNT_SolstheimBoatTravelService'
    );
    PickerScript := ScriptByName(
      QuestRecord,
      'DNT_SolstheimBoatParchmentPicker'
    );
    if not Assigned(ServiceScript) or not Assigned(PickerScript) then
      raise Exception.Create('Solstheim quest script wiring is incomplete');
    if FormID(PropertyObject(PickerScript, 'Service')) <>
      FormID(QuestRecord) then
      raise Exception.Create('Solstheim picker Service property mismatch');
    ReportLines.Add(
      'QUEST_FIXED_FORM_ID=' + IntToHex(FixedFormID(QuestRecord), 8)
    );
    ReportLines.Add('PASS quest=start_game_enabled_priority_60');

    AuditDialogue(QuestRecord);
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
