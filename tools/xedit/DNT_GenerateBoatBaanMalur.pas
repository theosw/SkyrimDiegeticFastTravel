unit DNT_GenerateBoatBaanMalur;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelBoatBaanMalur.esp';
  StartObjectID = $000800;
  BoatPrompt = 'Could you show me your route map?';
  OnEndFragmentMask = $02;
  GoodbyeResponseFlagsMask = $0001;
  EqualConditionType = $00;
  OrEqualConditionType = $01;

var
  OutputFile, JourneyFile: IInterface;
  StatusPath, ErrorPath, PluginOutputPath, SeqFormIDsPath: string;

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
    raise Exception.Create('Could not resolve ' + ExpectedSignature +
      ' object ' + IntToHex(ObjectID, 6));
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(IntToHex(ObjectID, 6) + ' resolved to ' +
      Signature(Result) + ', expected ' + ExpectedSignature);
  if (ExpectedEditorID <> '') and
    (GetElementEditValues(Result, 'EDID') <> ExpectedEditorID) then
    raise Exception.Create(IntToHex(ObjectID, 6) + ' is not ' +
      ExpectedEditorID);
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
    raise Exception.Create(GetElementEditValues(TopicRecord, 'EDID') +
      ' does not contain an INFO');
  Result := ElementByIndex(InfoGroup, 0);
end;

function EnsureTopGroup(const RecordSignature: string): IInterface;
begin
  Result := GroupBySignature(OutputFile, RecordSignature);
  if not Assigned(Result) then
    Result := Add(OutputFile, RecordSignature, True);
  if not Assigned(Result) then
    raise Exception.Create('Could not create top-level group: ' +
      RecordSignature);
end;

procedure ReserveESLFormIDRange;
var
  FileHeader: IInterface;
  CurrentObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(OutputFile, 0);
  if not Assigned(FileHeader) then
    raise Exception.Create('Baan Malur plugin has no file header');
  CurrentObjectID := GetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID'
  );
  if CurrentObjectID > StartObjectID then
    raise Exception.Create(
      'Baan Malur ESL FormID range starts at ' +
      IntToHex(StartObjectID, 6) + ', but the new file already reached ' +
      IntToHex(CurrentObjectID, 6)
    );
  SetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID',
    StartObjectID
  );
end;

function AddScript(
  RecordElement: IInterface;
  const ScriptName: string
): IInterface;
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
  if GetElementEditValues(Result, 'EDID') <> EditorIDValue then
    raise Exception.Create('Could not set quest EditorID: ' + EditorIDValue);
  Add(Result, 'DNAM', True);
  SetElementNativeValues(Result, 'DNAM\Flags', 1);
  SetElementNativeValues(Result, 'DNAM\Priority', 60);
end;

procedure AddSubjectCondition(
  RecordElement: IInterface;
  const FunctionName: string;
  ParameterRecord: IInterface;
  ConditionType: Cardinal;
  ComparisonValue: Double
);
var
  Conditions, ConditionEntry, ConditionData, ParameterElement,
    ReadBackParameter: IInterface;
begin
  Conditions := ElementByPath(RecordElement, 'Conditions');
  if not Assigned(Conditions) then begin
    Add(RecordElement, 'Conditions', True);
    Conditions := ElementByPath(RecordElement, 'Conditions');
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create conditions');

  ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create('Condition entry has no CTDA');
  SetElementNativeValues(ConditionData, 'Type', ConditionType);
  SetElementNativeValues(
    ConditionData,
    'Comparison Value - Float',
    ComparisonValue
  );
  SetElementEditValues(ConditionData, 'Function', FunctionName);
  SetElementNativeValues(ConditionData, 'Run On', 0);
  ParameterElement := ElementByPath(ConditionData, 'Parameter #1');
  SetEditValue(ParameterElement, Name(ParameterRecord));
  ReadBackParameter := LinksTo(ParameterElement);
  if not Assigned(ReadBackParameter) or
    (FormID(ReadBackParameter) <> FormID(ParameterRecord)) then
    raise Exception.Create(FunctionName + ' condition did not read back');
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
    raise Exception.Create('Could not create Baan Malur INFO VMAD');
  ElementAssign(VMAD, LowInteger, SourceVMAD, False);
  VMAD := ElementByPath(InfoRecord, 'VMAD');

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) = 0) then
    raise Exception.Create('Baan Malur INFO VMAD has no script entry');
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
  if not Assigned(Fragments) or (ElementCount(Fragments) = 0) then
    raise Exception.Create('Baan Malur INFO VMAD has no fragment entry');
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
end;

procedure ConfigureDialogue(PickerQuest: IInterface);
var
  SourceTopic, SourceBranch, TopicRecord, BranchRecord, InfoRecord,
    InfoGroup, TemplateInfo, SharedInfo, FragmentScript, QuestElement,
    BranchElement, BranchQuestElement, StartingTopicElement, ReadBack,
    Conditions, RavenCaptain, BaanCaptain, CormarisCaptain: IInterface;
