unit DNT_InventoryCarriageParchment;

uses SysUtils, Classes;

var
  CftoFile: IInterface;
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

function RequireAnyRecord(
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
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve object ' + IntToHex(ObjectID, 6));
end;

procedure AddElementTree(
  ElementValue: IInterface;
  const Prefix: string;
  Depth: Integer
);
var
  Child: IInterface;
  i: Integer;
begin
  if not Assigned(ElementValue) then begin
    ReportLines.Add(Prefix + '|MISSING=1');
    Exit;
  end;
  ReportLines.Add(
    Prefix +
    '|DEPTH=' + IntToStr(Depth) +
    '|NAME=' + Name(ElementValue) +
    '|PATH=' + Path(ElementValue) +
    '|VALUE=' + GetEditValue(ElementValue)
  );
  if Depth >= 9 then
    Exit;
  for i := 0 to Pred(ElementCount(ElementValue)) do begin
    Child := ElementByIndex(ElementValue, i);
    AddElementTree(Child, Prefix, Succ(Depth));
  end;
end;

procedure SearchElementTree(
  ElementValue, RootRecord: IInterface;
  const Needle, Prefix: string;
  Depth: Integer
);
var
  Child: IInterface;
  SearchValue: string;
  i: Integer;
begin
  if not Assigned(ElementValue) or (Depth > 18) then
    Exit;
  SearchValue := LowerCase(Name(ElementValue) + '|' + GetEditValue(ElementValue));
  if Pos(LowerCase(Needle), SearchValue) > 0 then
    ReportLines.Add(
      Prefix +
      '|RECORD=' + GetElementEditValues(RootRecord, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(RootRecord), 8) +
      '|PATH=' + Path(ElementValue) +
      '|NAME=' + Name(ElementValue) +
      '|VALUE=' + GetEditValue(ElementValue)
    );
  for i := 0 to Pred(ElementCount(ElementValue)) do begin
    Child := ElementByIndex(ElementValue, i);
    SearchElementTree(Child, RootRecord, Needle, Prefix, Succ(Depth));
  end;
end;

procedure FindCftoScriptBindings;
var
  QuestGroup, QuestRecord: IInterface;
  i: Integer;
begin
  QuestGroup := GroupBySignature(CftoFile, 'QUST');
  if not Assigned(QuestGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(QuestGroup)) do begin
    QuestRecord := ElementByIndex(QuestGroup, i);
    SearchElementTree(
      QuestRecord,
      QuestRecord,
      'KmodCarriageScript',
      'SCRIPT_BINDING',
      0
    );
  end;
end;

procedure AddDriverVoice(ObjectID: Cardinal);
var
  SourceDriverRecord, DriverRecord, ActorRecord, VoiceType, LinkedReferences, LinkedEntry,
    LinkedKeyword, LinkedRef, TemplateRecord, TemplateRecord2: IInterface;
  i: Integer;
begin
  SourceDriverRecord := RequireAnyRecord(CftoFile, ObjectID);
  DriverRecord := WinningOverride(SourceDriverRecord);
  if Signature(DriverRecord) = 'NPC_' then
    ActorRecord := DriverRecord
  else if (Signature(DriverRecord) = 'REFR') or
    (Signature(DriverRecord) = 'ACHR') then
    ActorRecord := WinningOverride(LinksTo(ElementByPath(DriverRecord, 'NAME')))
  else
    raise Exception.Create(
      'Configured driver has unsupported signature ' + Signature(DriverRecord)
    );
  if not Assigned(ActorRecord) or (Signature(ActorRecord) <> 'NPC_') then
    raise Exception.Create('Configured driver does not resolve to an NPC');
  VoiceType := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  ReportLines.Add(
    'DRIVER=' + GetElementEditValues(DriverRecord, 'EDID') +
    '|WINNER_PLUGIN=' + GetFileName(GetFile(DriverRecord)) +
    '|DRIVER_FORM=' + IntToHex(FixedFormID(DriverRecord), 8) +
    '|DRIVER_SIGNATURE=' + Signature(DriverRecord) +
    '|ACTOR=' + GetElementEditValues(ActorRecord, 'EDID') +
    '|NAME=' + GetElementEditValues(ActorRecord, 'FULL') +
    '|ACTOR_FORM=' + IntToHex(FixedFormID(ActorRecord), 8) +
    '|VOICE=' + GetElementEditValues(VoiceType, 'EDID') +
      '|VOICE_FORM=' + IntToHex(FixedFormID(VoiceType), 8)
  );
  LinkedReferences := ElementByPath(DriverRecord, 'Linked References');
  if not Assigned(LinkedReferences) then begin
    ReportLines.Add(
      'DRIVER_LINK_COUNT=0|DRIVER_FORM=' +
      IntToHex(FixedFormID(DriverRecord), 8)
    );
    Exit;
  end;
  ReportLines.Add(
    'DRIVER_LINK_COUNT=' + IntToStr(ElementCount(LinkedReferences)) +
    '|DRIVER_FORM=' + IntToHex(FixedFormID(DriverRecord), 8)
  );
  for i := 0 to Pred(ElementCount(LinkedReferences)) do begin
    LinkedEntry := ElementByIndex(LinkedReferences, i);
    LinkedKeyword := LinksTo(ElementByPath(LinkedEntry, 'Keyword/Ref'));
    LinkedRef := LinksTo(ElementByPath(LinkedEntry, 'Ref'));
    ReportLines.Add(
      'DRIVER_LINK=' + IntToStr(i) +
      '|DRIVER_FORM=' + IntToHex(FixedFormID(DriverRecord), 8) +
      '|KEYWORD=' + GetElementEditValues(LinkedKeyword, 'EDID') +
      '|KEYWORD_FORM=' + IntToHex(FixedFormID(LinkedKeyword), 8) +
      '|REF=' + GetElementEditValues(LinkedRef, 'EDID') +
      '|REF_FORM=' + IntToHex(FixedFormID(LinkedRef), 8) +
      '|REF_SIGNATURE=' + Signature(LinkedRef)
    );
  end;
  if ObjectID = $1C355D then begin
    AddElementTree(DriverRecord, 'DRIVER_TREE', 0);
    AddElementTree(ActorRecord, 'ACTOR_TREE', 0);
    TemplateRecord := WinningOverride(
      LinksTo(ElementByPath(ActorRecord, 'TPLT'))
    );
    AddElementTree(TemplateRecord, 'ACTOR_TEMPLATE_TREE', 0);
    TemplateRecord2 := WinningOverride(
      LinksTo(ElementByPath(TemplateRecord, 'TPLT'))
    );
    ReportLines.Add(
      'ACTOR_BASE_TEMPLATE_WINNER=' + GetFileName(GetFile(TemplateRecord2)) +
      '|FORM=' + IntToHex(FixedFormID(TemplateRecord2), 8)
    );
    AddElementTree(TemplateRecord2, 'ACTOR_BASE_TEMPLATE_TREE', 0);
    AddElementTree(ElementByPath(DriverRecord, 'VMAD'), 'DRIVER_VMAD', 0);
    AddElementTree(ElementByPath(ActorRecord, 'VMAD'), 'ACTOR_VMAD', 0);
    SearchElementTree(
      DriverRecord,
      DriverRecord,
      'KmodCarriageScript',
      'DRIVER_SCRIPT_SEARCH',
      0
    );
    SearchElementTree(
      ActorRecord,
      ActorRecord,
      'KmodCarriageScript',
      'ACTOR_SCRIPT_SEARCH',
      0
    );
  end;
end;

procedure AddConditions(InfoRecord: IInterface);
var
  Conditions, ConditionData, ParameterRecord: IInterface;
  i: Integer;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then begin
    ReportLines.Add('CONDITION_COUNT=0');
    Exit;
  end;
  ReportLines.Add('CONDITION_COUNT=' + IntToStr(ElementCount(Conditions)));
  for i := 0 to Pred(ElementCount(Conditions)) do begin
    ConditionData := ElementByPath(ElementByIndex(Conditions, i), 'CTDA');
    ParameterRecord := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
    ReportLines.Add(
      'CONDITION=' + IntToStr(i) +
      '|FUNCTION=' + GetElementEditValues(ConditionData, 'Function') +
      '|TYPE=' + IntToHex(GetElementNativeValues(ConditionData, 'Type'), 2) +
      '|RUN_ON=' + IntToStr(GetElementNativeValues(ConditionData, 'Run On')) +
      '|PARAM=' + GetElementEditValues(ParameterRecord, 'EDID') +
      '|PARAM_FORM=' + IntToHex(FixedFormID(ParameterRecord), 8)
    );
  end;
end;

procedure AddInfo(ObjectID: Cardinal; const LabelValue: string);
var
  InfoRecord, SharedInfo: IInterface;
begin
  InfoRecord := RequireRecord(CftoFile, ObjectID, 'INFO');
  SharedInfo := LinksTo(ElementByPath(InfoRecord, 'DNAM'));
  ReportLines.Add(
    'INFO=' + LabelValue +
    '|FORM=' + IntToHex(FixedFormID(InfoRecord), 8) +
    '|EDID=' + GetElementEditValues(InfoRecord, 'EDID') +
    '|PROMPT=' + GetElementEditValues(InfoRecord, 'RNAM') +
    '|RESPONSE=' + GetElementEditValues(
      InfoRecord,
      'Responses\Response\NAM1'
    ) +
    '|FLAGS=' + IntToHex(GetElementNativeValues(
      InfoRecord,
      'ENAM\Response Flags'
    ), 4) +
    '|SHARED_EDID=' + GetElementEditValues(SharedInfo, 'EDID') +
    '|SHARED_FORM=' + IntToHex(FixedFormID(SharedInfo), 8) +
    '|FRAGMENT_FILE=' + GetElementEditValues(
      InfoRecord,
      'VMAD\Script Fragments\FileName'
    )
  );
  AddConditions(InfoRecord);
end;

procedure AddMapMarker(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const StopId: string
);
var
  MarkerRecord: IInterface;
begin
  MarkerRecord := RequireRecord(PluginFile, ObjectID, 'REFR');
  ReportLines.Add(
    'MARKER=' + StopId +
    '|PLUGIN=' + GetFileName(PluginFile) +
    '|FORM=' + IntToHex(FixedFormID(MarkerRecord), 8) +
    '|EDID=' + GetElementEditValues(MarkerRecord, 'EDID') +
    '|NAME=' + GetElementEditValues(MarkerRecord, 'Map Marker\Full Name') +
    '|TYPE=' + GetElementEditValues(MarkerRecord, 'Map Marker\Marker Data\Type') +
    '|TYPE_VALUE=' + IntToStr(GetElementNativeValues(
      MarkerRecord,
      'Map Marker\Marker Data\Type'
    )) +
    '|X=' + GetElementEditValues(MarkerRecord, 'DATA\Position\X') +
    '|Y=' + GetElementEditValues(MarkerRecord, 'DATA\Position\Y') +
    '|Z=' + GetElementEditValues(MarkerRecord, 'DATA\Position\Z')
  );
end;

procedure AddRecordIdentity(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const LabelValue: string
);
var
  RecordValue: IInterface;
begin
  RecordValue := RequireAnyRecord(PluginFile, ObjectID);
  ReportLines.Add(
    'RECORD_IDENTITY=' + LabelValue +
    '|PLUGIN=' + GetFileName(GetFile(RecordValue)) +
    '|FORM=' + IntToHex(FixedFormID(RecordValue), 8) +
    '|SIGNATURE=' + Signature(RecordValue) +
    '|EDID=' + GetElementEditValues(RecordValue, 'EDID') +
    '|NAME=' + GetElementEditValues(RecordValue, 'FULL')
  );
end;

function Initialize: Integer;
var
  SkyrimFile, HearthFiresFile, TopicRecord, BranchRecord: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\carriage-parchment-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\carriage-parchment-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\carriage-parchment-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(CftoFile) then
      raise Exception.Create('Required CFTO file is missing');
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Required Skyrim master is missing');
    HearthFiresFile := FileByPluginName('HearthFires.esm');
    if not Assigned(HearthFiresFile) then
      raise Exception.Create('Required HearthFires master is missing');

    AddRecordIdentity(SkyrimFile, $107701, 'lorerim_winning_link_keyword');

    AddDriverVoice($0BBF91);
    AddDriverVoice($0BBF90);
    AddDriverVoice($09D8BF);
    AddDriverVoice($0BBF8E);
    AddDriverVoice($0BBF7F);
    AddDriverVoice($0BBF76);
    AddDriverVoice($0BBF6D);
    AddDriverVoice($0BBF6E);
    AddDriverVoice($1C355D);
    FindCftoScriptBindings;

    TopicRecord := RequireRecord(CftoFile, $09D8C6, 'DIAL');
    BranchRecord := RequireRecord(CftoFile, $09D8C5, 'DLBR');
    ReportLines.Add(
      'ROOT_TOPIC=' + GetElementEditValues(TopicRecord, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(TopicRecord), 8) +
      '|PROMPT=' + GetElementEditValues(TopicRecord, 'FULL') +
      '|BRANCH=' + GetElementEditValues(BranchRecord, 'EDID') +
      '|BRANCH_FORM=' + IntToHex(FixedFormID(BranchRecord), 8)
    );
    AddInfo($09D8C7, 'paid_root');
    AddInfo($0DA634, 'free_root');
    AddInfo($09D913, 'darkwater_success');
    AddInfo($0A2A2D, 'halfmoon_success');

    { CFTO's 27 executable carriage destinations. Their persistent world-map
      references are the coordinate authority for the beta parchment. }
    AddMapMarker(SkyrimFile, $01773A, 'dawnstar');
    AddMapMarker(SkyrimFile, $017760, 'falkreath');
    AddMapMarker(SkyrimFile, $01C38A, 'markarth');
    AddMapMarker(SkyrimFile, $0177B0, 'morthal');
    AddMapMarker(SkyrimFile, $01C390, 'riften');
    AddMapMarker(SkyrimFile, $04D0F4, 'solitude');
    AddMapMarker(SkyrimFile, $0162CE, 'whiterun');
    AddMapMarker(SkyrimFile, $038436, 'windhelm');
    AddMapMarker(SkyrimFile, $0177EF, 'winterhold');
    AddMapMarker(SkyrimFile, $017732, 'darkwater_crossing');
    AddMapMarker(SkyrimFile, $017753, 'dragon_bridge');
    AddMapMarker(SkyrimFile, $016370, 'halfmoon_mill');
    AddMapMarker(SkyrimFile, $01634F, 'heartwood_mill');
    AddMapMarker(SkyrimFile, $017791, 'ivarstead');
    AddMapMarker(SkyrimFile, $01779A, 'karthwasten');
    AddMapMarker(SkyrimFile, $0177A1, 'kynesgrove');
    AddMapMarker(SkyrimFile, $01636D, 'mixwater_mill');
    AddMapMarker(SkyrimFile, $017785, 'nightgate_inn');
    AddMapMarker(SkyrimFile, $0177C3, 'old_hroldan');
    AddMapMarker(SkyrimFile, $0162A4, 'riverwood');
    AddMapMarker(SkyrimFile, $0177CC, 'rorikstead');
    AddMapMarker(SkyrimFile, $0177D7, 'shors_stone');
    AddMapMarker(SkyrimFile, $0162BB, 'soljunds_sinkhole');
    AddMapMarker(SkyrimFile, $0177E4, 'stonehills');
    AddMapMarker(HearthFiresFile, $010DE8, 'heljarchen_hall');
    AddMapMarker(HearthFiresFile, $0030AA, 'lakeview_manor');
    AddMapMarker(HearthFiresFile, $00B8B0, 'winstad_manor');

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
