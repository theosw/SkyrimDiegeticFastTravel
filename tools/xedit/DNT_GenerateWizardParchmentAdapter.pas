unit DNT_GenerateWizardParchmentAdapter;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelWizardParchment.esp';
  ParchmentPrompt = 'Could you show me your travel map?';
  ParchmentResponse = 'Of course.';
  OnBeginFragmentMask = $01;
  GoodbyeResponseFlagsMask = $0001;
  SilentTerminalResponseFlagsMask = $0A01;
  MiscDialogueCategory = 7;
  EqualConditionType = $00;
  NotEqualConditionType = $20;

var
  OutputFile, SkyrimFile, WizardFile: IInterface;
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
  const ExpectedSignature, ExpectedEditorID: string
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
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve ' + ExpectedEditorID + ' at object ID ' +
      IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      IntToHex(ObjectID, 6) + ' is not ' + ExpectedEditorID
    );
end;

procedure ConfigureSharedResponse(
  InfoRecord: IInterface;
  const ExpectedEditorID, ResponseText: string;
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal
);
var
  SharedInfo, SharedInfoTopic, SharedInfoGroup, CandidateInfo,
    SourceResponses, SharedInfoElement, SharedInfoTarget,
    TargetResponses: IInterface;
  i: Integer;
  DonorIsTopicChild: Boolean;
begin
  SharedInfo := RequireRecord(
    SkyrimFile,
    SharedInfoFormID,
    'INFO',
    'OfCourse'
  );
  SharedInfoTopic := RequireRecord(
    SkyrimFile,
    SharedInfoTopicFormID,
    'DIAL',
    'DialogueGenericSharedInfo'
  );
  if GetElementNativeValues(
    SharedInfoTopic,
    'DATA\Category'
  ) <> MiscDialogueCategory then
    raise Exception.Create(
      ExpectedEditorID + ' donor topic is not Misc dialogue'
    );
  if GetElementEditValues(SharedInfoTopic, 'SNAM') <> 'SharedInfo' then
    raise Exception.Create(
      ExpectedEditorID + ' donor topic subtype is not SharedInfo'
    );

  SharedInfoGroup := ChildGroup(SharedInfoTopic);
  DonorIsTopicChild := False;
  if Assigned(SharedInfoGroup) then
    for i := 0 to Pred(ElementCount(SharedInfoGroup)) do begin
      CandidateInfo := ElementByIndex(SharedInfoGroup, i);
      if (Signature(CandidateInfo) = 'INFO') and
        (FormID(CandidateInfo) = FormID(SharedInfo)) then begin
        DonorIsTopicChild := True;
        Break;
      end;
    end;
  if not DonorIsTopicChild then
    raise Exception.Create(
      ExpectedEditorID + ' donor is not a child of its SharedInfo topic'
    );

  SourceResponses := ElementByPath(SharedInfo, 'Responses');
  if not Assigned(SourceResponses) or (ElementCount(SourceResponses) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' SharedInfo donor must own exactly one response'
    );
  if GetElementEditValues(
    SharedInfo,
    'Responses\Response\NAM1'
  ) <> ResponseText then
    raise Exception.Create(
      ExpectedEditorID + ' SharedInfo donor text does not match'
    );

  if Assigned(ElementByPath(InfoRecord, 'Responses')) then
    RemoveElement(InfoRecord, 'Responses');
  SharedInfoElement := ElementByPath(InfoRecord, 'DNAM');
  if not Assigned(SharedInfoElement) then begin
    Add(InfoRecord, 'DNAM', True);
    SharedInfoElement := ElementByPath(InfoRecord, 'DNAM');
  end;
  if not Assigned(SharedInfoElement) then
    raise Exception.Create(ExpectedEditorID + ' could not create Shared Info');
  SetEditValue(SharedInfoElement, Name(SharedInfo));
  SharedInfoTarget := LinksTo(SharedInfoElement);
  if not Assigned(SharedInfoTarget) or
    (FormID(SharedInfoTarget) <> FormID(SharedInfo)) then
    raise Exception.Create(
      ExpectedEditorID + ' SharedInfo donor did not read back'
    );
  TargetResponses := ElementByPath(InfoRecord, 'Responses');
  if Assigned(TargetResponses) and (ElementCount(TargetResponses) > 0) then
    raise Exception.Create(ExpectedEditorID + ' still owns response data');
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

