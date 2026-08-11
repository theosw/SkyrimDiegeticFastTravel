unit DNT_GenerateBoatNorthCoast;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelBoatNorthCoast.esp';
  BoatPrompt = 'Could you show me your northern routes?';
  OnEndFragmentMask = $02;
  GoodbyeResponseFlagsMask = $0001;
  EqualConditionType = $00;

var
  OutputFile, SkyrimFile, DawnguardFile, CftoFile: IInterface;
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
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve ' + ExpectedSignature + ' object ' +
      IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      IntToHex(ObjectID, 6) + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if (ExpectedEditorID <> '') and
    (GetElementEditValues(Result, 'EDID') <> ExpectedEditorID) then
    raise Exception.Create(
      IntToHex(ObjectID, 6) + ' is not ' + ExpectedEditorID
    );
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
      'North-coast FormID range is already occupied: ' +
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

function NewFormList(const EditorIDValue: string): IInterface;
begin
  Result := Add(EnsureTopGroup('FLST'), 'FLST', True);
  SetElementEditValues(Result, 'EDID', EditorIDValue);
  if GetElementEditValues(Result, 'EDID') <> EditorIDValue then
    raise Exception.Create('Could not set FLST EditorID: ' + EditorIDValue);
end;

procedure AddFormListEntry(ListRecord, EntryRecord: IInterface);
var
  Entries, Entry, ReadBack: IInterface;
begin
  Entries := ElementByPath(ListRecord, 'FormIDs');
  if not Assigned(Entries) then begin
    Add(ListRecord, 'FormIDs', True);
    Entries := ElementByPath(ListRecord, 'FormIDs');
  end;
  if not Assigned(Entries) then
    raise Exception.Create('Could not create FLST entries');
  if (ElementCount(Entries) = 1) and
    not Assigned(LinksTo(ElementByIndex(Entries, 0))) then
    Entry := ElementByIndex(Entries, 0)
  else
    Entry := ElementAssign(Entries, HighInteger, nil, False);
  SetEditValue(Entry, Name(EntryRecord));
  ReadBack := LinksTo(Entry);
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(EntryRecord)) then
    raise Exception.Create('FLST entry did not read back');
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
    raise Exception.Create('Could not create boat INFO VMAD');
  ElementAssign(VMAD, LowInteger, SourceVMAD, False);
  VMAD := ElementByPath(InfoRecord, 'VMAD');

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) = 0) then
    raise Exception.Create('Boat INFO VMAD has no script entry');
  while ElementCount(Scripts) > 1 do
    RemoveElement(Scripts, Pred(ElementCount(Scripts)));
  Result := ElementByIndex(Scripts, 0);
  SetElementEditValues(Result, 'ScriptName', ScriptName);
  Properties := ElementByPath(Result, 'Properties');
  while Assigned(Properties) and (ElementCount(Properties) > 0) do
    RemoveElement(Properties, 0);

  SetElementEditValues(VMAD, 'Script Fragments\FileName', ScriptName);
  SetElementNativeValues(
    VMAD,
    'Script Fragments\Flags',
    OnEndFragmentMask
  );
  Fragments := ElementByPath(VMAD, 'Script Fragments\Fragments');
  if not Assigned(Fragments) or (ElementCount(Fragments) = 0) then
    raise Exception.Create('Boat INFO VMAD has no fragment entry');
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
end;

procedure ConfigureDialogue(PickerQuest, ProviderWhitelist: IInterface);
var
  SourceTopic, SourceBranch, TopicRecord, BranchRecord, InfoRecord,
    InfoGroup, TemplateInfo, SharedInfo, FragmentScript, QuestElement,
    BranchElement, BranchQuestElement, StartingTopicElement, ReadBack,
    Conditions, DialogueFaction: IInterface;
