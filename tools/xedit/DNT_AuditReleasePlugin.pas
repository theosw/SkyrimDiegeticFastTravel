unit DNT_AuditReleasePlugin;

uses SysUtils, Classes;

const
  TargetPluginName = 'DiegeticTravel.esp';
  ExpectedMasterCount = 6;
  ExpectedStartGameQuestCount = 17;
  ExpectedOriginQuestCount = 9;

var
  TargetFile, CftoFile: IInterface;
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