function EnsureTopGroup(const RecordSignature: string): IInterface;
begin
  Result := GroupBySignature(OutputFile, RecordSignature);
  if not Assigned(Result) then
    Result := Add(OutputFile, RecordSignature, True);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not create top-level group: ' + RecordSignature
    );
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
      'Wizard parchment FormID range is already occupied: ' +
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

function NewQuest(const EditorIDValue, ScriptName: string): IInterface;
begin
  Result := Add(EnsureTopGroup('QUST'), 'QUST', True);
  SetElementEditValues(Result, 'EDID', EditorIDValue);
  if GetElementEditValues(Result, 'EDID') <> EditorIDValue then
    raise Exception.Create('Could not set quest EditorID: ' + EditorIDValue);
  Add(Result, 'DNAM', True);
  SetElementNativeValues(Result, 'DNAM\Flags', 1);
  SetElementNativeValues(Result, 'DNAM\Priority', 60);
  AddScript(Result, ScriptName);
end;

function QuestScript(QuestRecord: IInterface): IInterface;
begin
  Result := ElementByIndex(ElementByPath(QuestRecord, 'VMAD\Scripts'), 0);
end;

procedure AddSubjectCondition(
  InfoRecord: IInterface;
  const FunctionName: string;
  ParameterRecord: IInterface;
  ConditionType: Cardinal;
  ComparisonValue: Double
);
var
  Conditions, ConditionEntry, ConditionData, ParameterElement,
    ReadBackParameter: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then begin
    Add(InfoRecord, 'Conditions', True);
    Conditions := ElementByPath(InfoRecord, 'Conditions');
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create INFO conditions');

  ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);
  if not Assigned(ConditionEntry) then
    raise Exception.Create('Could not create INFO condition entry');
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create('INFO condition has no CTDA');

  SetElementNativeValues(ConditionData, 'Type', ConditionType);
  SetElementNativeValues(
    ConditionData,
    'Comparison Value - Float',
    ComparisonValue
  );
  SetElementEditValues(ConditionData, 'Function', FunctionName);
  SetElementNativeValues(ConditionData, 'Run On', 0);
  ParameterElement := ElementByPath(ConditionData, 'Parameter #1');
  if not Assigned(ParameterElement) then
    raise Exception.Create(FunctionName + ' condition has no Parameter #1');
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
  if Assigned(ElementByPath(InfoRecord, 'VMAD')) then
    RemoveElement(InfoRecord, 'VMAD');
  Add(InfoRecord, 'VMAD', True);
  VMAD := ElementByPath(InfoRecord, 'VMAD');
  SourceVMAD := ElementByPath(TemplateInfo, 'VMAD');
  if not Assigned(VMAD) or not Assigned(SourceVMAD) then
    raise Exception.Create('Could not create parchment INFO VMAD');
  ElementAssign(VMAD, LowInteger, SourceVMAD, False);
  VMAD := ElementByPath(InfoRecord, 'VMAD');

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) = 0) then
    raise Exception.Create('Parchment INFO VMAD has no script entry');
  while ElementCount(Scripts) > 1 do
    RemoveElement(Scripts, Pred(ElementCount(Scripts)));
  Result := ElementByIndex(Scripts, 0);
  SetElementEditValues(Result, 'ScriptName', ScriptName);
  Properties := ElementByPath(Result, 'Properties');
  while Assigned(Properties) and (ElementCount(Properties) > 0) do
    RemoveElement(Properties, 0);

  SetElementEditValues(VMAD, 'Script Fragments\FileName', ScriptName);
  SetElementNativeValues(VMAD, 'Script Fragments\Flags', OnBeginFragmentMask);
  Fragments := ElementByPath(VMAD, 'Script Fragments\Fragments');
  if not Assigned(Fragments) or (ElementCount(Fragments) = 0) then
    raise Exception.Create('Parchment INFO VMAD has no fragment entry');
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
end;

