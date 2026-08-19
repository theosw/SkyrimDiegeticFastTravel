unit DNT_AuditReleasePlugin;

uses SysUtils, Classes;

const
  TargetPluginName = 'DiegeticTravel.esp';
  ExpectedMasterCount = 6;
  ExpectedStartGameQuestCount = 17;
  ExpectedOriginQuestCount = 9;
  ParchmentPrompt = 'Could you show me your travel map?';
  ParchmentResponse = 'Of course.';
  OnBeginFragmentMask = $01;
  GoodbyeResponseFlagsMask = $0001;
  SilentTerminalResponseFlagsMask = $0A01;
  MiscDialogueCategory = 7;
  EqualConditionType = $00;
  NotEqualConditionType = $20;
  GreaterThanOrEqualConditionType = $60;

var
  TargetFile, SkyrimFile, CftoFile: IInterface;
  ReportLines: TStringList;
  StatusPath, ErrorPath, ReportPath, AuditStage: string;

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

function ResolveRecordByEditorID(
  PluginFile: IInterface;
  const RecordSignature, EditorIDValue: string
): IInterface;
var
  GroupRecord, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  GroupRecord := GroupBySignature(PluginFile, RecordSignature);
  if Assigned(GroupRecord) then
    for i := 0 to Pred(ElementCount(GroupRecord)) do begin
      Candidate := ElementByIndex(GroupRecord, i);
      if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
        Result := Candidate;
        Exit;
      end;
    end;
  raise Exception.Create('Could not resolve ' + EditorIDValue);
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

function ScriptByName(RecordElement: IInterface; const Value: string): IInterface;
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
    if GetElementEditValues(Candidate, 'ScriptName') = Value then begin
      Result := Candidate;
      Exit;
    end;
  end;
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
      if (Signature(CandidateInfo) = 'INFO') and
        (FormID(CandidateInfo) = FormID(InfoRecord)) then begin
        Result := TopicRecord;
        Exit;
      end;
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
  if not Assigned(ConditionData) or
    (GetElementEditValues(ConditionData, 'Function') <> FunctionName) then
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

procedure AssertInfoFragment(
  InfoRecord, PickerQuest: IInterface;
  const LabelValue: string
);
var
  VMAD, Scripts, ScriptEntry, Properties, Fragments, Fragment: IInterface;
