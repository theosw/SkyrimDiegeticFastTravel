unit DNT_AuditWizardParchmentAdapter;

uses SysUtils, Classes;

const
  ParchmentPrompt =
    'Could you show me your travel map? (250 gold per trip)';
  ParchmentResponse = 'Let me show you.';
  MirabelleParchmentResponse = 'Very good. Then we''re done here.';
  OnBeginFragmentMask = $01;
  SilentTerminalResponseFlagsMask = $0A01;
  EqualConditionType = $00;
  GreaterThanOrEqualConditionType = $60;
  NotEqualConditionType = $20;

var
  AdapterFile, SkyrimFile, WizardFile: IInterface;
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
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(
    PluginFile,
    FileFormID
  );
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
    raise Exception.Create('Could not resolve ' + ExpectedEditorID);
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(ExpectedEditorID + ' has the wrong signature');
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(ExpectedEditorID + ' has the wrong EditorID');
end;

function RequireSkyrimRecord(
  FormIDValue: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := RecordByFormID(SkyrimFile, FormIDValue, True);
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve ' + ExpectedEditorID);
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(ExpectedEditorID + ' has the wrong signature');
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(ExpectedEditorID + ' has the wrong EditorID');
end;

function RequireAdapterRecord(
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(AdapterFile, ExpectedSignature);
  if Assigned(RecordGroup) then
    for i := 0 to Pred(ElementCount(RecordGroup)) do begin
      Candidate := ElementByIndex(RecordGroup, i);
      if GetElementEditValues(Candidate, 'EDID') = ExpectedEditorID then begin
        Result := Candidate;
        Break;
      end;
    end;
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve adapter record ' +
      ExpectedEditorID);
end;

function TopicContainingInfo(
  PluginFile, InfoRecord: IInterface
): IInterface;
var
  TopicGroup, TopicRecord, InfoGroup, CandidateInfo: IInterface;
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
      CandidateInfo := ElementByIndex(InfoGroup, j);
      if FormID(CandidateInfo) = FormID(InfoRecord) then begin
        Result := TopicRecord;
        Exit;
      end;
    end;
  end;
end;

function InfoInTopicByEditorID(
  TopicRecord: IInterface;
  const EditorIDValue: string
): IInterface;
var
  InfoGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(InfoGroup)) do begin
    Candidate := ElementByIndex(InfoGroup, i);
    if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

function HasMasterNamed(const PluginName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(MasterCount(AdapterFile)) do
    if LowerCase(GetFileName(MasterByIndex(AdapterFile, i))) =
      LowerCase(PluginName) then begin
      Result := True;
      Exit;
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
      Result := LinksTo(
        ElementByPath(
          PropertyEntry,
          'Value\Object Union\Object v2\FormID'
        )
      );
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
  const FunctionName: string;
  ParameterRecord: IInterface;
  ConditionType: Cardinal;
  ComparisonValue: Double
);
var
  Conditions, ConditionData, ActualParameter: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (Index >= ElementCount(Conditions)) then
    raise Exception.Create('Missing parchment INFO condition ' +
      IntToStr(Index));
  ConditionData := ElementByPath(ElementByIndex(Conditions, Index), 'CTDA');
  if GetElementEditValues(ConditionData, 'Function') <> FunctionName then
    raise Exception.Create('Parchment INFO condition function mismatch');
  if GetElementNativeValues(ConditionData, 'Type') <> ConditionType then
    raise Exception.Create('Parchment INFO condition type mismatch');
  if Abs(
    GetElementNativeValues(ConditionData, 'Comparison Value - Float') -
    ComparisonValue
  ) > 0.001 then
    raise Exception.Create('Parchment INFO comparison mismatch');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create('Parchment INFO condition is not subject-scoped');
  ActualParameter := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ActualParameter) or
    (FormID(ActualParameter) <> FormID(ParameterRecord)) then
    raise Exception.Create('Parchment INFO condition parameter mismatch');
