unit DNT_AuditWizardMapAdapter;

uses SysUtils, Classes;

const
  MapPrompt = 'Can you show me where you can send me? (250 gold per trip)';
  MapResponse = 'Let me show you.';
  OnBeginFragmentMask = $01;
  SilentTerminalResponseFlagsMask = $0A01;
  GreaterThanOrEqualConditionType = $60;
  NotEqualConditionType = $20;

var
  AdapterFile, SkyrimFile, WizardFile: IInterface;
  ReportLines: TStringList;
  StatusPath, ErrorPath, ReportPath: string;

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

function DefinedRecordByObjectID(
  PluginFile: IInterface;
  ObjectID: Cardinal
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
end;

function RequireRecord(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(PluginFile, ObjectID);
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve ' + ExpectedEditorID);
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
    raise Exception.Create('Could not resolve ' + ExpectedEditorID);
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(ExpectedEditorID + ' has the wrong signature');
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(ExpectedEditorID + ' has the wrong EditorID');
end;

function RequireAdapterRecord(
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(AdapterFile, ExpectedSignature);
  if Assigned(RecordGroup) then
    for i := 0 to Pred(ElementCount(RecordGroup)) do begin
      Candidate := ElementByIndex(RecordGroup, i);
      if GetElementEditValues(Candidate, 'EDID') = ExpectedEditorID then begin
        Result := Candidate;
        Break;
      end;
    end;
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve adapter record ' +
      ExpectedEditorID);
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

function HasMasterNamed(const PluginName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(MasterCount(AdapterFile)) do
    if LowerCase(GetFileName(MasterByIndex(AdapterFile, i))) =
      LowerCase(PluginName) then begin
      Result := True;
      Exit;
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
    raise Exception.Create('Missing map INFO condition ' + IntToStr(Index));
  ConditionData := ElementByPath(ElementByIndex(Conditions, Index), 'CTDA');
  if GetElementEditValues(ConditionData, 'Function') <> FunctionName then
    raise Exception.Create('Map INFO condition function mismatch');
  if GetElementNativeValues(ConditionData, 'Type') <> ConditionType then
    raise Exception.Create('Map INFO condition type mismatch');
  if Abs(
    GetElementNativeValues(ConditionData, 'Comparison Value - Float') -
    ComparisonValue
  ) > 0.001 then
    raise Exception.Create('Map INFO condition comparison mismatch');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create('Map INFO condition is not subject-scoped');
  ActualParameter := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ActualParameter) or
    (FormID(ActualParameter) <> FormID(ParameterRecord)) then
    raise Exception.Create('Map INFO condition parameter mismatch');
end;

procedure AuditWhitelist;
var
  Whitelist, Entries, ActualRecord: IInterface;
  ExpectedRecords: array[0..4] of IInterface;
  i: Integer;
begin
  Whitelist := RequireAdapterRecord(
    'FLST',
    'DNT_WizardMapMarkerWhitelist'
  );
  ExpectedRecords[0] := RequireSkyrimRecord(
    $000162CE,
    'REFR',
    'WhiterunMapMarkerREF'
  );
  ExpectedRecords[1] := RequireSkyrimRecord(
    $0001C390,
    'REFR',
    'RiftenMapMarkerREF'
  );
  ExpectedRecords[2] := RequireSkyrimRecord(
    $0004D0F4,
    'REFR',
    'SolitudeMapmarkerRef'
  );
  ExpectedRecords[3] := RequireSkyrimRecord(
    $00038436,
    'REFR',
    'WindhelmMapMarkerRef'
  );
  ExpectedRecords[4] := RequireSkyrimRecord(
    $0001C38A,
    'REFR',
    'MarkarthMapMarkerREF'
  );
  Entries := ElementByPath(Whitelist, 'FormIDs');
  if not Assigned(Entries) or (ElementCount(Entries) <> 5) then
    raise Exception.Create('Wizard map whitelist does not have five entries');
  for i := 0 to 4 do begin
    ActualRecord := LinksTo(ElementByIndex(Entries, i));
    if not Assigned(ActualRecord) or
      (FormID(ActualRecord) <> FormID(ExpectedRecords[i])) then
      raise Exception.Create('Wizard map whitelist entry mismatch at ' +
        IntToStr(i));
  end;
  ReportLines.Add('PASS whitelist -> whiterun,riften,solitude,windhelm,markarth');
end;

procedure AuditQuest;
var
  MapQuest, WizardService, Whitelist, VMAD, Scripts, ScriptEntry,
    Properties: IInterface;
begin
  MapQuest := RequireAdapterRecord(
    'QUST',
    'DNT_WizardMapPickerQuest'
  );
  if (GetElementNativeValues(MapQuest, 'DNAM\Flags') and 1) = 0 then
    raise Exception.Create('Wizard map quest is not start-game enabled');
  if GetElementNativeValues(MapQuest, 'DNAM\Priority') <> 60 then
    raise Exception.Create('Wizard map quest priority is not 60');
  VMAD := ElementByPath(MapQuest, 'VMAD');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Wizard map quest does not have one script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardMapPicker' then
    raise Exception.Create('Wizard map quest script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 7) then
    raise Exception.Create('Wizard map quest does not have seven properties');

  WizardService := RequireRecord(
    WizardFile,
    $000800,
    'QUST',
    'DNT_WizardTravelQuest'
  );
  Whitelist := RequireAdapterRecord(
    'FLST',
    'DNT_WizardMapMarkerWhitelist'
  );
  AssertProperty(ScriptEntry, 'Service', WizardService);
  AssertProperty(ScriptEntry, 'DestinationWhitelist', Whitelist);
  AssertProperty(
    ScriptEntry,
    'WhiterunMapMarker',
    RequireSkyrimRecord($000162CE, 'REFR', 'WhiterunMapMarkerREF')
  );
  AssertProperty(
    ScriptEntry,
    'RiftenMapMarker',
    RequireSkyrimRecord($0001C390, 'REFR', 'RiftenMapMarkerREF')
  );
  AssertProperty(
    ScriptEntry,
    'SolitudeMapMarker',
    RequireSkyrimRecord($0004D0F4, 'REFR', 'SolitudeMapmarkerRef')
  );
  AssertProperty(
    ScriptEntry,
    'WindhelmMapMarker',
    RequireSkyrimRecord($00038436, 'REFR', 'WindhelmMapMarkerRef')
  );
  AssertProperty(
    ScriptEntry,
    'MarkarthMapMarker',
    RequireSkyrimRecord($0001C38A, 'REFR', 'MarkarthMapMarkerREF')
  );
  ReportLines.Add('PASS map quest -> core service and five exact marker properties');
end;

procedure AuditDialogue;
var
  MapTopic, MapBranch, InfoGroup, MapInfo, Conditions, VMAD,
    Scripts, ScriptEntry, Properties, PickerQuest, TopicQuest, BranchQuest,
    StartingTopic, HubInfo, HubTopic, CoreBranch, ActualBranch: IInterface;
begin
  PickerQuest := RequireAdapterRecord(
    'QUST',
    'DNT_WizardMapPickerQuest'
  );
  MapBranch := RequireAdapterRecord(
    'DLBR',
    'DNT_WG_OpenMapBranch'
  );
  MapTopic := RequireAdapterRecord(
    'DIAL',
    'DNT_WG_OpenMap'
  );
  if GetElementEditValues(MapTopic, 'FULL') <> MapPrompt then
    raise Exception.Create('Wizard map DIAL prompt does not match');
  TopicQuest := LinksTo(ElementByPath(MapTopic, 'QNAM'));
  if not Assigned(TopicQuest) or
    (FormID(TopicQuest) <> FormID(PickerQuest)) then
    raise Exception.Create(
      'Wizard map DIAL is not owned by the map quest; QNAM=' +
      GetElementEditValues(MapTopic, 'QNAM')
    );
  BranchQuest := LinksTo(ElementByPath(MapBranch, 'QNAM'));
  if not Assigned(BranchQuest) or
    (FormID(BranchQuest) <> FormID(PickerQuest)) then
    raise Exception.Create('Wizard map branch is not owned by the map quest');
  if GetElementNativeValues(MapBranch, 'TNAM') <> 0 then
    raise Exception.Create('Wizard map branch category is not Player');
  if GetElementNativeValues(MapBranch, 'DNAM') <> 1 then
    raise Exception.Create(
      'Wizard map branch is not a non-blocking, non-exclusive top-level branch'
    );
  StartingTopic := LinksTo(ElementByPath(MapBranch, 'SNAM'));
  if not Assigned(StartingTopic) or
    (FormID(StartingTopic) <> FormID(MapTopic)) then
    raise Exception.Create('Wizard map topic is not its branch starting topic');

  HubInfo := RequireRecord(
    WizardFile,
    $000808,
    'INFO',
    'DNT_WG_Request_Phinis'
  );
  HubTopic := TopicContainingInfo(WizardFile, HubInfo);
  if not Assigned(HubTopic) then
    raise Exception.Create('Could not resolve faculty hub topic');
  CoreBranch := LinksTo(ElementByPath(HubTopic, 'BNAM'));
  ActualBranch := LinksTo(ElementByPath(MapTopic, 'BNAM'));
  if not Assigned(CoreBranch) or not Assigned(ActualBranch) then
    raise Exception.Create('Could not resolve core or map dialogue branch');
  if FormID(ActualBranch) <> FormID(MapBranch) then
    raise Exception.Create('Wizard map DIAL does not point to its map branch');
  if FormID(ActualBranch) = FormID(CoreBranch) then
    raise Exception.Create('Wizard map DIAL incorrectly reuses the core branch');
  InfoGroup := ChildGroup(MapTopic);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 1) then
    raise Exception.Create('Wizard map DIAL does not contain one INFO');
  MapInfo := ElementByIndex(InfoGroup, 0);
  if GetElementEditValues(MapInfo, 'EDID') <>
    'DNT_WG_OpenMap_Faculty' then
    raise Exception.Create('Wizard map INFO EditorID does not match');
  if GetElementEditValues(MapInfo, 'RNAM') <> MapPrompt then
    raise Exception.Create('Wizard map INFO prompt does not match');
  if GetElementEditValues(MapInfo, 'Responses\Response\NAM1') <>
    MapResponse then
    raise Exception.Create('Wizard map response does not match');
  if GetElementNativeValues(MapInfo, 'ENAM\Response Flags') <>
    SilentTerminalResponseFlagsMask then
    raise Exception.Create('Wizard map response flags do not match');
  if Assigned(ElementByPath(MapInfo, 'DNAM')) then
    raise Exception.Create('Wizard map INFO unexpectedly uses SharedInfo');
  if Assigned(ElementByPath(MapInfo, 'Link To')) then
    raise Exception.Create('Wizard map INFO unexpectedly links a submenu');

  Conditions := ElementByPath(MapInfo, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 3) then
    raise Exception.Create('Wizard map INFO does not have three faculty conditions');
  AssertCondition(
    MapInfo,
    0,
    'GetFactionRank',
    RequireSkyrimRecord($0001F259, 'FACT', 'CollegeofWinterholdFaction'),
    GreaterThanOrEqualConditionType,
    3.0
  );
  AssertCondition(
    MapInfo,
    1,
    'GetIsID',
    RequireSkyrimRecord($0006A152, 'NPC_', 'MGArnielSummon'),
    NotEqualConditionType,
    1.0
  );
  AssertCondition(
    MapInfo,
    2,
    'GetIsID',
    RequireSkyrimRecord($0003B0E4, 'NPC_', 'dunAlftandEndrast'),
    NotEqualConditionType,
    1.0
  );

  VMAD := ElementByPath(MapInfo, 'VMAD');
  if not Assigned(VMAD) or
    (GetElementNativeValues(VMAD, 'Script Fragments\Flags') <>
      OnBeginFragmentMask) or
    (GetElementEditValues(VMAD, 'Script Fragments\FileName') <>
      'DNT_WizardMapFragment') then
    raise Exception.Create('Wizard map INFO fragment metadata does not match');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create('Wizard map INFO does not have one fragment script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardMapFragment' then
    raise Exception.Create('Wizard map fragment script does not match');
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 1) then
    raise Exception.Create('Wizard map fragment does not have one property');
  AssertProperty(ScriptEntry, 'Picker', PickerQuest);
  ReportLines.Add(
    'PASS dedicated top-level branch -> starting topic -> BCD picker fragment'
  );
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-map-adapter-audit.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-map-adapter-audit.error';
  ReportPath := ScriptsPath +
    '..\..\build\wizard-map-adapter-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    AdapterFile := FileByPluginName('DiegeticTravelWizardMap.esp');
    SkyrimFile := FileByPluginName('Skyrim.esm');
    WizardFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    if not Assigned(AdapterFile) or not Assigned(SkyrimFile) or
      not Assigned(WizardFile) then
      raise Exception.Create('Required adapter audit plugin is missing');
    if not HasMasterNamed('DiegeticTravelWizardGuides.esp') then
      raise Exception.Create('Adapter does not master the core wizard plugin');
    if not HasMasterNamed('Better Carriage Destinations.esp') then
      raise Exception.Create('Adapter does not master BCD');

    AuditWhitelist;
    AuditQuest;
    AuditDialogue;
    ReportLines.Add('PASS wizard map-adapter audit complete');
    ReportLines.SaveToFile(ReportPath);
    WriteTextFile(StatusPath, 'success');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
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
