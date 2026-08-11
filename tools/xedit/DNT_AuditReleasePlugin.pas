unit DNT_AuditReleasePlugin;

uses SysUtils, Classes;

const
  TargetPluginName = 'DiegeticTravel.esp';
  ExpectedMasterCount = 6;
  ExpectedStartGameQuestCount = 18;
  ExpectedOriginQuestCount = 9;

var
  TargetFile: IInterface;
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

  RequireQuestScript('DNT_RouteServiceQuest', 'DNT_RouteService');
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
  ReportLines.Add('PASS start_game_quests=18');
  ReportLines.Add('PASS origin_services=9');
  ReportLines.Add('PASS critical_quest_scripts=9');
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