begin
  VMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(VMAD) or
    (GetElementNativeValues(VMAD, 'Script Fragments\Flags') <>
      OnBeginFragmentMask) or
    (GetElementEditValues(VMAD, 'Script Fragments\FileName') <>
      'DNT_WizardParchmentFragment') then
    raise Exception.Create(LabelValue + ' fragment metadata mismatch');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create(LabelValue + ' does not have one script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardParchmentFragment' then
    raise Exception.Create(LabelValue + ' fragment script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 1) then
    raise Exception.Create(LabelValue + ' fragment property count mismatch');
  AssertProperty(ScriptEntry, 'Picker', PickerQuest);
  Fragments := ElementByPath(VMAD, 'Script Fragments\Fragments');
  if not Assigned(Fragments) or (ElementCount(Fragments) <> 1) then
    raise Exception.Create(LabelValue + ' fragment entry count mismatch');
  Fragment := ElementByIndex(Fragments, 0);
  if (GetElementEditValues(Fragment, 'ScriptName') <>
      'DNT_WizardParchmentFragment') or
    (GetElementEditValues(Fragment, 'FragmentName') <> 'Fragment_0') then
    raise Exception.Create(LabelValue + ' fragment entry does not match');
end;

procedure AssertSharedResponse(
  InfoRecord: IInterface;
  const EditorIDValue: string
);
var
  ExpectedSharedInfo, SharedInfo, Responses, SharedInfoTopic,
    SharedInfoGroup, CandidateInfo: IInterface;
  i: Integer;
  DonorIsTopicChild: Boolean;
begin
  ExpectedSharedInfo := RequireRecord(SkyrimFile, $000DBA22, 'INFO');
  if GetElementEditValues(ExpectedSharedInfo, 'EDID') <> 'OfCourse' then
    raise Exception.Create(EditorIDValue + ' donor EditorID does not match');
  SharedInfo := LinksTo(ElementByPath(InfoRecord, 'DNAM'));
  if not Assigned(SharedInfo) or
    (FormID(SharedInfo) <> FormID(ExpectedSharedInfo)) then
    raise Exception.Create(EditorIDValue + ' SharedInfo donor does not match');
  SharedInfoTopic := RequireRecord(SkyrimFile, $0001F319, 'DIAL');
  if GetElementEditValues(SharedInfoTopic, 'EDID') <>
    'DialogueGenericSharedInfo' then
    raise Exception.Create(EditorIDValue + ' donor topic EditorID mismatch');
  if GetElementNativeValues(SharedInfoTopic, 'DATA\Category') <>
    MiscDialogueCategory then
    raise Exception.Create(EditorIDValue + ' donor topic is not Misc dialogue');
  if GetElementEditValues(SharedInfoTopic, 'SNAM') <> 'SharedInfo' then
    raise Exception.Create(EditorIDValue + ' donor topic is not SharedInfo');
  SharedInfoGroup := ChildGroup(SharedInfoTopic);
  DonorIsTopicChild := False;
  if Assigned(SharedInfoGroup) then
    for i := 0 to Pred(ElementCount(SharedInfoGroup)) do begin
      CandidateInfo := ElementByIndex(SharedInfoGroup, i);
      if (Signature(CandidateInfo) = 'INFO') and
        (FormID(CandidateInfo) = FormID(ExpectedSharedInfo)) then begin
        DonorIsTopicChild := True;
        Break;
      end;
    end;
  if not DonorIsTopicChild then
    raise Exception.Create(EditorIDValue + ' donor is not a SharedInfo child');
  Responses := ElementByPath(InfoRecord, 'Responses');
  if Assigned(Responses) and (ElementCount(Responses) > 0) then
    raise Exception.Create(EditorIDValue + ' unexpectedly owns responses');
  if GetElementEditValues(
    ExpectedSharedInfo,
    'Responses\Response\NAM1'
  ) <> ParchmentResponse then
    raise Exception.Create(EditorIDValue + ' donor response text mismatch');
end;

procedure AuditMasters;
var
  Expected: TStringList;
  i: Integer;
begin
  Expected := TStringList.Create;
  try
    Expected.Add('Skyrim.esm');
    Expected.Add('Update.esm');
    Expected.Add('Dawnguard.esm');
    Expected.Add('HearthFires.esm');
    Expected.Add('Dragonborn.esm');
    Expected.Add('CFTO.esp');
    if MasterCount(TargetFile) <> ExpectedMasterCount then
      raise Exception.Create('Release master count mismatch');
    for i := 0 to Pred(Expected.Count) do
      if LowerCase(GetFileName(MasterByIndex(TargetFile, i))) <>
        LowerCase(Expected[i]) then
        raise Exception.Create('Release master order mismatch at ' + IntToStr(i));
    ReportLines.Add('PASS masters=6');
  finally
    Expected.Free;
  end;
end;

procedure AuditHeader;
var
  FileHeader: IInterface;
  NextObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(TargetFile, 0);
  if not Assigned(FileHeader) then
    raise Exception.Create('Release plugin has no TES4 header');
  NextObjectID := GetElementNativeValues(FileHeader, 'HEDR\Next Object ID');
  if (NextObjectID <= $000800) or (NextObjectID > $001000) then
    raise Exception.Create(
      'Release Next Object ID is outside the ESL range: ' +
      IntToHex(NextObjectID, 6)
    );
  if not GetIsESL(TargetFile) then
    raise Exception.Create('Release plugin is not ESL flagged');
  if not CanBeESL(TargetFile) then
    raise Exception.Create('xEdit reports that the release plugin cannot be ESL');
  ReportLines.Add('PASS esl=true');
  ReportLines.Add('PASS next_object_id=0x' + IntToHex(NextObjectID, 6));
end;

procedure RequireQuestScript(const EditorIDValue, ScriptName: string);
var
  QuestRecord: IInterface;
begin
  QuestRecord := ResolveRecordByEditorID(TargetFile, 'QUST', EditorIDValue);
  if (GetElementNativeValues(QuestRecord, 'DNAM\Flags') and 1) = 0 then
    raise Exception.Create(EditorIDValue + ' is not Start Game Enabled');
  if not Assigned(ScriptByName(QuestRecord, ScriptName)) then
    raise Exception.Create(EditorIDValue + ' is missing ' + ScriptName);
end;

procedure AuditQuests;
var
  QuestGroup, QuestRecord, MasterQuest: IInterface;
  EditorIDValue: string;
  i, StartGameCount, OriginCount: Integer;
begin
  QuestGroup := GroupBySignature(TargetFile, 'QUST');
  if not Assigned(QuestGroup) then
    raise Exception.Create('Release plugin has no QUST group');
  StartGameCount := 0;
  OriginCount := 0;
  for i := 0 to Pred(ElementCount(QuestGroup)) do begin
    QuestRecord := ElementByIndex(QuestGroup, i);
    if (GetElementNativeValues(QuestRecord, 'DNAM\Flags') and 1) <> 0 then begin
      MasterQuest := Master(QuestRecord);
      if not Assigned(MasterQuest) or
        ((GetElementNativeValues(MasterQuest, 'DNAM\Flags') and 1) = 0) then
        Inc(StartGameCount);
    end;
    EditorIDValue := GetElementEditValues(QuestRecord, 'EDID');
    if Pos('DNT_Origin_', EditorIDValue) = 1 then begin
      Inc(OriginCount);
      if not Assigned(ScriptByName(QuestRecord, 'DNT_OriginService')) then
        raise Exception.Create(EditorIDValue + ' is missing DNT_OriginService');
    end;
  end;
  if StartGameCount <> ExpectedStartGameQuestCount then
    raise Exception.Create(
      'Start Game Enabled quest count mismatch: ' + IntToStr(StartGameCount)
    );
  if OriginCount <> ExpectedOriginQuestCount then
    raise Exception.Create('Origin quest count mismatch: ' + IntToStr(OriginCount));

  RequireQuestScript('DNT_TravelCoordinatorQuest', 'DNT_TravelCoordinator');
  RequireQuestScript('DNT_WizardTravelQuest', 'DNT_WizardTravelService');
  RequireQuestScript(
    'DNT_WizardParchmentPickerQuest',
    'DNT_WizardParchmentPicker'
  );
  RequireQuestScript(
    'DNT_CarriageParchmentQuest',
    'DNT_CarriageParchmentPicker'
  );
  RequireQuestScript('DNT_BoatHonrichQuest', 'DNT_BoatTravelService');
  RequireQuestScript('DNT_BoatIlinaltaQuest', 'DNT_IlinaltaBoatTravelService');
  RequireQuestScript(
    'DNT_BoatNorthCoastQuest',
    'DNT_NorthCoastBoatTravelService'
  );
  RequireQuestScript(
    'DNT_BoatSolstheimQuest',
    'DNT_SolstheimBoatTravelService'
  );
  ReportLines.Add('PASS start_game_quests=17');
  ReportLines.Add('PASS origin_services=9');
  ReportLines.Add('PASS critical_quest_scripts=8');
end;

procedure AuditWizardParchmentDialogue;
var
  PickerQuest, PickerQuestScript, PickerQuestProperties, PickerTopic,
    PickerBranch, TopicQuest, BranchQuest, StartingTopic, InfoGroup,
    FacultyInfo, MirabelleInfo, MirabelleBase, Speaker, Conditions,
    CollegeFaction, ArnielSummon, Endrast: IInterface;
begin
  PickerQuest := ResolveRecordByEditorID(
    TargetFile,
    'QUST',
    'DNT_WizardParchmentPickerQuest'
  );
  PickerQuestScript := ScriptByName(
    PickerQuest,
    'DNT_WizardParchmentPicker'
  );
  if not Assigned(PickerQuestScript) then
    raise Exception.Create('Wizard parchment quest script is missing');
  PickerQuestProperties := ElementByPath(PickerQuestScript, 'Properties');
  if not Assigned(PickerQuestProperties) or
    (ElementCount(PickerQuestProperties) <> 1) then
    raise Exception.Create(
      'Wizard parchment quest must expose only its Service property'
    );
  AssertProperty(
    PickerQuestScript,
    'Service',
    ResolveRecordByEditorID(TargetFile, 'QUST', 'DNT_WizardTravelQuest')
  );
  if Assigned(PropertyObject(PickerQuestScript, 'MirabelleBase')) then
    raise Exception.Create('Obsolete MirabelleBase property is still present');

  FacultyInfo := FindInfoByEditorID(
    TargetFile,
    'DNT_WG_OpenParchment_Faculty'
  );
  MirabelleInfo := FindInfoByEditorID(
    TargetFile,
    'DNT_WG_OpenParchment_Mirabelle'
  );
  if not Assigned(FacultyInfo) or not Assigned(MirabelleInfo) then
    raise Exception.Create('Wizard parchment INFO split is incomplete');
  PickerTopic := TopicContainingInfo(TargetFile, FacultyInfo);
  if not Assigned(PickerTopic) or
    (GetElementEditValues(PickerTopic, 'EDID') <> 'DNT_WG_OpenParchment') then
    raise Exception.Create('Wizard parchment topic does not match');
  if FormID(TopicContainingInfo(TargetFile, MirabelleInfo)) <>
    FormID(PickerTopic) then
    raise Exception.Create('Mirabelle INFO is not in the parchment topic');
  if (GetElementEditValues(PickerTopic, 'FULL') <> ParchmentPrompt) or
    (GetElementNativeValues(PickerTopic, 'TIFC') <> 2) then
    raise Exception.Create('Wizard parchment topic prompt/count mismatch');
  InfoGroup := ChildGroup(PickerTopic);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 2) then
    raise Exception.Create('Wizard parchment topic must contain two INFOs');

  PickerBranch := LinksTo(ElementByPath(PickerTopic, 'BNAM'));
  if not Assigned(PickerBranch) or
    (GetElementEditValues(PickerBranch, 'EDID') <>
      'DNT_WG_OpenParchmentBranch') then
    raise Exception.Create('Wizard parchment branch does not match');
  TopicQuest := LinksTo(ElementByPath(PickerTopic, 'QNAM'));
  BranchQuest := LinksTo(ElementByPath(PickerBranch, 'QNAM'));
  StartingTopic := LinksTo(ElementByPath(PickerBranch, 'SNAM'));
  if not Assigned(TopicQuest) or
    (FormID(TopicQuest) <> FormID(PickerQuest)) or
    not Assigned(BranchQuest) or
    (FormID(BranchQuest) <> FormID(PickerQuest)) or
    not Assigned(StartingTopic) or
    (FormID(StartingTopic) <> FormID(PickerTopic)) then
    raise Exception.Create('Wizard parchment topic/branch wiring mismatch');
  if (GetElementNativeValues(PickerBranch, 'TNAM') <> 0) or
    (GetElementNativeValues(PickerBranch, 'DNAM') <> 1) then
    raise Exception.Create('Wizard parchment branch flags do not match');

  if GetElementEditValues(FacultyInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Faculty parchment prompt does not match');
  if GetElementNativeValues(FacultyInfo, 'ENAM\Response Flags') <>
    GoodbyeResponseFlagsMask then
    raise Exception.Create('Faculty parchment flags are not terminal voiced');
  if Assigned(ElementByPath(FacultyInfo, 'Link To')) then
    raise Exception.Create('Faculty parchment unexpectedly links a submenu');
  AssertSharedResponse(FacultyInfo, 'DNT_WG_OpenParchment_Faculty');

  MirabelleBase := RequireRecord(SkyrimFile, $0001C1A0, 'NPC_');
  if GetElementEditValues(MirabelleBase, 'EDID') <> 'MirabelleErvine' then
    raise Exception.Create('Mirabelle base record does not match');
  if GetElementEditValues(MirabelleInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Mirabelle parchment prompt does not match');
  if Assigned(ElementByPath(MirabelleInfo, 'DNAM')) then
    raise Exception.Create('Mirabelle parchment unexpectedly uses SharedInfo');
  if GetElementEditValues(
    MirabelleInfo,
    'Responses\Response\NAM1'
  ) <> ParchmentResponse then
    raise Exception.Create('Mirabelle parchment subtitle does not match');
  if not Assigned(ElementByPath(MirabelleInfo, 'Responses')) or
    (ElementCount(ElementByPath(MirabelleInfo, 'Responses')) <> 1) then
    raise Exception.Create('Mirabelle parchment must own one response');
  if GetElementNativeValues(MirabelleInfo, 'ENAM\Response Flags') <>
    SilentTerminalResponseFlagsMask then
    raise Exception.Create('Mirabelle parchment flags are not subtitle-only');
  if Assigned(ElementByPath(MirabelleInfo, 'Link To')) then
    raise Exception.Create('Mirabelle parchment unexpectedly links a submenu');
  Speaker := LinksTo(ElementByPath(MirabelleInfo, 'ANAM'));
  if not Assigned(Speaker) or
    (FormID(Speaker) <> FormID(MirabelleBase)) then
    raise Exception.Create('Mirabelle parchment exact speaker does not match');

  CollegeFaction := RequireRecord(SkyrimFile, $0001F259, 'FACT');
  ArnielSummon := RequireRecord(SkyrimFile, $0006A152, 'NPC_');
  Endrast := RequireRecord(SkyrimFile, $0003B0E4, 'NPC_');
  Conditions := ElementByPath(FacultyInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 4) then
    raise Exception.Create('Faculty parchment condition count mismatch');
  AssertCondition(FacultyInfo, 0, 'GetFactionRank', CollegeFaction,
    GreaterThanOrEqualConditionType, 3.0);
  AssertCondition(FacultyInfo, 1, 'GetIsID', ArnielSummon,
    NotEqualConditionType, 1.0);
  AssertCondition(FacultyInfo, 2, 'GetIsID', Endrast,
    NotEqualConditionType, 1.0);
  AssertCondition(FacultyInfo, 3, 'GetIsID', MirabelleBase,
    NotEqualConditionType, 1.0);
  Conditions := ElementByPath(MirabelleInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 4) then
    raise Exception.Create('Mirabelle parchment condition count mismatch');
  AssertCondition(MirabelleInfo, 0, 'GetFactionRank', CollegeFaction,
    GreaterThanOrEqualConditionType, 3.0);
  AssertCondition(MirabelleInfo, 1, 'GetIsID', ArnielSummon,
    NotEqualConditionType, 1.0);
  AssertCondition(MirabelleInfo, 2, 'GetIsID', Endrast,
    NotEqualConditionType, 1.0);
  AssertCondition(MirabelleInfo, 3, 'GetIsID', MirabelleBase,
    EqualConditionType, 1.0);

  AssertInfoFragment(FacultyInfo, PickerQuest, 'Faculty parchment INFO');
  AssertInfoFragment(MirabelleInfo, PickerQuest, 'Mirabelle parchment INFO');
  ReportLines.Add(
    'PASS wizard_parchment_dialogue=faculty_shared_ofcourse_mirabelle_subtitle'
  );
end;

function GateConditionCount(
  InfoRecord, GateGlobal: IInterface;
  ValidateShape: Boolean
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
    if not Assigned(ParameterRecord) or
      (FormID(ParameterRecord) <> FormID(GateGlobal)) then
      Continue;
    Inc(Result);
    if ValidateShape then begin
      if GetElementNativeValues(ConditionData, 'Type') <> 0 then
        raise Exception.Create('Legacy dialogue gate is not an equality test');
      if Abs(GetElementNativeValues(
        ConditionData,
        'Comparison Value - Float'
      ) - 1.0) > 0.001 then
        raise Exception.Create('Legacy dialogue gate does not compare with one');
      if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
        raise Exception.Create('Legacy dialogue gate is not subject-scoped');
    end;
  end;
end;

procedure AssertGatedInfo(
  InfoRecord, GateGlobal: IInterface;
  const LabelValue: string
);
var
  Winner: IInterface;
begin
  Winner := WinningOverride(InfoRecord);
  if not Assigned(Winner) then
    raise Exception.Create(LabelValue + ' has no winning override');
  if LowerCase(GetFileName(GetFile(Winner))) <>
    LowerCase(TargetPluginName) then
    raise Exception.Create(LabelValue + ' winner is not the consolidated plugin');
  if GateConditionCount(Winner, GateGlobal, True) <> 1 then
    raise Exception.Create(LabelValue + ' does not have exactly one gate');
end;

procedure AssertUngatedInfo(
  GateGlobal: IInterface;
  const EditorIDValue: string
);
var
  InfoRecord: IInterface;
begin
  InfoRecord := FindInfoByEditorID(TargetFile, EditorIDValue);
  if not Assigned(InfoRecord) then
    raise Exception.Create('Could not resolve parchment INFO ' + EditorIDValue);
  if GateConditionCount(InfoRecord, GateGlobal, False) <> 0 then
    raise Exception.Create(EditorIDValue + ' was incorrectly gated');
end;

function AuditFerryTopic(
  TopicObjectID: Cardinal;
  GateGlobal: IInterface;
  const LabelValue: string
): Integer;
var
  SourceTopic, InfoGroup, SourceInfo: IInterface;
  i: Integer;
begin
  Result := 0;
  SourceTopic := RequireRecord(CftoFile, TopicObjectID, 'DIAL');
  InfoGroup := ChildGroup(SourceTopic);
  if not Assigned(InfoGroup) then
    raise Exception.Create(LabelValue + ' has no INFO child group');
  for i := 0 to Pred(ElementCount(InfoGroup)) do begin
    SourceInfo := ElementByIndex(InfoGroup, i);
    if Signature(SourceInfo) <> 'INFO' then
      Continue;
    AssertGatedInfo(SourceInfo, GateGlobal, LabelValue);
    Inc(Result);
  end;
  if Result = 0 then
    raise Exception.Create(LabelValue + ' contains no INFO records');
end;

procedure AuditLegacyDialogueGate;
var
  GateGlobal, WizardHub: IInterface;
  FerryCount: Integer;
begin
  GateGlobal := ResolveRecordByEditorID(
    TargetFile,
    'GLOB',
    'DNT_ShowLegacyTravelDialogue'
  );
  if GetFile(GateGlobal) <> TargetFile then
    raise Exception.Create('Legacy dialogue global is not a local record');
  if Abs(GetElementNativeValues(GateGlobal, 'FLTV')) > 0.001 then
    raise Exception.Create('Legacy dialogue global does not default to zero');

  WizardHub := FindInfoByEditorID(TargetFile, 'DNT_WG_Request_Phinis');
  if not Assigned(WizardHub) then
    raise Exception.Create('Could not resolve obsolete College wizard hub');
  AssertGatedInfo(WizardHub, GateGlobal, 'obsolete College wizard hub');

  AssertGatedInfo(
    RequireRecord(CftoFile, $09D8C7, 'INFO'),
    GateGlobal,
    'CFTO paid carriage request'
  );
  AssertGatedInfo(
    RequireRecord(CftoFile, $0DA634, 'INFO'),
    GateGlobal,
    'CFTO free carriage request'
  );

  FerryCount := 0;
  FerryCount := FerryCount + AuditFerryTopic(
    $019DC4,
    GateGlobal,
    'CFTO Lake Honrich request'
  );
  FerryCount := FerryCount + AuditFerryTopic(
    $02E1DD,
    GateGlobal,
    'CFTO Lake Ilinalta request'
  );
  FerryCount := FerryCount + AuditFerryTopic(
    $00AA0E,
    GateGlobal,
    'CFTO north-coast request'
  );
  FerryCount := FerryCount + AuditFerryTopic(
    $0383FE,
    GateGlobal,
    'CFTO Solstheim request'
  );

  AssertUngatedInfo(GateGlobal, 'DNT_WG_OpenParchment_Faculty');
  AssertUngatedInfo(GateGlobal, 'DNT_CarriageParchmentPaidInfo');
  AssertUngatedInfo(GateGlobal, 'DNT_CarriageParchmentFreeInfo');
  AssertUngatedInfo(GateGlobal, 'DNT_BoatHonrichParchmentInfo');
  AssertUngatedInfo(GateGlobal, 'DNT_BoatIlinaltaParchmentInfo');
  AssertUngatedInfo(GateGlobal, 'DNT_BoatNorthCoastParchmentInfo');
  AssertUngatedInfo(GateGlobal, 'DNT_BoatSolstheimParchmentInfo');

  ReportLines.Add('PASS legacy_dialogue_global_default=0');
  ReportLines.Add('PASS legacy_wizard_infos=1');
  ReportLines.Add('PASS legacy_carriage_infos=2');
  ReportLines.Add('PASS legacy_ferry_infos=' + IntToStr(FerryCount));
  ReportLines.Add('PASS parchment_infos_ungated=7');
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\release-package-xedit-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\release-package-xedit-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\release-package-xedit-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    AuditStage := 'plugin lookup';
    TargetFile := FileByPluginName(TargetPluginName);
    if not Assigned(TargetFile) then
      raise Exception.Create('Consolidated release plugin is not loaded');
    AuditStage := 'masters';
    AuditMasters;
    AuditStage := 'header';
    AuditHeader;
    AuditStage := 'quests';
    AuditQuests;
    AuditStage := 'wizard parchment dialogue';
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');
    AuditWizardParchmentDialogue;
    AuditStage := 'legacy dialogue gate';
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(CftoFile) then
      raise Exception.Create('CFTO is not loaded');
    AuditLegacyDialogueGate;
    ReportLines.SaveToFile(ReportPath);
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Consolidated release audit passed');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, AuditStage + ': ' + E.Message);
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
