unit DNT_GenerateCarriageParchment;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelCarriageParchment.esp';
  MapPrompt = 'Could you show me your route map?';
  OnEndFragmentMask = $02;
  GoodbyeResponseFlagsMask = $0001;

var
  OutputFile, CftoFile, CoreFile: IInterface;
  StatusPath, ErrorPath, PluginOutputPath, SeqFormIDsPath: string;
  ReleaseMode: Boolean;

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
  const ExpectedSignature: string
): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(PluginFile) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
  if not Assigned(Result) or (Signature(Result) <> ExpectedSignature) then
    raise Exception.Create('Could not resolve ' + ExpectedSignature + ' ' +
      IntToHex(ObjectID, 6));
end;

function RequireRecordByEditorID(
  PluginFile: IInterface;
  const RecordSignature, EditorIDValue: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(PluginFile, RecordSignature);
  if Assigned(RecordGroup) then
    for i := 0 to Pred(ElementCount(RecordGroup)) do begin
      Candidate := ElementByIndex(RecordGroup, i);
      if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
        Result := Candidate;
        Exit;
      end;
    end;
  raise Exception.Create('Could not resolve ' + EditorIDValue);
end;

function EnsureTopGroup(const RecordSignature: string): IInterface;
begin
  Result := GroupBySignature(OutputFile, RecordSignature);
  if not Assigned(Result) then
    Result := Add(OutputFile, RecordSignature, True);
end;

procedure ReserveNextObjectID(StartObjectID: Cardinal);
var
  FileHeader: IInterface;
  CurrentObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(OutputFile, 0);
  CurrentObjectID := GetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID'
  );
  if CurrentObjectID > StartObjectID then
    raise Exception.Create(
      'Carriage parchment FormID range is already occupied: ' +
      IntToHex(CurrentObjectID, 6)
    );
  SetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID',
    StartObjectID
  );
end;

function AddScript(RecordElement: IInterface; const ScriptName: string): IInterface;
var
  Scripts: IInterface;
begin
  Scripts := ElementByPath(Add(RecordElement, 'VMAD', False), 'Scripts');
  Result := ElementAssign(Scripts, HighInteger, nil, False);
  SetElementEditValues(Result, 'ScriptName', ScriptName);
end;

function AddObjectProperty(
  ScriptElement: IInterface;
  const PropertyName: string;
  PropertyRecord: IInterface
): IInterface;
var
  Properties: IInterface;
begin
  Properties := ElementByPath(ScriptElement, 'Properties');
  Result := ElementAssign(Properties, HighInteger, nil, False);
  SetElementEditValues(Result, 'propertyName', PropertyName);
  SetElementEditValues(Result, 'Type', 'Object');
  SetElementEditValues(
    Result,
    'Value\Object Union\Object v2\FormID',
    Name(PropertyRecord)
  );
end;

function NewQuest(const EditorIDValue: string): IInterface;
begin
  Result := Add(EnsureTopGroup('QUST'), 'QUST', True);
  SetElementEditValues(Result, 'EDID', EditorIDValue);
  Add(Result, 'DNAM', True);
  SetElementNativeValues(Result, 'DNAM\Flags', 1);
  SetElementNativeValues(Result, 'DNAM\Priority', 60);
end;

function ConfigureInfoFragment(
  InfoRecord, TemplateInfo: IInterface;
  const ScriptName: string
): IInterface;
var
  VMAD, Scripts, Properties, Fragments, Fragment, SourceVMAD: IInterface;
begin
  Add(InfoRecord, 'VMAD', True);
  VMAD := ElementByPath(InfoRecord, 'VMAD');
  SourceVMAD := ElementByPath(TemplateInfo, 'VMAD');
  if not Assigned(VMAD) or not Assigned(SourceVMAD) then
    raise Exception.Create('Could not create carriage INFO VMAD');
  ElementAssign(VMAD, LowInteger, SourceVMAD, False);
  VMAD := ElementByPath(InfoRecord, 'VMAD');

  Scripts := ElementByPath(VMAD, 'Scripts');
  while ElementCount(Scripts) > 1 do
    RemoveElement(Scripts, Pred(ElementCount(Scripts)));
  Result := ElementByIndex(Scripts, 0);
  SetElementEditValues(Result, 'ScriptName', ScriptName);
  Properties := ElementByPath(Result, 'Properties');
  while Assigned(Properties) and (ElementCount(Properties) > 0) do
    RemoveElement(Properties, 0);

  SetElementEditValues(VMAD, 'Script Fragments\FileName', ScriptName);
  SetElementNativeValues(VMAD, 'Script Fragments\Flags', OnEndFragmentMask);
  Fragments := ElementByPath(VMAD, 'Script Fragments\Fragments');
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
end;

