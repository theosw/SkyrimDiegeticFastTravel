unit DNT_AuditBoatIlinalta;

uses SysUtils, Classes;

const
  BoatPrompt = 'Could you show me the Lake Ilinalta route?';
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
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(PluginFile, ObjectID);
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

function HasMasterNamed(const PluginName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(MasterCount(BoatFile)) do
    if LowerCase(GetFileName(MasterByIndex(BoatFile, i))) =
      LowerCase(PluginName) then begin
      Result := True;
      Exit;
    end;
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

procedure AssertProperty(
  ScriptEntry: IInterface;
  const PropertyNameValue: string;
  ExpectedRecord: IInterface
);
var
  ActualRecord: IInterface;
begin
  ActualRecord := PropertyObject(ScriptEntry, PropertyNameValue);
  if not Assigned(ActualRecord) or
    (FormID(ActualRecord) <> FormID(ExpectedRecord)) then
    raise Exception.Create(PropertyNameValue + ' property does not match');
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
      if not HasMasterNamed(ExpectedMasters[i]) then
        raise Exception.Create('Boat plugin lacks master ' + ExpectedMasters[i]);
  finally
    ExpectedMasters.Free;
  end;
  if HasMasterNamed('Better Carriage Destinations.esp') or
    HasMasterNamed('BCD - Carriages.esp') or
    HasMasterNamed('BCD - CFTO.esp') then
    raise Exception.Create('Boat plugin unexpectedly masters BCD');
  if Assigned(GroupBySignature(BoatFile, 'FLST')) or
    Assigned(GroupBySignature(BoatFile, 'FACT')) then
    raise Exception.Create('Boat plugin unexpectedly defines routes/factions');
  ReportLines.Add('PASS masters -> official files plus CFTO only, no BCD');
end;

procedure AuditQuest;
var
  BoatQuest, ServiceScript, PickerScript, Scripts: IInterface;
begin
  BoatQuest := RequireBoatRecord('QUST', 'DNT_BoatIlinaltaQuest');
  if (GetElementNativeValues(BoatQuest, 'DNAM\Flags') and 1) = 0 then
    raise Exception.Create('Boat quest is not start-game enabled');
  if GetElementNativeValues(BoatQuest, 'DNAM\Priority') <> 60 then
    raise Exception.Create('Boat quest priority is not 60');
  Scripts := ElementByPath(BoatQuest, 'VMAD\Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 2) then
    raise Exception.Create('Boat quest does not have exactly two scripts');
  ServiceScript := ScriptByName(
    BoatQuest,
    'DNT_IlinaltaBoatTravelService'
  );
  PickerScript := ScriptByName(
    BoatQuest,
    'DNT_IlinaltaBoatParchmentPicker'
  );
  if not Assigned(ServiceScript) or not Assigned(PickerScript) then
    raise Exception.Create('Boat quest scripts do not match');
  AssertProperty(PickerScript, 'Service', BoatQuest);
  ReportLines.Add(
    'PASS quest -> start-enabled service and native parchment provider'
  );
  ReportLines.Add(
    'QUEST_FIXED_FORM_ID=' + IntToHex(FixedFormID(BoatQuest), 8)
  );
end;

procedure AuditDialogue;
var
  BoatQuest, BoatBranch, BoatTopic, BoatInfo, InfoGroup, Conditions,
    TopicQuest, BranchQuest, StartingTopic, ActualBranch, SharedInfo,
    ActualSharedInfo, DialogueFaction, RouteFaction, VMAD, Scripts,
    FragmentScript, Properties: IInterface;
begin
  BoatQuest := RequireBoatRecord('QUST', 'DNT_BoatIlinaltaQuest');
  BoatBranch := RequireBoatRecord(
    'DLBR',
    'DNT_BoatIlinaltaParchmentBranch'
  );
  BoatTopic := RequireBoatRecord(
    'DIAL',
    'DNT_BoatIlinaltaParchmentTopic'
  );
  if GetElementEditValues(BoatTopic, 'FULL') <> BoatPrompt then
    raise Exception.Create('Boat prompt does not match');
  if GetElementNativeValues(BoatTopic, 'TIFC') <> 1 then
    raise Exception.Create('Boat DIAL INFO count does not match');

  TopicQuest := LinksTo(ElementByPath(BoatTopic, 'QNAM'));
  BranchQuest := LinksTo(ElementByPath(BoatBranch, 'QNAM'));
  StartingTopic := LinksTo(ElementByPath(BoatBranch, 'SNAM'));
  ActualBranch := LinksTo(ElementByPath(BoatTopic, 'BNAM'));
  if not Assigned(TopicQuest) or
    (FormID(TopicQuest) <> FormID(BoatQuest)) or
    not Assigned(BranchQuest) or
    (FormID(BranchQuest) <> FormID(BoatQuest)) then
    raise Exception.Create('Boat topic/branch quest ownership mismatch');
  if not Assigned(StartingTopic) or
    (FormID(StartingTopic) <> FormID(BoatTopic)) or
    not Assigned(ActualBranch) or
    (FormID(ActualBranch) <> FormID(BoatBranch)) then
    raise Exception.Create('Boat topic/branch links do not match');
  if GetElementNativeValues(BoatBranch, 'TNAM') <> 0 then
    raise Exception.Create('Boat branch category is not Player');
  if GetElementNativeValues(BoatBranch, 'DNAM') <> 1 then
    raise Exception.Create('Boat branch is not top-level non-blocking');

  InfoGroup := ChildGroup(BoatTopic);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 1) then
    raise Exception.Create('Boat topic does not contain exactly one INFO');
  BoatInfo := ElementByIndex(InfoGroup, 0);
  if GetElementEditValues(BoatInfo, 'EDID') <>
    'DNT_BoatIlinaltaParchmentInfo' then
    raise Exception.Create('Boat INFO EditorID does not match');
  if GetElementEditValues(BoatInfo, 'RNAM') <> BoatPrompt then
    raise Exception.Create('Boat INFO prompt does not match');
  if GetElementNativeValues(BoatInfo, 'ENAM\Response Flags') <>
    GoodbyeResponseFlagsMask then
    raise Exception.Create('Boat response flags do not match');
  SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO', '');
  ActualSharedInfo := LinksTo(ElementByPath(BoatInfo, 'DNAM'));
  if not Assigned(ActualSharedInfo) or
    (FormID(ActualSharedInfo) <> FormID(SharedInfo)) then
    raise Exception.Create('Boat shared voiced response does not match');

  Conditions := ElementByPath(BoatInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 2) then
    raise Exception.Create('Boat INFO does not have two faction conditions');
  DialogueFaction := RequireRecord(
    CftoFile,
    $00AA05,
    'FACT',
    'KmodFastTravelDialogueFaction'
  );
  RouteFaction := RequireRecord(
    CftoFile,
    $02E1DF,
    'FACT',
    'KmodFerryRoute3Faction'
  );
  AssertCondition(BoatInfo, 0, DialogueFaction);
  AssertCondition(BoatInfo, 1, RouteFaction);

  VMAD := ElementByPath(BoatInfo, 'VMAD');
  if not Assigned(VMAD) or
    (GetElementNativeValues(VMAD, 'Script Fragments\Flags') <>
      OnEndFragmentMask) or
    (GetElementEditValues(VMAD, 'Script Fragments\FileName') <>
      'DNT_IlinaltaBoatParchmentFragment') then
    raise Exception.Create('Boat INFO fragment metadata mismatch');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Boat INFO does not have one fragment script');
  FragmentScript := ElementByIndex(Scripts, 0);
  if GetElementEditValues(FragmentScript, 'ScriptName') <>
    'DNT_IlinaltaBoatParchmentFragment' then
    raise Exception.Create('Boat fragment script does not match');
  Properties := ElementByPath(FragmentScript, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 1) then
    raise Exception.Create('Boat fragment does not have one property');
  AssertProperty(FragmentScript, 'Picker', BoatQuest);
  ReportLines.Add(
    'PASS dialogue -> Route 3 ferrymen, shared voice, and OnEnd picker'
  );
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\boat-ilinalta-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\boat-ilinalta-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-ilinalta-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    BoatFile := FileByPluginName('DiegeticTravelBoatIlinalta.esp');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(BoatFile) or not Assigned(DawnguardFile) or
      not Assigned(CftoFile) then
      raise Exception.Create('Required boat audit plugin is missing');
    AuditMasters;
    AuditQuest;
    AuditDialogue;
    ReportLines.Add('PASS Lake Ilinalta boat plugin audit complete');
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
