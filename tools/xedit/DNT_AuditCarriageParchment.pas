unit DNT_AuditCarriageParchment;

uses SysUtils, Classes;

const
  MapPrompt = 'Could you show me your route map?';

var
  AdapterFile, CoreFile, SkyrimFile: IInterface;
  ReportLines: TStringList;
  StatusPath, ErrorPath, ReportPath, AuditStage: string;

procedure WriteTextFile(const Path, TextValue: string);
var Lines: TStringList;
begin
  Lines := TStringList.Create;
  try Lines.Text := TextValue; Lines.SaveToFile(Path); finally Lines.Free; end;
end;

function FileByPluginName(const PluginName: string): IInterface;
var i: Integer;
begin
  Result := nil;
  for i := 0 to Pred(FileCount) do
    if LowerCase(GetFileName(FileByIndex(i))) = LowerCase(PluginName) then begin
      Result := FileByIndex(i); Exit;
    end;
end;

function ResolveRecordByEditorID(
  PluginFile: IInterface;
  const RecordSignature, EditorIDValue: string
): IInterface;
var GroupRecord, Candidate: IInterface; i: Integer;
begin
  Result := nil;
  GroupRecord := GroupBySignature(PluginFile, RecordSignature);
  if Assigned(GroupRecord) then
    for i := 0 to Pred(ElementCount(GroupRecord)) do begin
      Candidate := ElementByIndex(GroupRecord, i);
      if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
        Result := Candidate; Exit;
      end;
    end;
  raise Exception.Create('Could not resolve ' + EditorIDValue);
end;