end;

procedure AuditMasters;
begin
  if not HasMasterNamed('DiegeticTravelWizardGuides.esp') then
    raise Exception.Create('Parchment adapter does not master wizard core');
  if HasMasterNamed('Better Carriage Destinations.esp') then
    raise Exception.Create('Parchment adapter unexpectedly masters BCD');
  if Assigned(GroupBySignature(AdapterFile, 'FLST')) then
    raise Exception.Create('Parchment adapter unexpectedly defines a FLST');
  ReportLines.Add('PASS masters -> wizard core only, no BCD');
end;

procedure AuditQuest;
var
  PickerQuest, WizardService, MirabelleBase, VMAD, Scripts, ScriptEntry,
    Properties: IInterface;
begin
  PickerQuest := RequireAdapterRecord(
    'QUST',
    'DNT_WizardParchmentPickerQuest'
  );
  if (GetElementNativeValues(PickerQuest, 'DNAM\Flags') and 1) = 0 then
    raise Exception.Create('Parchment quest is not start-game enabled');
  if GetElementNativeValues(PickerQuest, 'DNAM\Priority') <> 60 then
    raise Exception.Create('Parchment quest priority is not 60');
  VMAD := ElementByPath(PickerQuest, 'VMAD');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Parchment quest does not have one script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardParchmentPicker' then
    raise Exception.Create('Parchment quest script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 2) then
    raise Exception.Create('Parchment quest does not have two properties');

  WizardService := RequireRecord(
    WizardFile,
    $000800,
    'QUST',
    'DNT_WizardTravelQuest'
  );
  AssertProperty(ScriptEntry, 'Service', WizardService);
  MirabelleBase := RequireSkyrimRecord(
    $0001C1A0,
    'NPC_',
    'MirabelleErvine'
  );
  AssertProperty(ScriptEntry, 'MirabelleBase', MirabelleBase);
  ReportLines.Add(
    'PASS quest -> native provider, core service, and Mirabelle identity'
  );
end;

procedure AuditDialogue;
var
  PickerQuest, PickerBranch, PickerTopic, InfoGroup, PickerInfo,
    MirabelleInfo, MirabelleBase, Speaker,
    Conditions, VMAD, Scripts, ScriptEntry, Properties, TopicQuest,
    BranchQuest, StartingTopic, HubInfo, HubTopic, CoreBranch, ActualBranch:
    IInterface;
begin
  PickerQuest := RequireAdapterRecord(
    'QUST',
    'DNT_WizardParchmentPickerQuest'
  );
  PickerBranch := RequireAdapterRecord(
    'DLBR',
    'DNT_WG_OpenParchmentBranch'
  );
  PickerTopic := RequireAdapterRecord(
    'DIAL',
    'DNT_WG_OpenParchment'
  );
  if GetElementEditValues(PickerTopic, 'FULL') <> ParchmentPrompt then
    raise Exception.Create('Parchment DIAL prompt does not match');
  if GetElementNativeValues(PickerTopic, 'TIFC') <> 2 then
    raise Exception.Create('Parchment DIAL INFO count does not match');

  TopicQuest := LinksTo(ElementByPath(PickerTopic, 'QNAM'));
  BranchQuest := LinksTo(ElementByPath(PickerBranch, 'QNAM'));
  if not Assigned(TopicQuest) or
    (FormID(TopicQuest) <> FormID(PickerQuest)) or
    not Assigned(BranchQuest) or
    (FormID(BranchQuest) <> FormID(PickerQuest)) then
    raise Exception.Create('Parchment topic/branch quest ownership mismatch');
  if GetElementNativeValues(PickerBranch, 'TNAM') <> 0 then
    raise Exception.Create('Parchment branch category is not Player');
  if GetElementNativeValues(PickerBranch, 'DNAM') <> 1 then
    raise Exception.Create('Parchment branch is not top-level non-blocking');
  StartingTopic := LinksTo(ElementByPath(PickerBranch, 'SNAM'));
  if not Assigned(StartingTopic) or
    (FormID(StartingTopic) <> FormID(PickerTopic)) then
    raise Exception.Create('Parchment topic is not branch starting topic');

  HubInfo := RequireRecord(
    WizardFile,
    $000808,
    'INFO',
    'DNT_WG_Request_Phinis'
  );
  HubTopic := TopicContainingInfo(WizardFile, HubInfo);
  CoreBranch := LinksTo(ElementByPath(HubTopic, 'BNAM'));
  ActualBranch := LinksTo(ElementByPath(PickerTopic, 'BNAM'));
  if not Assigned(CoreBranch) or not Assigned(ActualBranch) then
    raise Exception.Create('Could not resolve dialogue branches');
  if FormID(ActualBranch) <> FormID(PickerBranch) then
    raise Exception.Create('Parchment DIAL does not point to its branch');
  if FormID(ActualBranch) = FormID(CoreBranch) then
    raise Exception.Create('Parchment DIAL reuses the core branch');

  InfoGroup := ChildGroup(PickerTopic);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 2) then
    raise Exception.Create('Parchment DIAL does not contain two INFOs');
  PickerInfo := InfoInTopicByEditorID(
    PickerTopic,
    'DNT_WG_OpenParchment_Faculty'
  );
  MirabelleInfo := InfoInTopicByEditorID(
    PickerTopic,
    'DNT_WG_OpenParchment_Mirabelle'
  );
  if not Assigned(PickerInfo) or not Assigned(MirabelleInfo) then
    raise Exception.Create('Parchment INFO EditorIDs do not match');
  if GetElementEditValues(PickerInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Parchment INFO prompt does not match');
  if GetElementEditValues(PickerInfo, 'Responses\Response\NAM1') <>
    ParchmentResponse then
    raise Exception.Create('Parchment response does not match');
  if GetElementNativeValues(PickerInfo, 'ENAM\Response Flags') <>
    SilentTerminalResponseFlagsMask then
    raise Exception.Create('Parchment response flags do not match');
  if Assigned(ElementByPath(PickerInfo, 'DNAM')) then
    raise Exception.Create('Parchment INFO unexpectedly uses SharedInfo');
  if Assigned(ElementByPath(PickerInfo, 'Link To')) then
    raise Exception.Create('Parchment INFO unexpectedly links a submenu');

  Conditions := ElementByPath(PickerInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 4) then
    raise Exception.Create('Faculty parchment INFO does not have four conditions');
  AssertCondition(
    PickerInfo,
    0,
    'GetFactionRank',
    RequireSkyrimRecord($0001F259, 'FACT', 'CollegeofWinterholdFaction'),
    GreaterThanOrEqualConditionType,
    3.0
  );
  AssertCondition(
    PickerInfo,
    1,
    'GetIsID',
    RequireSkyrimRecord($0006A152, 'NPC_', 'MGArnielSummon'),
    NotEqualConditionType,
    1.0
  );
  MirabelleBase := RequireSkyrimRecord(
    $0001C1A0,
    'NPC_',
    'MirabelleErvine'
  );
  AssertCondition(
    PickerInfo,
    3,
    'GetIsID',
    MirabelleBase,
    NotEqualConditionType,
    1.0
  );
  AssertCondition(
    PickerInfo,
    2,
    'GetIsID',
    RequireSkyrimRecord($0003B0E4, 'NPC_', 'dunAlftandEndrast'),
    NotEqualConditionType,
    1.0
  );

  VMAD := ElementByPath(PickerInfo, 'VMAD');
  if not Assigned(VMAD) or
    (GetElementNativeValues(VMAD, 'Script Fragments\Flags') <>
      OnBeginFragmentMask) or
    (GetElementEditValues(VMAD, 'Script Fragments\FileName') <>
      'DNT_WizardParchmentFragment') then
    raise Exception.Create('Parchment INFO fragment metadata mismatch');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Parchment INFO does not have one script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardParchmentFragment' then
    raise Exception.Create('Parchment fragment script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 1) then
    raise Exception.Create('Parchment fragment does not have one property');
  AssertProperty(ScriptEntry, 'Picker', PickerQuest);

  if GetElementEditValues(MirabelleInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Mirabelle parchment prompt does not match');
  if GetElementEditValues(MirabelleInfo, 'Responses\Response\NAM1') <>
    MirabelleParchmentResponse then
    raise Exception.Create('Mirabelle parchment response does not match');
  if GetElementNativeValues(MirabelleInfo, 'ENAM\Response Flags') <>
    SilentTerminalResponseFlagsMask then
    raise Exception.Create('Mirabelle parchment response flags do not match');
  if Assigned(ElementByPath(MirabelleInfo, 'DNAM')) then
    raise Exception.Create('Mirabelle parchment unexpectedly uses SharedInfo');
  if Assigned(ElementByPath(MirabelleInfo, 'Link To')) then
    raise Exception.Create('Mirabelle parchment unexpectedly links a submenu');
  Speaker := LinksTo(ElementByPath(MirabelleInfo, 'ANAM'));
  if not Assigned(Speaker) or (FormID(Speaker) <> FormID(MirabelleBase)) then
    raise Exception.Create('Mirabelle parchment speaker does not match');

  Conditions := ElementByPath(MirabelleInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 4) then
    raise Exception.Create('Mirabelle parchment INFO does not have four conditions');
  AssertCondition(
    MirabelleInfo,
    0,
    'GetFactionRank',
    RequireSkyrimRecord($0001F259, 'FACT', 'CollegeofWinterholdFaction'),
    GreaterThanOrEqualConditionType,
    3.0
  );
  AssertCondition(
    MirabelleInfo,
    1,
    'GetIsID',
    RequireSkyrimRecord($0006A152, 'NPC_', 'MGArnielSummon'),
    NotEqualConditionType,
    1.0
  );
  AssertCondition(
    MirabelleInfo,
    2,
    'GetIsID',
    RequireSkyrimRecord($0003B0E4, 'NPC_', 'dunAlftandEndrast'),
    NotEqualConditionType,
    1.0
  );
  AssertCondition(
    MirabelleInfo,
    3,
    'GetIsID',
    MirabelleBase,
    EqualConditionType,
    1.0
  );

  VMAD := ElementByPath(MirabelleInfo, 'VMAD');
  if not Assigned(VMAD) or
    (GetElementNativeValues(VMAD, 'Script Fragments\Flags') <>
      OnBeginFragmentMask) or
    (GetElementEditValues(VMAD, 'Script Fragments\FileName') <>
      'DNT_WizardParchmentFragment') then
    raise Exception.Create('Mirabelle parchment fragment metadata mismatch');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Mirabelle parchment does not have one script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardParchmentFragment' then
    raise Exception.Create('Mirabelle parchment fragment script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 1) then
    raise Exception.Create('Mirabelle parchment fragment does not have one property');
  AssertProperty(ScriptEntry, 'Picker', PickerQuest);
  ReportLines.Add(
    'PASS dialogue -> general faculty plus Mirabelle voice presentation INFO'
  );
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-parchment-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-parchment-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\wizard-parchment-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    AdapterFile := FileByPluginName('DiegeticTravelWizardParchment.esp');
    SkyrimFile := FileByPluginName('Skyrim.esm');
    WizardFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    if not Assigned(AdapterFile) or not Assigned(SkyrimFile) or
      not Assigned(WizardFile) then
      raise Exception.Create('Required parchment audit plugin is missing');

    AuditMasters;
    AuditQuest;
    AuditDialogue;
    ReportLines.Add('PASS wizard parchment-adapter audit complete');
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