procedure ConfigureParchmentDialogue(PickerQuest: IInterface);
var
  HubInfo, SourceTopic, SourceBranch, PickerTopic, PickerBranch, InfoGroup,
    PickerInfo, MirabelleInfo, TemplateInfo, FragmentScript,
    MirabelleFragmentScript, Responses, SourceResponses, Conditions,
    SourceConditions, MirabelleBase, SpeakerElement: IInterface;
  QuestElement, BranchElement, BranchQuestElement, StartingTopicElement,
    ReadBack: IInterface;
  i: Integer;
begin
  HubInfo := RequireRecord(
    WizardFile,
    $000808,
    'INFO',
    'DNT_WG_Request_Phinis'
  );
  SourceTopic := TopicContainingInfo(WizardFile, HubInfo);
  if not Assigned(SourceTopic) or (Signature(SourceTopic) <> 'DIAL') then
    raise Exception.Create('Could not resolve faculty hub DIAL from its INFO');
  SourceBranch := LinksTo(ElementByPath(SourceTopic, 'BNAM'));
  if not Assigned(SourceBranch) then
    raise Exception.Create('Faculty hub DIAL has no branch link');

  PickerTopic := wbCopyElementToFile(SourceTopic, OutputFile, True, False);
  if not Assigned(PickerTopic) then
    raise Exception.Create('Could not clone faculty hub DIAL');
  SetElementEditValues(PickerTopic, 'EDID', 'DNT_WG_OpenParchment');
  SetElementEditValues(PickerTopic, 'FULL', ParchmentPrompt);

  PickerBranch := wbCopyElementToFile(SourceBranch, OutputFile, True, False);
  if not Assigned(PickerBranch) then
    raise Exception.Create('Could not clone faculty hub dialogue branch');
  SetElementEditValues(PickerBranch, 'EDID', 'DNT_WG_OpenParchmentBranch');

  QuestElement := ElementByPath(PickerTopic, 'QNAM');
  if not Assigned(QuestElement) then begin
    Add(PickerTopic, 'QNAM', True);
    QuestElement := ElementByPath(PickerTopic, 'QNAM');
  end;
  SetEditValue(QuestElement, Name(PickerQuest));

  BranchElement := ElementByPath(PickerTopic, 'BNAM');
  if not Assigned(BranchElement) then begin
    Add(PickerTopic, 'BNAM', True);
    BranchElement := ElementByPath(PickerTopic, 'BNAM');
  end;
  SetEditValue(BranchElement, Name(PickerBranch));

  BranchQuestElement := ElementByPath(PickerBranch, 'QNAM');
  if not Assigned(BranchQuestElement) then begin
    Add(PickerBranch, 'QNAM', True);
    BranchQuestElement := ElementByPath(PickerBranch, 'QNAM');
  end;
  SetEditValue(BranchQuestElement, Name(PickerQuest));
  SetElementNativeValues(PickerBranch, 'TNAM', 0);
  SetElementNativeValues(PickerBranch, 'DNAM', 1);

  StartingTopicElement := ElementByPath(PickerBranch, 'SNAM');
  if not Assigned(StartingTopicElement) then begin
    Add(PickerBranch, 'SNAM', True);
    StartingTopicElement := ElementByPath(PickerBranch, 'SNAM');
  end;
  SetEditValue(StartingTopicElement, Name(PickerTopic));

  ReadBack := LinksTo(ElementByPath(PickerBranch, 'SNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(PickerTopic)) then
    raise Exception.Create('Parchment topic is not its branch starting topic');
  ReadBack := LinksTo(ElementByPath(PickerTopic, 'BNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(PickerBranch)) then
    raise Exception.Create('Parchment topic does not point to its branch');

  InfoGroup := ChildGroup(PickerTopic);
  if Assigned(InfoGroup) and (ElementCount(InfoGroup) <> 0) then
    raise Exception.Create('New parchment DIAL unexpectedly contains INFOs');
  PickerInfo := Add(PickerTopic, 'INFO', True);
  Add(PickerInfo, 'ENAM', True);
  Add(PickerInfo, 'CNAM', True);

  SourceConditions := ElementByPath(HubInfo, 'Conditions');
  Add(PickerInfo, 'Conditions', True);
  Conditions := ElementByPath(PickerInfo, 'Conditions');
  while ElementCount(Conditions) > 0 do
    RemoveElement(Conditions, 0);
  for i := 0 to Pred(ElementCount(SourceConditions)) do
    ElementAssign(
      Conditions,
      HighInteger,
      ElementByIndex(SourceConditions, i),
      False
    );

  SourceResponses := ElementByPath(HubInfo, 'Responses');
  if not Assigned(SourceResponses) or (ElementCount(SourceResponses) <> 1) then
    raise Exception.Create('Faculty hub does not own exactly one response');
  Add(PickerInfo, 'Responses', True);
  Responses := ElementByPath(PickerInfo, 'Responses');
  while ElementCount(Responses) > 0 do
    RemoveElement(Responses, 0);
  ElementAssign(
    Responses,
    HighInteger,
    ElementByIndex(SourceResponses, 0),
    False
  );

  SetElementEditValues(PickerInfo, 'EDID', 'DNT_WG_OpenParchment_Faculty');
  SetElementEditValues(PickerInfo, 'RNAM', ParchmentPrompt);
  if Assigned(ElementByPath(PickerInfo, 'DNAM')) then
    RemoveElement(PickerInfo, 'DNAM');
  ConfigureSharedResponse(
    PickerInfo,
    'DNT_WG_OpenParchment_Faculty',
    ParchmentResponse,
    $000DBA22,
    $0001F319
  );
  SetElementNativeValues(
    PickerInfo,
    'ENAM\Response Flags',
    GoodbyeResponseFlagsMask
  );
  if Assigned(ElementByPath(PickerInfo, 'Link To')) then
    RemoveElement(PickerInfo, 'Link To');

  MirabelleBase := RequireRecord(
    SkyrimFile,
    $0001C1A0,
    'NPC_',
    'MirabelleErvine'
  );
  AddSubjectCondition(
    PickerInfo,
    'GetIsID',
    MirabelleBase,
    NotEqualConditionType,
    1.0
  );

  TemplateInfo := RequireRecord(
    WizardFile,
    $00080B,
    'INFO',
    'DNT_WG_Whiterun_FromPhinis'
  );
  FragmentScript := ConfigureInfoFragment(
    PickerInfo,
    TemplateInfo,
    'DNT_WizardParchmentFragment'
  );
  AddObjectProperty(FragmentScript, 'Picker', PickerQuest);

  MirabelleInfo := Add(PickerTopic, 'INFO', True);
  Add(MirabelleInfo, 'ENAM', True);
  Add(MirabelleInfo, 'CNAM', True);

  Add(MirabelleInfo, 'Conditions', True);
  Conditions := ElementByPath(MirabelleInfo, 'Conditions');
  while ElementCount(Conditions) > 0 do
    RemoveElement(Conditions, 0);
  for i := 0 to Pred(ElementCount(SourceConditions)) do
    ElementAssign(
      Conditions,
      HighInteger,
      ElementByIndex(SourceConditions, i),
      False
    );
  AddSubjectCondition(
    MirabelleInfo,
    'GetIsID',
    MirabelleBase,
    EqualConditionType,
    1.0
  );

  Add(MirabelleInfo, 'Responses', True);
  Responses := ElementByPath(MirabelleInfo, 'Responses');
  while ElementCount(Responses) > 0 do
    RemoveElement(Responses, 0);
  ElementAssign(
    Responses,
    HighInteger,
    ElementByIndex(SourceResponses, 0),
    False
  );

  SetElementEditValues(
    MirabelleInfo,
    'EDID',
    'DNT_WG_OpenParchment_Mirabelle'
  );
  SetElementEditValues(MirabelleInfo, 'RNAM', ParchmentPrompt);
  if Assigned(ElementByPath(MirabelleInfo, 'DNAM')) then
    RemoveElement(MirabelleInfo, 'DNAM');
  SetElementEditValues(
    MirabelleInfo,
    'Responses\Response\NAM1',
    ParchmentResponse
  );
  SetElementNativeValues(
    MirabelleInfo,
    'ENAM\Response Flags',
    SilentTerminalResponseFlagsMask
  );
  if Assigned(ElementByPath(MirabelleInfo, 'Link To')) then
    RemoveElement(MirabelleInfo, 'Link To');
  Add(MirabelleInfo, 'ANAM', True);
  SpeakerElement := ElementByPath(MirabelleInfo, 'ANAM');
  SetEditValue(SpeakerElement, Name(MirabelleBase));

  MirabelleFragmentScript := ConfigureInfoFragment(
    MirabelleInfo,
    TemplateInfo,
    'DNT_WizardParchmentFragment'
  );
  AddObjectProperty(MirabelleFragmentScript, 'Picker', PickerQuest);

  if GetElementEditValues(PickerInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Parchment prompt did not read back');
  if GetElementEditValues(MirabelleInfo, 'Responses\Response\NAM1') <>
    ParchmentResponse then
    raise Exception.Create('Mirabelle parchment response did not read back');
  SetElementNativeValues(PickerTopic, 'TIFC', 2);
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
  PickerQuest, PickerScript, WizardService: IInterface;
begin
  Result := 1;
  ReleaseMode := FileExists(
    ScriptsPath + '..\..\build\consolidated-release.mode'
  );
  StatusPath := ScriptsPath + '..\..\build\wizard-parchment.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-parchment.error';
  if ReleaseMode then begin
    PluginOutputPath := ScriptsPath +
      '..\..\build\release\DiegeticTravel.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\release-wizard-parchment-seq-formids.txt';
  end else begin
    PluginOutputPath := ScriptsPath +
      '..\..\modules\parchment-picker\mod\DiegeticTravelWizardParchment.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\wizard-parchment-seq-formids.txt';
  end;
  WriteTextFile(StatusPath, 'running');

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if ReleaseMode then
      WizardFile := FileByPluginName('DiegeticTravel.esp')
    else
      WizardFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    if not Assigned(SkyrimFile) or not Assigned(WizardFile) then
      raise Exception.Create('Required Skyrim or wizard plugin is missing');

    if ReleaseMode then begin
      OutputFile := WizardFile;
      ReserveNextObjectID($000A00);
    end else begin
      OutputFile := AddNewFileName(OutputPluginName);
      if not Assigned(OutputFile) then
        raise Exception.Create('Could not create ' + OutputPluginName);
      AddMasterIfMissing(OutputFile, 'Skyrim.esm');
      AddMasterIfMissing(OutputFile, 'Update.esm');
      AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
      AddMasterIfMissing(OutputFile, 'HearthFires.esm');
      AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
      AddMasterIfMissing(OutputFile, 'DiegeticTravelWizardGuides.esp');
    end;

    WizardService := RequireRecord(
      WizardFile,
      $000800,
      'QUST',
      'DNT_WizardTravelQuest'
    );
    PickerQuest := NewQuest(
      'DNT_WizardParchmentPickerQuest',
      'DNT_WizardParchmentPicker'
    );
    PickerScript := QuestScript(PickerQuest);
    AddObjectProperty(PickerScript, 'Service', WizardService);

    ConfigureParchmentDialogue(PickerQuest);
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormID(PickerQuest);
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Generated wizard parchment-picker adapter');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