begin
  SourceTopic := RequireRecordByEditorID(
    JourneyFile,
    'DIAL',
    'SOMRFerrySystemGreeting'
  );
  SourceBranch := RequireRecordByEditorID(
    JourneyFile,
    'DLBR',
    'SOMRFerrySystemMainBranch'
  );

  TopicRecord := wbCopyElementToFile(SourceTopic, OutputFile, True, False);
  BranchRecord := wbCopyElementToFile(SourceBranch, OutputFile, True, False);
  if not Assigned(TopicRecord) or not Assigned(BranchRecord) then
    raise Exception.Create('Could not clone Baan Malur dialogue shell');

  SetElementEditValues(TopicRecord, 'EDID', 'DNT_BaanMalurBoatParchmentTopic');
  SetElementEditValues(TopicRecord, 'FULL', BoatPrompt);
  SetElementEditValues(BranchRecord, 'EDID', 'DNT_BaanMalurBoatParchmentBranch');

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

  ReadBack := LinksTo(ElementByPath(TopicRecord, 'BNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(BranchRecord)) then
    raise Exception.Create('Baan Malur topic does not point to its branch');
  ReadBack := LinksTo(ElementByPath(BranchRecord, 'SNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(TopicRecord)) then
    raise Exception.Create('Baan Malur branch does not start at its topic');

  InfoGroup := ChildGroup(TopicRecord);
  if Assigned(InfoGroup) and (ElementCount(InfoGroup) <> 0) then
    raise Exception.Create('New Baan Malur DIAL unexpectedly contains INFOs');
  InfoRecord := Add(TopicRecord, 'INFO', True);
  Add(InfoRecord, 'ENAM', True);
  Add(InfoRecord, 'CNAM', True);
  SetElementEditValues(InfoRecord, 'EDID', 'DNT_BaanMalurBoatParchmentInfo');
  SetElementEditValues(InfoRecord, 'RNAM', BoatPrompt);
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    GoodbyeResponseFlagsMask
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
  Add(InfoRecord, 'Conditions', True);
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  while Assigned(Conditions) and (ElementCount(Conditions) > 0) do
    RemoveElement(Conditions, 0);
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    RavenCaptain,
    OrEqualConditionType,
    1.0
  );
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    BaanCaptain,
    OrEqualConditionType,
    1.0
  );
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    CormarisCaptain,
    EqualConditionType,
    1.0
  );

  SharedInfo := FirstTopicInfo(SourceTopic);
  Add(InfoRecord, 'DNAM', True);
  SetEditValue(ElementByPath(InfoRecord, 'DNAM'), Name(SharedInfo));

  TemplateInfo := FirstTopicInfo(RequireRecordByEditorID(
    JourneyFile,
    'DIAL',
    'SOMRFerryToBaanMalur'
  ));
  FragmentScript := ConfigureInfoFragment(
    InfoRecord,
    TemplateInfo,
    'DNT_BaanMalurBoatParchmentFragment'
  );
  AddObjectProperty(FragmentScript, 'Picker', PickerQuest);
  SetElementNativeValues(TopicRecord, 'TIFC', 1);
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
  BoatQuest, ServiceScript, PickerScript: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\boat-baan-malur.status';
  ErrorPath := ScriptsPath + '..\..\build\boat-baan-malur.error';
  PluginOutputPath := ScriptsPath +
    '..\..\modules\boat-baan-malur\mod\DiegeticTravelBoatBaanMalur.esp';
  SeqFormIDsPath := ScriptsPath +
    '..\..\build\boat-baan-malur-seq-formids.txt';
  WriteTextFile(StatusPath, 'running');

  try
    JourneyFile := FileByPluginName('Journey to Baan Malur.esp');
    if not Assigned(JourneyFile) then
      raise Exception.Create('Required Journey to Baan Malur file is missing');

    OutputFile := AddNewFileName(OutputPluginName);
    if not Assigned(OutputFile) then
      raise Exception.Create('Could not create ' + OutputPluginName);
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'ccBGSSSE001-Fish.esm');
    AddMasterIfMissing(OutputFile, 'ccBGSSSE037-Curios.esl');
    AddMasterIfMissing(OutputFile, 'Journey to Baan Malur.esp');
    ReserveESLFormIDRange;

    BoatQuest := NewQuest('DNT_BaanMalurBoatQuest');
    ServiceScript := AddScript(
      BoatQuest,
      'DNT_BaanMalurBoatTravelService'
    );
    PickerScript := AddScript(
      BoatQuest,
      'DNT_BaanMalurBoatParchmentPicker'
    );
    AddObjectProperty(PickerScript, 'Service', BoatQuest);

    ConfigureDialogue(BoatQuest);
    SetIsESL(OutputFile, True);
    if not GetIsESL(OutputFile) then
      raise Exception.Create('Could not set the Baan Malur add-on ESL flag');
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormID(BoatQuest);
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Generated optional Baan Malur merchant ferry ESP-FE');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