procedure CopyConditions(SourceInfo, TargetInfo: IInterface);
var
  SourceConditions, TargetConditions: IInterface;
  i: Integer;
begin
  SourceConditions := ElementByPath(SourceInfo, 'Conditions');
  Add(TargetInfo, 'Conditions', True);
  TargetConditions := ElementByPath(TargetInfo, 'Conditions');
  while Assigned(TargetConditions) and (ElementCount(TargetConditions) > 0) do
    RemoveElement(TargetConditions, 0);
  for i := 0 to Pred(ElementCount(SourceConditions)) do
    ElementAssign(
      TargetConditions,
      HighInteger,
      ElementByIndex(SourceConditions, i),
      False
    );
end;

procedure AddMapInfo(
  TopicRecord, SourceInfo, PickerQuest, TemplateInfo: IInterface;
  const EditorIDValue: string
);
var
  InfoRecord, SharedInfo, FragmentScript: IInterface;
begin
  InfoRecord := Add(TopicRecord, 'INFO', True);
  Add(InfoRecord, 'ENAM', True);
  Add(InfoRecord, 'CNAM', True);
  SetElementEditValues(InfoRecord, 'EDID', EditorIDValue);
  SetElementEditValues(InfoRecord, 'RNAM', MapPrompt);
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    GoodbyeResponseFlagsMask
  );
  CopyConditions(SourceInfo, InfoRecord);

  SharedInfo := LinksTo(ElementByPath(SourceInfo, 'DNAM'));
  if not Assigned(SharedInfo) then
    raise Exception.Create('Carriage source INFO has no shared response');
  Add(InfoRecord, 'DNAM', True);
  SetEditValue(ElementByPath(InfoRecord, 'DNAM'), Name(SharedInfo));

  FragmentScript := ConfigureInfoFragment(
    InfoRecord,
    TemplateInfo,
    'DNT_CarriageParchmentFragment'
  );
  AddObjectProperty(FragmentScript, 'Picker', PickerQuest);
end;

procedure ConfigureDialogue(PickerQuest: IInterface);
var
  SourceTopic, SourceBranch, SourcePaidInfo, SourceFreeInfo, TopicRecord,
    BranchRecord, TopicChildGroup, TemplateInfo, QuestElement, BranchElement,
    BranchQuestElement, StartingTopicElement: IInterface;
