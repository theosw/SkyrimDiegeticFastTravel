unit DNT_GenerateWizardMapAdapter;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelWizardMap.esp';
  MapPrompt = 'Can you show me where you can send me? (250 gold per trip)';
  MapResponse = 'Let me show you.';
  OnBeginFragmentMask = $01;
  SilentTerminalResponseFlagsMask = $0A01;

var
  OutputFile, SkyrimFile, WizardFile, BCDFile: IInterface;
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

function RequireSkyrimRecord(
  FormIDValue: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := RecordByFormID(SkyrimFile, FormIDValue, True);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve Skyrim record ' + IntToHex(FormIDValue, 8)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      IntToHex(FormIDValue, 8) + ' is not ' + ExpectedEditorID
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
    raise Exception.Create('Could not create map INFO VMAD');
  ElementAssign(VMAD, LowInteger, SourceVMAD, False);
  VMAD := ElementByPath(InfoRecord, 'VMAD');

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) = 0) then
    raise Exception.Create('Map INFO VMAD has no script entry');
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
    raise Exception.Create('Map INFO VMAD has no fragment entry');
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
end;

procedure ConfigureMapDialogue(MapQuest: IInterface);
var
  HubInfo, SourceTopic, SourceBranch, MapTopic, MapBranch, InfoGroup,
    MapInfo, TemplateInfo,
    MapScript, Responses, SourceResponses, Conditions, SourceConditions:
    IInterface;
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

  MapTopic := wbCopyElementToFile(SourceTopic, OutputFile, True, False);
  if not Assigned(MapTopic) then
    raise Exception.Create('Could not clone faculty hub DIAL');
  SetElementEditValues(MapTopic, 'EDID', 'DNT_WG_OpenMap');
  SetElementEditValues(MapTopic, 'FULL', MapPrompt);

  MapBranch := wbCopyElementToFile(SourceBranch, OutputFile, True, False);
  if not Assigned(MapBranch) then
    raise Exception.Create('Could not clone faculty hub dialogue branch');
  SetElementEditValues(MapBranch, 'EDID', 'DNT_WG_OpenMapBranch');

  QuestElement := ElementByPath(MapTopic, 'QNAM');
  if not Assigned(QuestElement) then begin
    Add(MapTopic, 'QNAM', True);
    QuestElement := ElementByPath(MapTopic, 'QNAM');
  end;
  if not Assigned(QuestElement) then
    raise Exception.Create('Could not create map DIAL quest link');
  SetEditValue(QuestElement, Name(MapQuest));

  BranchElement := ElementByPath(MapTopic, 'BNAM');
  if not Assigned(BranchElement) then begin
    Add(MapTopic, 'BNAM', True);
    BranchElement := ElementByPath(MapTopic, 'BNAM');
  end;
  if not Assigned(BranchElement) then
    raise Exception.Create('Could not create map DIAL branch link');
  SetEditValue(BranchElement, Name(MapBranch));

  BranchQuestElement := ElementByPath(MapBranch, 'QNAM');
  if not Assigned(BranchQuestElement) then begin
    Add(MapBranch, 'QNAM', True);
    BranchQuestElement := ElementByPath(MapBranch, 'QNAM');
  end;
  if not Assigned(BranchQuestElement) then
    raise Exception.Create('Could not create map branch quest link');
  SetEditValue(BranchQuestElement, Name(MapQuest));
  SetElementNativeValues(MapBranch, 'TNAM', 0);
  SetElementNativeValues(MapBranch, 'DNAM', 1);

  StartingTopicElement := ElementByPath(MapBranch, 'SNAM');
  if not Assigned(StartingTopicElement) then begin
    Add(MapBranch, 'SNAM', True);
    StartingTopicElement := ElementByPath(MapBranch, 'SNAM');
  end;
  if not Assigned(StartingTopicElement) then
    raise Exception.Create('Could not create map branch starting-topic link');
  SetEditValue(StartingTopicElement, Name(MapTopic));

  ReadBack := LinksTo(ElementByPath(MapBranch, 'SNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(MapTopic)) then
    raise Exception.Create('Map topic is not the map branch starting topic');
  ReadBack := LinksTo(ElementByPath(MapTopic, 'BNAM'));
  if not Assigned(ReadBack) or (FormID(ReadBack) <> FormID(MapBranch)) then
    raise Exception.Create('Map topic does not point to its dedicated branch');

  InfoGroup := ChildGroup(MapTopic);
  if Assigned(InfoGroup) and (ElementCount(InfoGroup) <> 0) then
    raise Exception.Create('New map DIAL unexpectedly contains INFO records');
  MapInfo := Add(MapTopic, 'INFO', True);
  if not Assigned(MapInfo) then
    raise Exception.Create('Could not create map INFO');
  Add(MapInfo, 'ENAM', True);
  Add(MapInfo, 'CNAM', True);

  SourceConditions := ElementByPath(HubInfo, 'Conditions');
  if not Assigned(SourceConditions) then
    raise Exception.Create('Faculty hub has no conditions to copy');
  Add(MapInfo, 'Conditions', True);
  Conditions := ElementByPath(MapInfo, 'Conditions');
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
  Add(MapInfo, 'Responses', True);
  Responses := ElementByPath(MapInfo, 'Responses');
  while ElementCount(Responses) > 0 do
    RemoveElement(Responses, 0);
  ElementAssign(
    Responses,
    HighInteger,
    ElementByIndex(SourceResponses, 0),
    False
  );

  SetElementEditValues(MapInfo, 'EDID', 'DNT_WG_OpenMap_Faculty');
  SetElementEditValues(MapInfo, 'RNAM', MapPrompt);
  if Assigned(ElementByPath(MapInfo, 'DNAM')) then
    RemoveElement(MapInfo, 'DNAM');
  Responses := ElementByPath(MapInfo, 'Responses');
  if not Assigned(Responses) or (ElementCount(Responses) <> 1) then
    raise Exception.Create('Map INFO does not own exactly one response');
  SetElementEditValues(MapInfo, 'Responses\Response\NAM1', MapResponse);
  SetElementNativeValues(
    MapInfo,
    'ENAM\Response Flags',
    SilentTerminalResponseFlagsMask
  );
  if Assigned(ElementByPath(MapInfo, 'Link To')) then
    RemoveElement(MapInfo, 'Link To');

  TemplateInfo := RequireRecord(
    WizardFile,
    $00080B,
    'INFO',
    'DNT_WG_Whiterun_FromPhinis'
  );
  MapScript := ConfigureInfoFragment(
    MapInfo,
    TemplateInfo,
    'DNT_WizardMapFragment'
  );
  AddObjectProperty(MapScript, 'Picker', MapQuest);

  if GetElementEditValues(MapInfo, 'RNAM') <> MapPrompt then
    raise Exception.Create('Map prompt did not read back');
  if GetElementEditValues(MapInfo, 'Responses\Response\NAM1') <>
    MapResponse then
    raise Exception.Create('Map response did not read back');
  SetElementNativeValues(MapTopic, 'TIFC', 1);
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
  Whitelist, MapQuest, MapScript, WizardService, WhiterunMarker, RiftenMarker,
    SolitudeMarker, WindhelmMarker, MarkarthMarker: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-map-adapter.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-map-adapter.error';
  PluginOutputPath := ScriptsPath +
    '..\..\modules\wizard-map-picker\mod\DiegeticTravelWizardMap.esp';
  SeqFormIDsPath := ScriptsPath +
    '..\..\build\wizard-map-adapter-seq-formids.txt';
  WriteTextFile(StatusPath, 'running');

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    WizardFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    BCDFile := FileByPluginName('Better Carriage Destinations.esp');
    if not Assigned(SkyrimFile) or not Assigned(WizardFile) or
      not Assigned(BCDFile) then
      raise Exception.Create('Required Skyrim, wizard, or BCD plugin is missing');

    OutputFile := AddNewFileName(OutputPluginName);
    if not Assigned(OutputFile) then
      raise Exception.Create('Could not create ' + OutputPluginName);
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'DiegeticTravelWizardGuides.esp');
    AddMasterIfMissing(OutputFile, 'Better Carriage Destinations.esp');

    WhiterunMarker := RequireSkyrimRecord(
      $000162CE,
      'REFR',
      'WhiterunMapMarkerREF'
    );
    RiftenMarker := RequireSkyrimRecord(
      $0001C390,
      'REFR',
      'RiftenMapMarkerREF'
    );
    SolitudeMarker := RequireSkyrimRecord(
      $0004D0F4,
      'REFR',
      'SolitudeMapmarkerRef'
    );
    WindhelmMarker := RequireSkyrimRecord(
      $00038436,
      'REFR',
      'WindhelmMapMarkerRef'
    );
    MarkarthMarker := RequireSkyrimRecord(
      $0001C38A,
      'REFR',
      'MarkarthMapMarkerREF'
    );

    Whitelist := NewFormList('DNT_WizardMapMarkerWhitelist');
    AddFormListEntry(Whitelist, WhiterunMarker);
    AddFormListEntry(Whitelist, RiftenMarker);
    AddFormListEntry(Whitelist, SolitudeMarker);
    AddFormListEntry(Whitelist, WindhelmMarker);
    AddFormListEntry(Whitelist, MarkarthMarker);

    WizardService := RequireRecord(
      WizardFile,
      $000800,
      'QUST',
      'DNT_WizardTravelQuest'
    );
    MapQuest := NewQuest(
      'DNT_WizardMapPickerQuest',
      'DNT_WizardMapPicker'
    );
    MapScript := QuestScript(MapQuest);
    AddObjectProperty(MapScript, 'Service', WizardService);
    AddObjectProperty(MapScript, 'DestinationWhitelist', Whitelist);
    AddObjectProperty(MapScript, 'WhiterunMapMarker', WhiterunMarker);
    AddObjectProperty(MapScript, 'RiftenMapMarker', RiftenMarker);
    AddObjectProperty(MapScript, 'SolitudeMapMarker', SolitudeMarker);
    AddObjectProperty(MapScript, 'WindhelmMapMarker', WindhelmMarker);
    AddObjectProperty(MapScript, 'MarkarthMapMarker', MarkarthMarker);

    ConfigureMapDialogue(MapQuest);
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormID(MapQuest);
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Generated wizard BCD map-picker adapter');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