function ResolveRecordByObjectID(
  PluginFile: IInterface;
  ObjectID: Cardinal
): IInterface;
var FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID := (MasterCount(PluginFile) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
end;

function ScriptByName(RecordElement: IInterface; const Value: string): IInterface;
var Scripts, Candidate: IInterface; i: Integer;
begin
  Result := nil;
  Scripts := ElementByPath(RecordElement, 'VMAD\Scripts');
  if not Assigned(Scripts) then Exit;
  for i := 0 to Pred(ElementCount(Scripts)) do begin
    Candidate := ElementByIndex(Scripts, i);
    if GetElementEditValues(Candidate, 'ScriptName') = Value then begin
      Result := Candidate; Exit;
    end;
  end;
end;

function PropertyObject(ScriptEntry: IInterface; const Value: string): IInterface;
var Properties, Entry: IInterface; i: Integer;
begin
  Result := nil;
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then Exit;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    Entry := ElementByIndex(Properties, i);
    if GetElementEditValues(Entry, 'propertyName') = Value then begin
      Result := LinksTo(ElementByPath(
        Entry,
        'Value\Object Union\Object v2\FormID'
      ));
      Exit;
    end;
  end;
end;

procedure AuditMasters;
var Expected: TStringList; i: Integer;
begin
  Expected := TStringList.Create;
  try
    Expected.Add('Skyrim.esm');
    Expected.Add('Update.esm');
    Expected.Add('Dawnguard.esm');
    Expected.Add('HearthFires.esm');
    Expected.Add('Dragonborn.esm');
    Expected.Add('CFTO.esp');
    Expected.Add('DiegeticTravel.esp');
    if MasterCount(AdapterFile) <> Expected.Count then
      raise Exception.Create('Adapter master count mismatch');
    for i := 0 to Pred(Expected.Count) do
      if LowerCase(GetFileName(MasterByIndex(AdapterFile, i))) <>
        LowerCase(Expected[i]) then
        raise Exception.Create('Adapter master order mismatch');
    ReportLines.Add('PASS masters=7');
  finally
    Expected.Free;
  end;
end;

procedure AuditInfo(
  InfoRecord, PickerQuest, SharedInfo: IInterface;
  ExpectedConditionCount: Integer;
  const ExpectedEditorID: string
);
var Conditions, ScriptEntry, Fragments, Fragment: IInterface;
begin
  if GetElementEditValues(InfoRecord, 'EDID') <> ExpectedEditorID then
    raise Exception.Create('Adapter INFO order/EditorID mismatch');
  if GetElementEditValues(InfoRecord, 'RNAM') <> MapPrompt then
    raise Exception.Create('Adapter INFO prompt mismatch');
  if GetElementNativeValues(InfoRecord, 'ENAM\Response Flags') <> 1 then
    raise Exception.Create('Adapter INFO is not Goodbye');
  if FormID(LinksTo(ElementByPath(InfoRecord, 'DNAM'))) <>
    FormID(SharedInfo) then
    raise Exception.Create('Adapter shared response mismatch');
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or
    (ElementCount(Conditions) <> ExpectedConditionCount) then
    raise Exception.Create('Adapter INFO condition count mismatch');
  ScriptEntry := ScriptByName(InfoRecord, 'DNT_CarriageParchmentFragment');
  if not Assigned(ScriptEntry) or
    (FormID(PropertyObject(ScriptEntry, 'Picker')) <> FormID(PickerQuest)) then
    raise Exception.Create('Adapter fragment Picker wiring mismatch');
  if GetElementEditValues(InfoRecord, 'VMAD\Script Fragments\FileName') <>
    'DNT_CarriageParchmentFragment' then
    raise Exception.Create('Adapter fragment filename mismatch');
  if GetElementNativeValues(InfoRecord, 'VMAD\Script Fragments\Flags') <> 2 then
    raise Exception.Create('Adapter fragment is not OnEnd');
  Fragments := ElementByPath(InfoRecord, 'VMAD\Script Fragments\Fragments');
  if not Assigned(Fragments) or (ElementCount(Fragments) <> 1) then
    raise Exception.Create('Adapter fragment count mismatch');
  Fragment := ElementByIndex(Fragments, 0);
  if GetElementEditValues(Fragment, 'FragmentName') <> 'Fragment_0' then
    raise Exception.Create('Adapter fragment binding mismatch');
end;

function Initialize: Integer;
var QuestRecord, CoordinatorQuest, PickerScript, TopicRecord, BranchRecord,
  InfoGroup, SharedInfo, PaidInfo, FreeInfo: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\carriage-parchment-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\carriage-parchment-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\carriage-parchment-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    AdapterFile := FileByPluginName('DiegeticTravelCarriageParchment.esp');
    CoreFile := FileByPluginName('DiegeticTravel.esp');
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(AdapterFile) or not Assigned(CoreFile) or
      not Assigned(SkyrimFile) then
      raise Exception.Create('Required adapter audit plugin is missing');
    AuditStage := 'masters';
    AuditMasters;

    AuditStage := 'quest lookup';
    QuestRecord := ResolveRecordByEditorID(
      AdapterFile,
      'QUST',
      'DNT_CarriageParchmentQuest'
    );
    CoordinatorQuest := ResolveRecordByEditorID(
      CoreFile,
      'QUST',
      'DNT_TravelCoordinatorQuest'
    );
    if GetElementNativeValues(QuestRecord, 'DNAM\Flags') <> 1 then
      raise Exception.Create('Adapter quest is not Start Game Enabled');
    PickerScript := ScriptByName(QuestRecord, 'DNT_CarriageParchmentPicker');
    if not Assigned(PickerScript) or
      (FormID(PropertyObject(PickerScript, 'Coordinator')) <>
        FormID(CoordinatorQuest)) then
      raise Exception.Create('Adapter Coordinator wiring mismatch');
    ReportLines.Add(
      'QUEST_FIXED_FORM_ID=' + IntToHex(FixedFormID(QuestRecord), 8)
    );
    ReportLines.Add('PASS quest=core_coordinator_wired');

    AuditStage := 'dialogue lookup';
    TopicRecord := ResolveRecordByEditorID(
      AdapterFile,
      'DIAL',
      'DNT_CarriageParchmentTopic'
    );
    BranchRecord := ResolveRecordByEditorID(
      AdapterFile,
      'DLBR',
      'DNT_CarriageParchmentBranch'
    );
    if GetElementEditValues(TopicRecord, 'FULL') <> MapPrompt then
      raise Exception.Create('Adapter topic prompt mismatch');
    if FormID(LinksTo(ElementByPath(TopicRecord, 'QNAM'))) <>
      FormID(QuestRecord) then
      raise Exception.Create(
        'Adapter topic quest mismatch actual=' +
        Name(LinksTo(ElementByPath(TopicRecord, 'QNAM'))) +
        ' expected=' + Name(QuestRecord)
      );
    if FormID(LinksTo(ElementByPath(TopicRecord, 'BNAM'))) <>
      FormID(BranchRecord) then
      raise Exception.Create('Adapter topic branch mismatch');
    if FormID(LinksTo(ElementByPath(BranchRecord, 'SNAM'))) <>
      FormID(TopicRecord) then
      raise Exception.Create('Adapter branch start mismatch');
    InfoGroup := ChildGroup(TopicRecord);
    if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 2) then
      raise Exception.Create('Adapter topic must contain two INFOs');
    PaidInfo := ElementByIndex(InfoGroup, 0);
    FreeInfo := ElementByIndex(InfoGroup, 1);
    SharedInfo := ResolveRecordByObjectID(SkyrimFile, $0CDFA2);
    AuditStage := 'paid info';
    AuditInfo(
      PaidInfo,
      QuestRecord,
      SharedInfo,
      4,
      'DNT_CarriageParchmentPaidInfo'
    );
    AuditStage := 'free info';
    AuditInfo(
      FreeInfo,
      QuestRecord,
      SharedInfo,
      3,
      'DNT_CarriageParchmentFreeInfo'
    );
    ReportLines.Add('PASS dialogue=paid_free_shared_voice_goodbye_on_end');
    ReportLines.SaveToFile(ReportPath);
    WriteTextFile(StatusPath, 'success');
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
  if Assigned(ReportLines) then ReportLines.Free;
  Result := 0;
end;

end.