begin
  SourceTopic := RequireRecord(CftoFile, $09D8C6, 'DIAL');
  SourceBranch := RequireRecord(CftoFile, $09D8C5, 'DLBR');
  SourcePaidInfo := RequireRecord(CftoFile, $09D8C7, 'INFO');
  SourceFreeInfo := RequireRecord(CftoFile, $0DA634, 'INFO');
  TemplateInfo := RequireRecord(CftoFile, $019DC8, 'INFO');

  TopicRecord := wbCopyElementToFile(SourceTopic, OutputFile, True, False);
  BranchRecord := wbCopyElementToFile(SourceBranch, OutputFile, True, False);
  SetElementEditValues(TopicRecord, 'EDID', 'DNT_CarriageParchmentTopic');
  SetElementEditValues(TopicRecord, 'FULL', MapPrompt);
  SetElementEditValues(BranchRecord, 'EDID', 'DNT_CarriageParchmentBranch');

  QuestElement := ElementByPath(TopicRecord, 'QNAM');
  if not Assigned(QuestElement) then begin
    Add(TopicRecord, 'QNAM', True);
    QuestElement := ElementByPath(TopicRecord, 'QNAM');
  end;
  SetEditValue(QuestElement, Name(PickerQuest));
  BranchElement := ElementByPath(TopicRecord, 'BNAM');
  if not Assigned(BranchElement) then begin
    Add(TopicRecord, 'BNAM', True);
    BranchElement := ElementByPath(TopicRecord, 'BNAM');
  end;
  SetEditValue(BranchElement, Name(BranchRecord));
  BranchQuestElement := ElementByPath(BranchRecord, 'QNAM');
  if not Assigned(BranchQuestElement) then begin
    Add(BranchRecord, 'QNAM', True);
    BranchQuestElement := ElementByPath(BranchRecord, 'QNAM');
  end;
  SetEditValue(BranchQuestElement, Name(PickerQuest));
  SetElementNativeValues(BranchRecord, 'TNAM', 0);
  SetElementNativeValues(BranchRecord, 'DNAM', 1);
  StartingTopicElement := ElementByPath(BranchRecord, 'SNAM');
  if not Assigned(StartingTopicElement) then begin
    Add(BranchRecord, 'SNAM', True);
    StartingTopicElement := ElementByPath(BranchRecord, 'SNAM');
  end;
  SetEditValue(StartingTopicElement, Name(TopicRecord));

  TopicChildGroup := ChildGroup(TopicRecord);
  if Assigned(TopicChildGroup) and (ElementCount(TopicChildGroup) <> 0) then
    raise Exception.Create('New carriage DIAL unexpectedly contains INFOs');
  AddMapInfo(
    TopicRecord,
    SourcePaidInfo,
    PickerQuest,
    TemplateInfo,
    'DNT_CarriageParchmentPaidInfo'
  );
  AddMapInfo(
    TopicRecord,
    SourceFreeInfo,
    PickerQuest,
    TemplateInfo,
    'DNT_CarriageParchmentFreeInfo'
  );
  SetElementNativeValues(TopicRecord, 'TIFC', 2);
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

procedure SaveGeneratedSeqFormID(QuestRecord: IInterface);
var
  SeqFormIDs: TStringList;
begin
  SeqFormIDs := TStringList.Create;
  try
    SeqFormIDs.Add(IntToHex(FixedFormID(QuestRecord), 8));
    SeqFormIDs.SaveToFile(SeqFormIDsPath);
  finally
    SeqFormIDs.Free;
  end;
end;

function Initialize: Integer;
var
  PickerQuest, PickerScript, CoordinatorQuest: IInterface;
begin
  Result := 1;
  ReleaseMode := FileExists(
    ScriptsPath + '..\..\build\consolidated-release.mode'
  );
  StatusPath := ScriptsPath + '..\..\build\carriage-parchment.status';
  ErrorPath := ScriptsPath + '..\..\build\carriage-parchment.error';
  if ReleaseMode then begin
    PluginOutputPath := ScriptsPath +
      '..\..\build\release\DiegeticTravel.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\release-carriage-parchment-seq-formids.txt';
  end else begin
    PluginOutputPath := ScriptsPath +
      '..\..\modules\carriage-parchment\mod\DiegeticTravelCarriageParchment.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\carriage-parchment-seq-formids.txt';
  end;
  WriteTextFile(StatusPath, 'running');
  try
    CftoFile := FileByPluginName('CFTO.esp');
    CoreFile := FileByPluginName('DiegeticTravel.esp');
    if not Assigned(CftoFile) or not Assigned(CoreFile) then
      raise Exception.Create('Required CFTO or carriage core file is missing');

    CoordinatorQuest := RequireRecordByEditorID(
      CoreFile,
      'QUST',
      'DNT_TravelCoordinatorQuest'
    );
    if ReleaseMode then begin
      OutputFile := CoreFile;
      ReserveNextObjectID($000A20);
    end else begin
      OutputFile := AddNewFileName(OutputPluginName);
      AddMasterIfMissing(OutputFile, 'Skyrim.esm');
      AddMasterIfMissing(OutputFile, 'Update.esm');
      AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
      AddMasterIfMissing(OutputFile, 'HearthFires.esm');
      AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
      AddMasterIfMissing(OutputFile, 'CFTO.esp');
      AddMasterIfMissing(OutputFile, 'DiegeticTravel.esp');
    end;

    PickerQuest := NewQuest('DNT_CarriageParchmentQuest');
    PickerScript := AddScript(PickerQuest, 'DNT_CarriageParchmentPicker');
    AddObjectProperty(PickerScript, 'Coordinator', CoordinatorQuest);
    ConfigureDialogue(PickerQuest);
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormID(PickerQuest);
    WriteTextFile(StatusPath, 'success');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
