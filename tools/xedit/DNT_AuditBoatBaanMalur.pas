unit DNT_AuditBoatBaanMalur;

uses SysUtils, Classes;

const
  BoatPrompt = 'Could you show me your route map?';
  NativeDialogueGateEditorID = 'DNT_ShowBaanMalurNativeDialogue';
  ProviderListEditorID = 'DNT_BaanMalurBoatProviders';
  OnEndFragmentMask = $02;
  GoodbyeResponseFlagsMask = $0001;
  EqualConditionType = $00;
  OrEqualConditionType = $01;

var
  BoatFile, JourneyFile: IInterface;
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

function FirstTopicInfo(TopicRecord: IInterface): IInterface;
var
  InfoGroup: IInterface;
begin
  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) = 0) then
    raise Exception.Create('Topic has no INFO');
  Result := ElementByIndex(InfoGroup, 0);
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
    ExpectedMasters.Add('ccBGSSSE001-Fish.esm');
    ExpectedMasters.Add('ccBGSSSE037-Curios.esl');
    ExpectedMasters.Add('Journey to Baan Malur.esp');
    if MasterCount(BoatFile) <> ExpectedMasters.Count then
      raise Exception.Create('Baan Malur plugin master count does not match');
    for i := 0 to Pred(ExpectedMasters.Count) do
      if LowerCase(GetFileName(MasterByIndex(BoatFile, i))) <>
        LowerCase(ExpectedMasters[i]) then
        raise Exception.Create('Baan Malur plugin master order mismatch');
    ReportLines.Add('PASS masters=8');
  finally
    ExpectedMasters.Free;
  end;
end;

procedure AuditESLState;
var
  FileHeader: IInterface;
  NextObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(BoatFile, 0);
  if not Assigned(FileHeader) then
    raise Exception.Create('Baan Malur plugin has no TES4 header');
  NextObjectID := GetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID'
  );
  if (NextObjectID <= $000800) or (NextObjectID > $001000) then
    raise Exception.Create(
      'Baan Malur Next Object ID is outside the ESL range: ' +
      IntToHex(NextObjectID, 6)
    );
  if not GetIsESL(BoatFile) then
    raise Exception.Create('Baan Malur add-on is not ESL flagged');
  if not CanBeESL(BoatFile) then
    raise Exception.Create('xEdit reports that the Baan Malur add-on cannot be ESL');
  ReportLines.Add('PASS esl=true');
  ReportLines.Add('PASS next_object_id=0x' + IntToHex(NextObjectID, 6));
end;

procedure AssertCaptainCondition(
  InfoRecord: IInterface;
  Index, ExpectedType: Integer;
  ExpectedCaptain: IInterface
);
var
  Conditions, ConditionData, ActualCaptain: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (Index >= ElementCount(Conditions)) then
    raise Exception.Create('Missing captain condition ' + IntToStr(Index));
  ConditionData := ElementByPath(ElementByIndex(Conditions, Index), 'CTDA');
  if GetElementEditValues(ConditionData, 'Function') <> 'GetIsID' then
    raise Exception.Create('Captain condition function mismatch');
  if GetElementNativeValues(ConditionData, 'Type') <> ExpectedType then
    raise Exception.Create('Captain condition OR layout mismatch');
  if Abs(GetElementNativeValues(
    ConditionData,
    'Comparison Value - Float'
  ) - 1.0) > 0.001 then
    raise Exception.Create('Captain condition comparison mismatch');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create('Captain condition is not subject-scoped');
  ActualCaptain := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ActualCaptain) or
    (FormID(ActualCaptain) <> FormID(ExpectedCaptain)) then
    raise Exception.Create('Captain condition target mismatch');
end;

procedure AssertProviderList(
  ProviderList, RavenCaptain, BaanCaptain, CormarisCaptain: IInterface
);
var
  Entries, ActualRecord: IInterface;
  ExpectedRecords: array[0..2] of IInterface;
  i: Integer;