begin
  SourceTopic := RequireRecord(
    CftoFile,
    $00AA0E,
    'DIAL',
    'KmodFastTravelFerryTopic'
  );
  SourceBranch := LinksTo(ElementByPath(SourceTopic, 'BNAM'));
  if not Assigned(SourceBranch) or (Signature(SourceBranch) <> 'DLBR') then
    raise Exception.Create('Route 1 source topic has no dialogue branch');

  TopicRecord := wbCopyElementToFile(SourceTopic, OutputFile, True, False);
  BranchRecord := wbCopyElementToFile(SourceBranch, OutputFile, True, False);
  if not Assigned(TopicRecord) or not Assigned(BranchRecord) then
    raise Exception.Create('Could not clone Route 1 dialogue shell');

  SetElementEditValues(TopicRecord, 'EDID', 'DNT_BoatNorthCoastParchmentTopic');
  SetElementEditValues(TopicRecord, 'FULL', BoatPrompt);
  SetElementEditValues(BranchRecord, 'EDID', 'DNT_BoatNorthCoastParchmentBranch');

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
    raise Exception.Create('Boat topic does not point to its branch');
  ReadBack := LinksTo(ElementByPath(BranchRecord, 'SNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(TopicRecord)) then
    raise Exception.Create('Boat branch does not start at its topic');

  InfoGroup := ChildGroup(TopicRecord);
  if Assigned(InfoGroup) and (ElementCount(InfoGroup) <> 0) then
    raise Exception.Create('New boat DIAL unexpectedly contains INFOs');
  InfoRecord := Add(TopicRecord, 'INFO', True);
  Add(InfoRecord, 'ENAM', True);
  Add(InfoRecord, 'CNAM', True);
  SetElementEditValues(InfoRecord, 'EDID', 'DNT_BoatNorthCoastParchmentInfo');
  SetElementEditValues(InfoRecord, 'RNAM', BoatPrompt);
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    GoodbyeResponseFlagsMask
  );

  DialogueFaction := RequireRecord(
    CftoFile,
    $00AA05,
    'FACT',
    'KmodFastTravelDialogueFaction'
  );
  Add(InfoRecord, 'Conditions', True);
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  while Assigned(Conditions) and (ElementCount(Conditions) > 0) do
    RemoveElement(Conditions, 0);
  AddSubjectCondition(
    InfoRecord,
    'GetInFaction',
    DialogueFaction,
    EqualConditionType,
    1.0
  );
  AddSubjectCondition(
    InfoRecord,
    'IsInList',
    ProviderWhitelist,
    EqualConditionType,
    1.0
  );
  SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO', '');
  Add(InfoRecord, 'DNAM', True);
  SetEditValue(ElementByPath(InfoRecord, 'DNAM'), Name(SharedInfo));

  TemplateInfo := RequireRecord(CftoFile, $019DC8, 'INFO', '');
  FragmentScript := ConfigureInfoFragment(
    InfoRecord,
    TemplateInfo,
    'DNT_NorthCoastBoatParchmentFragment'
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
  BoatQuest, ServiceScript, PickerScript, ProviderWhitelist: IInterface;
begin
  Result := 1;
  ReleaseMode := FileExists(
    ScriptsPath + '..\..\build\consolidated-release.mode'
  );
  StatusPath := ScriptsPath + '..\..\build\boat-north-coast.status';
  ErrorPath := ScriptsPath + '..\..\build\boat-north-coast.error';
  if ReleaseMode then begin
    PluginOutputPath := ScriptsPath +
      '..\..\build\release\DiegeticTravel.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\release-boat-north-coast-seq-formids.txt';
  end else begin
    PluginOutputPath := ScriptsPath +
      '..\..\modules\boat-north-coast\mod\DiegeticTravelBoatNorthCoast.esp';
    SeqFormIDsPath := ScriptsPath +
      '..\..\build\boat-north-coast-seq-formids.txt';
  end;
  WriteTextFile(StatusPath, 'running');

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(SkyrimFile) or not Assigned(DawnguardFile) or
      not Assigned(CftoFile) then
      raise Exception.Create('Required Skyrim, Dawnguard, or CFTO file is missing');

    if ReleaseMode then begin
      OutputFile := FileByPluginName('DiegeticTravel.esp');
      if not Assigned(OutputFile) then
        raise Exception.Create('Consolidated release plugin is missing');
      ReserveNextObjectID($000A80);
    end else begin
      OutputFile := AddNewFileName(OutputPluginName);
      if not Assigned(OutputFile) then
        raise Exception.Create('Could not create ' + OutputPluginName);
      AddMasterIfMissing(OutputFile, 'Skyrim.esm');
      AddMasterIfMissing(OutputFile, 'Update.esm');
      AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
      AddMasterIfMissing(OutputFile, 'HearthFires.esm');
      AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
      AddMasterIfMissing(OutputFile, 'CFTO.esp');
    end;

    ProviderWhitelist := NewFormList('DNT_BoatNorthCoastProviders');
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $00AA07, 'NPC_', 'KmodFerrymanDawnstar'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $00AA08, 'NPC_', 'KmodFerrymanSolitude'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $00AA09, 'NPC_', 'KmodFerrymanWindhelm'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $00AA0B, 'NPC_', 'KmodFerrymanMorthal'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $014C5A, 'NPC_', 'KmodFerrymanLighthouse'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $158FFC, 'NPC_', 'KmodFerrymanWinterhold'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $2D4C09, 'NPC_', 'KmodFerrymanDragonBridge'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $014C89, 'NPC_', 'KmodFerrymanWindstad'
    ));
    AddFormListEntry(ProviderWhitelist, RequireRecord(
      CftoFile, $1F0E6A, 'NPC_', 'KmodFerrymanVolkihar'
    ));

    BoatQuest := NewQuest('DNT_BoatNorthCoastQuest');
    ServiceScript := AddScript(BoatQuest, 'DNT_NorthCoastBoatTravelService');
    PickerScript := AddScript(BoatQuest, 'DNT_NorthCoastBoatParchmentPicker');
    AddObjectProperty(PickerScript, 'Service', BoatQuest);

    ConfigureDialogue(BoatQuest, ProviderWhitelist);
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormID(BoatQuest);
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Generated north-coast boat parchment candidate');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
