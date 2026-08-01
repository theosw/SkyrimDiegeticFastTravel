unit DNT_GenerateWizardParchmentAdapter;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelWizardParchment.esp';
  ParchmentPrompt =
    'Could you show me your travel map? (250 gold per trip)';
  ParchmentResponse = 'Let me show you.';
  OnBeginFragmentMask = $01;
  SilentTerminalResponseFlagsMask = $0A01;

var
  OutputFile, SkyrimFile, WizardFile: IInterface;
  StatusPath, ErrorPath, PluginOutputPath, SeqOutputPath: string;

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
    PickerInfo, TemplateInfo, FragmentScript, Responses, SourceResponses,
    Conditions, SourceConditions: IInterface;
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
  SetElementEditValues(
    PickerInfo,
    'Responses\Response\NAM1',
    ParchmentResponse
  );
  SetElementNativeValues(
    PickerInfo,
    'ENAM\Response Flags',
    SilentTerminalResponseFlagsMask
  );
  if Assigned(ElementByPath(PickerInfo, 'Link To')) then
    RemoveElement(PickerInfo, 'Link To');

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

  if GetElementEditValues(PickerInfo, 'RNAM') <> ParchmentPrompt then
    raise Exception.Create('Parchment prompt did not read back');
  if GetElementEditValues(PickerInfo, 'Responses\Response\NAM1') <>
    ParchmentResponse then
    raise Exception.Create('Parchment response did not read back');
  SetElementNativeValues(PickerTopic, 'TIFC', 1);
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

procedure SaveGeneratedSeq(QuestRecord: IInterface);
var
  OutputStream: TFileStream;
  FixedID: Cardinal;
begin
  FixedID := FixedFormID(QuestRecord);
  OutputStream := TFileStream.Create(SeqOutputPath, fmCreate);
  try
    OutputStream.WriteBuffer(FixedID, 4);
  finally
    OutputStream.Free;
  end;
end;

function Initialize: Integer;
var
  PickerQuest, PickerScript, WizardService: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-parchment.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-parchment.error';
  PluginOutputPath := ScriptsPath +
    '..\..\modules\parchment-picker\mod\DiegeticTravelWizardParchment.esp';
  SeqOutputPath := ScriptsPath +
    '..\..\modules\parchment-picker\mod\SEQ\DiegeticTravelWizardParchment.seq';
  WriteTextFile(StatusPath, 'running');

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    WizardFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    if not Assigned(SkyrimFile) or not Assigned(WizardFile) then
      raise Exception.Create('Required Skyrim or wizard plugin is missing');

    OutputFile := AddNewFileName(OutputPluginName);
    if not Assigned(OutputFile) then
      raise Exception.Create('Could not create ' + OutputPluginName);
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'DiegeticTravelWizardGuides.esp');

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
    SaveGeneratedSeq(PickerQuest);
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