begin
  ExpectedRecords[0] := RavenCaptain;
  ExpectedRecords[1] := BaanCaptain;
  ExpectedRecords[2] := CormarisCaptain;
  Entries := ElementByPath(ProviderList, 'FormIDs');
  if not Assigned(Entries) or (ElementCount(Entries) <> 3) then
    raise Exception.Create('Baan Malur provider list must contain three actors');
  for i := 0 to 2 do begin
    ActualRecord := LinksTo(ElementByIndex(Entries, i));
    if not Assigned(ActualRecord) or
      (FormID(ActualRecord) <> FormID(ExpectedRecords[i])) then
      raise Exception.Create('Baan Malur provider list order mismatch');
  end;
end;

procedure AssertNativeGateCondition(
  InfoRecord: IInterface;
  Index: Integer;
  const ExpectedFunction: string;
  ExpectedType: Integer;
  ExpectedComparison: Double;
  ExpectedParameter: IInterface
);
var
  Conditions, ConditionData, ActualParameter: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (Index >= ElementCount(Conditions)) then
    raise Exception.Create('Missing native fallback condition ' + IntToStr(Index));
  ConditionData := ElementByPath(ElementByIndex(Conditions, Index), 'CTDA');
  if GetElementEditValues(ConditionData, 'Function') <> ExpectedFunction then
    raise Exception.Create('Native fallback condition function mismatch');
  if GetElementNativeValues(ConditionData, 'Type') <> ExpectedType then
    raise Exception.Create('Native fallback condition OR layout mismatch');
  if Abs(GetElementNativeValues(
    ConditionData,
    'Comparison Value - Float'
  ) - ExpectedComparison) > 0.001 then
    raise Exception.Create('Native fallback condition comparison mismatch');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create('Native fallback condition is not subject-scoped');
  ActualParameter := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ActualParameter) or
    (FormID(ActualParameter) <> FormID(ExpectedParameter)) then
    raise Exception.Create('Native fallback condition parameter mismatch');
end;

procedure AuditNativeDialogueGate;
var
  GateGlobal, ProviderList, SourceTopic, SourceInfo, Winner,
    SourceConditions, WinnerConditions, SourceConditionData,
    WinnerConditionData, SourceParameter, WinnerParameter,
    RavenCaptain, BaanCaptain, CormarisCaptain: IInterface;
begin
  GateGlobal := RequireRecordByEditorID(
    BoatFile,
    'GLOB',
    NativeDialogueGateEditorID
  );
  if Abs(GetElementNativeValues(GateGlobal, 'FLTV')) > 0.001 then
    raise Exception.Create('Baan Malur native-dialogue gate must default to zero');

  ProviderList := RequireRecordByEditorID(
    BoatFile,
    'FLST',
    ProviderListEditorID
  );
  RavenCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'RavenRockSailorCaptain'
  );
  BaanCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'BaanSailorCaptain'
  );
  CormarisCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'CormarisSailorCaptain'
  );
  AssertProviderList(
    ProviderList,
    RavenCaptain,
    BaanCaptain,
    CormarisCaptain
  );

  SourceTopic := RequireRecordByEditorID(
    JourneyFile,
    'DIAL',
    'SOMRFerrySystemGreeting'
  );
  SourceInfo := FirstTopicInfo(SourceTopic);
  Winner := WinningOverride(SourceInfo);
  if not Assigned(Winner) or (GetFile(Winner) <> BoatFile) then
    raise Exception.Create('Baan Malur add-on does not win the native greeting');

  SourceConditions := ElementByPath(SourceInfo, 'Conditions');
  WinnerConditions := ElementByPath(Winner, 'Conditions');
  if not Assigned(SourceConditions) or (ElementCount(SourceConditions) <> 1) or
    not Assigned(WinnerConditions) or (ElementCount(WinnerConditions) <> 3) then
    raise Exception.Create('Native greeting must preserve one source condition and add two gates');
  SourceConditionData := ElementByPath(
    ElementByIndex(SourceConditions, 0),
    'CTDA'
  );
  WinnerConditionData := ElementByPath(
    ElementByIndex(WinnerConditions, 0),
    'CTDA'
  );
  if GetElementEditValues(SourceConditionData, 'Function') <>
    GetElementEditValues(WinnerConditionData, 'Function') then
    raise Exception.Create('Native greeting source condition function changed');
  if GetElementNativeValues(SourceConditionData, 'Type') <>
    GetElementNativeValues(WinnerConditionData, 'Type') then
    raise Exception.Create('Native greeting source condition type changed');
  if GetElementNativeValues(SourceConditionData, 'Run On') <>
    GetElementNativeValues(WinnerConditionData, 'Run On') then
    raise Exception.Create('Native greeting source condition scope changed');
  if Abs(GetElementNativeValues(
    SourceConditionData,
    'Comparison Value - Float'
  ) - GetElementNativeValues(
    WinnerConditionData,
    'Comparison Value - Float'
  )) > 0.001 then
    raise Exception.Create('Native greeting source comparison changed');
  SourceParameter := LinksTo(ElementByPath(SourceConditionData, 'Parameter #1'));
  WinnerParameter := LinksTo(ElementByPath(WinnerConditionData, 'Parameter #1'));
  if not Assigned(SourceParameter) or not Assigned(WinnerParameter) or
    (FormID(SourceParameter) <> FormID(WinnerParameter)) then
    raise Exception.Create('Native greeting source parameter changed');

  AssertNativeGateCondition(
    Winner,
    1,
    'GetGlobalValue',
    OrEqualConditionType,
    1.0,
    GateGlobal
  );
  AssertNativeGateCondition(
    Winner,
    2,
    'IsInList',
    EqualConditionType,
    0.0,
    ProviderList
  );
  if GetElementEditValues(Winner, 'Responses\Response\NAM1') <>
    GetElementEditValues(SourceInfo, 'Responses\Response\NAM1') then
    raise Exception.Create('Native greeting response changed');

  ReportLines.Add(
    'PASS native_dialogue_gate=provider_scoped_default_off_restorable'
  );
end;

procedure AuditDialogue(QuestRecord: IInterface);
var
  TopicRecord, BranchRecord, InfoRecord, SourceGreetingInfo,
    RavenCaptain, BaanCaptain, CormarisCaptain, FragmentScript,
    Conditions, Fragments, Fragment: IInterface;
begin
  TopicRecord := RequireRecordByEditorID(
    BoatFile,
    'DIAL',
    'DNT_BaanMalurBoatParchmentTopic'
  );
  BranchRecord := RequireRecordByEditorID(
    BoatFile,
    'DLBR',
    'DNT_BaanMalurBoatParchmentBranch'
  );
  if GetElementEditValues(TopicRecord, 'FULL') <> BoatPrompt then
    raise Exception.Create('Baan Malur prompt mismatch');
  if GetElementNativeValues(TopicRecord, 'TIFC') <> 1 then
    raise Exception.Create('Baan Malur INFO count mismatch');
  AssertLinked(TopicRecord, 'QNAM', 'Topic quest', QuestRecord);
  AssertLinked(TopicRecord, 'BNAM', 'Topic branch', BranchRecord);
  AssertLinked(BranchRecord, 'QNAM', 'Branch quest', QuestRecord);
  AssertLinked(BranchRecord, 'SNAM', 'Branch start topic', TopicRecord);

  InfoRecord := FirstTopicInfo(TopicRecord);
  if GetElementEditValues(InfoRecord, 'EDID') <>
    'DNT_BaanMalurBoatParchmentInfo' then
    raise Exception.Create('Baan Malur INFO EditorID mismatch');
  if GetElementEditValues(InfoRecord, 'RNAM') <> BoatPrompt then
    raise Exception.Create('Baan Malur INFO prompt mismatch');
  if GetElementNativeValues(InfoRecord, 'ENAM\Response Flags') <>
    GoodbyeResponseFlagsMask then
    raise Exception.Create('Baan Malur INFO must be Goodbye');

  SourceGreetingInfo := FirstTopicInfo(RequireRecordByEditorID(
    JourneyFile,
    'DIAL',
    'SOMRFerrySystemGreeting'
  ));
  AssertLinked(InfoRecord, 'DNAM', 'Shared response', SourceGreetingInfo);

  RavenCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'RavenRockSailorCaptain'
  );
  BaanCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'BaanSailorCaptain'
  );
  CormarisCaptain := RequireRecordByEditorID(
    JourneyFile,
    'NPC_',
    'CormarisSailorCaptain'
  );
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 3) then
    raise Exception.Create('Baan Malur INFO must have three captain conditions');
  AssertCaptainCondition(InfoRecord, 0, 1, RavenCaptain);
  AssertCaptainCondition(InfoRecord, 1, 1, BaanCaptain);
  AssertCaptainCondition(InfoRecord, 2, 0, CormarisCaptain);

  FragmentScript := ScriptByName(
    InfoRecord,
    'DNT_BaanMalurBoatParchmentFragment'
  );
  if not Assigned(FragmentScript) then
    raise Exception.Create('Baan Malur INFO fragment script is missing');
  if FormID(PropertyObject(FragmentScript, 'Picker')) <>
    FormID(QuestRecord) then
    raise Exception.Create('Baan Malur fragment Picker mismatch');
  if GetElementEditValues(InfoRecord, 'VMAD\Script Fragments\FileName') <>
    'DNT_BaanMalurBoatParchmentFragment' then
    raise Exception.Create('Baan Malur fragment filename mismatch');
  if GetElementNativeValues(InfoRecord, 'VMAD\Script Fragments\Flags') <>
    OnEndFragmentMask then
    raise Exception.Create('Baan Malur fragment must run on end');
  Fragments := ElementByPath(
    InfoRecord,
    'VMAD\Script Fragments\Fragments'
  );
  if not Assigned(Fragments) or (ElementCount(Fragments) <> 1) then
    raise Exception.Create('Baan Malur fragment count mismatch');
  Fragment := ElementByIndex(Fragments, 0);
  if (GetElementEditValues(Fragment, 'ScriptName') <>
    'DNT_BaanMalurBoatParchmentFragment') or
    (GetElementEditValues(Fragment, 'FragmentName') <> 'Fragment_0') then
    raise Exception.Create('Baan Malur fragment binding mismatch');
  ReportLines.Add('PASS dialogue=three_public_captains_shared_voice_goodbye_on_end');
end;

function Initialize: Integer;
var
  QuestRecord, SourceQuest, ServiceScript, PickerScript: IInterface;
  SourceQuestFlags: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\boat-baan-malur-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\boat-baan-malur-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-baan-malur-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    BoatFile := FileByPluginName('DiegeticTravelBoatBaanMalur.esp');
    JourneyFile := FileByPluginName('Journey to Baan Malur.esp');
    if not Assigned(BoatFile) or not Assigned(JourneyFile) then
      raise Exception.Create('Required Baan Malur audit plugin is missing');

    AuditMasters;
    AuditESLState;
    SourceQuest := RequireRecordByEditorID(
      JourneyFile,
      'QUST',
      'SOMRFerrySystemMain'
    );
    SourceQuestFlags := GetElementNativeValues(SourceQuest, 'DNAM\Flags');
    if (SourceQuestFlags and 8) = 0 then
      raise Exception.Create('Journey ferry quest does not allow repeated stages');
    ReportLines.Add('PASS source_quest=allow_repeated_stages');
    QuestRecord := RequireRecordByEditorID(
      BoatFile,
      'QUST',
      'DNT_BaanMalurBoatQuest'
    );
    if GetElementNativeValues(QuestRecord, 'DNAM\Flags') <> 1 then
      raise Exception.Create('Baan Malur quest is not Start Game Enabled');
    if GetElementNativeValues(QuestRecord, 'DNAM\Priority') <> 60 then
      raise Exception.Create('Baan Malur quest priority mismatch');
    ServiceScript := ScriptByName(
      QuestRecord,
      'DNT_BaanMalurBoatTravelService'
    );
    PickerScript := ScriptByName(
      QuestRecord,
      'DNT_BaanMalurBoatParchmentPicker'
    );
    if not Assigned(ServiceScript) or not Assigned(PickerScript) then
      raise Exception.Create('Baan Malur quest script wiring is incomplete');
    if FormID(PropertyObject(PickerScript, 'Service')) <>
      FormID(QuestRecord) then
      raise Exception.Create('Baan Malur picker Service mismatch');
    ReportLines.Add(
      'QUEST_FIXED_FORM_ID=' + IntToHex(FixedFormID(QuestRecord), 8)
    );
    ReportLines.Add('PASS quest=start_game_enabled_priority_60');

    AuditDialogue(QuestRecord);
    AuditNativeDialogueGate;
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
