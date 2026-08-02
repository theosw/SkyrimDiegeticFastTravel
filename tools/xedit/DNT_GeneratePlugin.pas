{
  Generate DiegeticTravel.esp from build/dialogue_manifest.json.

  The PowerShell launcher writes build/xedit_generator_config.json with the
  absolute manifest and output paths. xEdit's Pascal host does not expose
  process environment variables.

  Run with Skyrim.esm and CFTO.esp loaded. The script deliberately reuses CFTO's
  paid carriage topics and travel handoff. It folds CFTO's free-carriage path
  into the hazard-aware branch while leaving ferry dialogue untouched.
}
unit DNT_GeneratePlugin;

var
  GeneratorConfig, Manifest, DialogueRuntime: TJsonObject;
  OutputFile, RouteQuest, CoordinatorQuest, TemplateInfo, LegacyFreeGlobal: IInterface;
  AvailableGlobals, CostGlobals, HoursGlobals, OriginServices: TStringList;
  GeneratorConfigPath, ManifestPath, DialogueRuntimePath, PluginOutputPath,
    SeqFormIDsPath, GeneratorStatusPath, GeneratorErrorPath,
    OutputPluginName: string;

procedure WriteGeneratorStatus(const Status: string);
var
  StatusLines: TStringList;
begin
  StatusLines := TStringList.Create;
  try
    StatusLines.Add(Status);
    StatusLines.SaveToFile(GeneratorStatusPath);
  finally
    StatusLines.Free;
  end;
end;

procedure WriteGeneratorError(const ErrorText: string);
var
  ErrorLines: TStringList;
begin
  ErrorLines := TStringList.Create;
  try
    ErrorLines.Add(ErrorText);
    ErrorLines.SaveToFile(GeneratorErrorPath);
  finally
    ErrorLines.Free;
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

function ResolveFormRef(const RefText: string): IInterface;
var
  Value, PluginName, FormText: string;
  Separator: Integer;
  SourceFile: IInterface;
  LocalFormID, LoadOrderFormID: Cardinal;
begin
  Result := nil;
  Value := RefText;
  if Pos('__formData|', Value) = 1 then
    Delete(Value, 1, Length('__formData|'));

  Separator := Pos('|', Value);
  if Separator = 0 then
    Exit;
  PluginName := Copy(Value, 1, Separator - 1);
  FormText := Copy(Value, Separator + 1, Length(Value));
  if LowerCase(Copy(FormText, 1, 2)) = '0x' then
    Delete(FormText, 1, 2);

  SourceFile := FileByPluginName(PluginName);
  if not Assigned(SourceFile) then
    raise Exception.Create('Required plugin is not loaded: ' + PluginName);

  LocalFormID := StrToInt('$' + FormText);
  // Manifest references use a plugin-local ObjectID. xEdit's conversion API
  // expects a file FormID, whose high byte identifies the defining file within
  // that file's own master table. For a record defined by SourceFile, that
  // index is exactly MasterCount(SourceFile).
  LocalFormID := (MasterCount(SourceFile) shl 24) or
    (LocalFormID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(
    SourceFile,
    LocalFormID
  );
  Result := RecordByFormID(SourceFile, LoadOrderFormID, True);
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve form: ' + RefText);
end;

function JsonFormRef(FormRecord: IInterface): string;
begin
  Result := '__formData|' + OutputPluginName + '|0x' +
    IntToHex(GetLoadOrderFormID(FormRecord) and $00FFFFFF, 6);
end;

function EditorToken(const Value: string): string;
var
  i: Integer;
  UpperNext: Boolean;
  Character: string;
begin
  Result := '';
  UpperNext := True;
  for i := 1 to Length(Value) do begin
    Character := Copy(Value, i, 1);
    if Character = '_' then
      UpperNext := True
    else begin
      if UpperNext then
        Character := UpperCase(Character);
      Result := Result + Character;
      UpperNext := False;
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

function ListRecord(List: TStringList; const Key: string): IInterface;
var
  Index: Integer;
begin
  Index := List.IndexOf(Key);
  if Index < 0 then
    raise Exception.Create('Generated record is missing for key: ' + Key);
  Result := ObjectToElement(List.Objects[Index]);
end;

function AddScript(RecordElement: IInterface; const ScriptName: string): IInterface;
var
  Scripts: IInterface;
begin
  Scripts := ElementByPath(Add(RecordElement, 'VMAD', False), 'Scripts');
  Result := ElementAssign(Scripts, HighInteger, nil, False);
  SetElementEditValues(Result, 'ScriptName', ScriptName);
end;

function AddProperty(
  ScriptElement: IInterface;
  const PropertyName, PropertyType: string;
  PropertyValue: Variant
): IInterface;
var
  Properties: IInterface;
begin
  Properties := ElementByPath(ScriptElement, 'Properties');
  Result := ElementAssign(Properties, HighInteger, nil, False);
  SetElementEditValues(Result, 'propertyName', PropertyName);
  SetElementEditValues(Result, 'Type', PropertyType);
  if LowerCase(PropertyType) = 'object' then
    SetElementEditValues(
      Result,
      'Value\Object Union\Object v2\FormID',
      PropertyValue
    )
  else
    SetElementNativeValues(Result, PropertyType, PropertyValue);
end;

function NewGlobal(const EditorID: string): IInterface;
begin
  Result := Add(EnsureTopGroup('GLOB'), 'GLOB', True);
  SetElementEditValues(Result, 'EDID', EditorID);
  if GetElementEditValues(Result, 'EDID') <> EditorID then
    raise Exception.Create('Could not set global EditorID: ' + EditorID);
  SetElementEditValues(Result, 'FNAM', 'Float');
  SetElementEditValues(Result, 'FLTV', '0');
end;

function NewQuest(const EditorID, ScriptName: string): IInterface;
begin
  Result := Add(EnsureTopGroup('QUST'), 'QUST', True);
  SetElementEditValues(Result, 'EDID', EditorID);
  if GetElementEditValues(Result, 'EDID') <> EditorID then
    raise Exception.Create('Could not set quest EditorID: ' + EditorID);
  Add(Result, 'DNAM', True);
  SetElementNativeValues(Result, 'DNAM\Flags', 1);
  SetElementNativeValues(Result, 'DNAM\Priority', 50);
  AddScript(Result, ScriptName);
end;

function QuestScript(QuestRecord: IInterface): IInterface;
begin
  Result := ElementByIndex(ElementByPath(QuestRecord, 'VMAD\Scripts'), 0);
end;

procedure AddPlayerListenerAlias(QuestRecord: IInterface);
var
  TemplateQuest, PlayerRef, SourceAlias, SourceVMADAlias: IInterface;
  Aliases, AliasEntry, VMAD, VMADAliases, AliasVMAD: IInterface;
  Scripts, ScriptEntry, Properties: IInterface;
begin
  TemplateQuest := ResolveFormRef('__formData|Skyrim.esm|0x0E3308');
  PlayerRef := ResolveFormRef('__formData|Skyrim.esm|0x000014');
  SourceAlias := ElementByIndex(
    ElementByPath(TemplateQuest, 'Aliases'),
    1
  );
  SourceVMADAlias := ElementByIndex(
    ElementByPath(TemplateQuest, 'VMAD\Aliases'),
    1
  );
  if not Assigned(SourceAlias) or not Assigned(SourceVMADAlias) then
    raise Exception.Create('Player alias template is incomplete');

  Aliases := ElementByPath(QuestRecord, 'Aliases');
  if not Assigned(Aliases) then
    Aliases := Add(QuestRecord, 'Aliases', True);
  while ElementCount(Aliases) > 0 do
    RemoveElement(Aliases, Pred(ElementCount(Aliases)));
  AliasEntry := ElementAssign(
    Aliases,
    HighInteger,
    SourceAlias,
    False
  );
  SetElementNativeValues(AliasEntry, 'ALST', 0);
  SetElementEditValues(AliasEntry, 'ALID', 'DNT_Player');
  // ElementAssign copied the complete Specific Reference union from the
  // known player-alias template. Reassigning ALFR through the union container
  // is rejected by xEdit 4.1.5f as an edit to the non-editable struct itself.
  Add(QuestRecord, 'ANAM', True);
  SetElementNativeValues(QuestRecord, 'ANAM', 1);

  VMAD := ElementByPath(QuestRecord, 'VMAD');
  VMADAliases := ElementByPath(VMAD, 'Aliases');
  if not Assigned(VMADAliases) then
    VMADAliases := Add(VMAD, 'Aliases', True);
  while ElementCount(VMADAliases) > 0 do
    RemoveElement(VMADAliases, Pred(ElementCount(VMADAliases)));
  AliasVMAD := ElementAssign(
    VMADAliases,
    HighInteger,
    SourceVMADAlias,
    False
  );

  SetElementEditValues(
    AliasVMAD,
    'Object Union\Object v2\FormID',
    Name(QuestRecord)
  );
  SetElementNativeValues(
    AliasVMAD,
    'Object Union\Object v2\Alias',
    0
  );

  // xEdit names the nested quest-alias VMAD collection "Alias Scripts";
  // Mutagen exposes the same field as QuestFragmentAlias.Scripts.
  Scripts := ElementByPath(AliasVMAD, 'Alias Scripts');
  if not Assigned(Scripts) then
    Scripts := Add(AliasVMAD, 'Alias Scripts', True);
  if not Assigned(Scripts) then
    raise Exception.Create('Could not create player listener script array');
  while ElementCount(Scripts) > 1 do
    RemoveElement(Scripts, Pred(ElementCount(Scripts)));
  if ElementCount(Scripts) = 0 then
    ScriptEntry := ElementAssign(Scripts, HighInteger, nil, False)
  else
    ScriptEntry := ElementByIndex(Scripts, 0);
  if not Assigned(ScriptEntry) then
    raise Exception.Create('Could not create player listener script entry');
  SetElementEditValues(
    ScriptEntry,
    'ScriptName',
    'DNT_DialogueMenuListener'
  );
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    Properties := Add(ScriptEntry, 'Properties', True);
  if not Assigned(Properties) then
    raise Exception.Create('Could not create player listener properties');
  while ElementCount(Properties) > 0 do
    RemoveElement(Properties, 0);
  AddProperty(
    ScriptEntry,
    'Coordinator',
    'Object',
    Name(QuestRecord)
  );

  if GetElementEditValues(AliasEntry, 'ALID') <> 'DNT_Player' then
    raise Exception.Create('Could not create DNT player alias');
  if GetElementEditValues(
    AliasVMAD,
    'Object Union\Object v2\FormID'
  ) <> Name(QuestRecord) then
    raise Exception.Create('Player listener alias points to the wrong quest');
  if GetElementNativeValues(
    AliasVMAD,
    'Object Union\Object v2\Alias'
  ) <> 0 then
    raise Exception.Create('Player listener alias points to the wrong alias ID');
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_DialogueMenuListener' then
    raise Exception.Create('Could not bind DNT dialogue menu listener');
end;

function ReplaceInfoFragment(
  InfoRecord: IInterface;
  const ScriptName: string
): IInterface;
var
  VMAD, Scripts, Properties, Fragments, Fragment: IInterface;
begin
  VMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(VMAD) then begin
    // A VMAD subrecord cannot be copied directly into an INFO record with
    // ElementAssign. Create the destination subrecord first, then assign the
    // template VMAD into that container.
    Add(InfoRecord, 'VMAD', True);
    VMAD := ElementByPath(InfoRecord, 'VMAD');
    if not Assigned(VMAD) then
      raise Exception.Create(
        'Could not create INFO VMAD for ' + ScriptName
      );
    ElementAssign(
      VMAD,
      LowInteger,
      ElementByPath(TemplateInfo, 'VMAD'),
      False
    );
    VMAD := ElementByPath(InfoRecord, 'VMAD');
  end;
  if not Assigned(VMAD) then
    raise Exception.Create('INFO VMAD is missing for ' + ScriptName);

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) then
    raise Exception.Create('INFO VMAD scripts are missing for ' + ScriptName);
  while ElementCount(Scripts) > 1 do
    RemoveElement(Scripts, Pred(ElementCount(Scripts)));
  if ElementCount(Scripts) = 0 then
    raise Exception.Create('INFO VMAD has no script entry for ' + ScriptName);
  Result := ElementByIndex(Scripts, 0);
  SetElementEditValues(Result, 'ScriptName', ScriptName);

  Properties := ElementByPath(Result, 'Properties');
  while ElementCount(Properties) > 0 do
    RemoveElement(Properties, 0);

  SetElementEditValues(VMAD, 'Script Fragments\FileName', ScriptName);
  // INFO fragment flag bit 0 is OnBegin. Set it explicitly instead of
  // inheriting timing from whichever destination INFO supplied the VMAD.
  SetElementNativeValues(VMAD, 'Script Fragments\Flags', 1);
  Fragments := ElementByPath(VMAD, 'Script Fragments\Fragments');
  if not Assigned(Fragments) then
    raise Exception.Create(
      'INFO VMAD fragment array is missing for ' + ScriptName
    );
  while ElementCount(Fragments) > 1 do
    RemoveElement(Fragments, Pred(ElementCount(Fragments)));
  if ElementCount(Fragments) = 0 then
    raise Exception.Create('INFO VMAD has no fragment for ' + ScriptName);
  Fragment := ElementByIndex(Fragments, 0);
  SetElementEditValues(Fragment, 'ScriptName', ScriptName);
  SetElementEditValues(Fragment, 'FragmentName', 'Fragment_0');
  if GetElementNativeValues(VMAD, 'Script Fragments\Flags') <> 1 then
    raise Exception.Create(
      'INFO VMAD is not configured for OnBegin: ' + ScriptName
    );
end;

procedure ConfigureAvailabilityCondition(
  ConditionData, AvailableGlobal: IInterface
);
begin
  SetElementEditValues(ConditionData, 'Type', '10000000');
  SetElementEditValues(ConditionData, 'Comparison Value - Float', '1.0');
  SetElementEditValues(ConditionData, 'Function', 'GetGlobalValue');
  SetElementEditValues(ConditionData, 'Global', Name(AvailableGlobal));
  SetElementEditValues(ConditionData, 'Run On', 'Subject');
  SetElementEditValues(ConditionData, 'Parameter #3', '-1');
end;

procedure ConfigureGoldCondition(
  ConditionData, CostGlobal, Gold001, PlayerRef: IInterface;
  HasEnoughGold: Boolean
);
begin
  if HasEnoughGold then
    SetElementEditValues(ConditionData, 'Type', '11000100')
  else
    SetElementEditValues(ConditionData, 'Type', '00100100');
  SetElementEditValues(
    ConditionData,
    'Comparison Value - Global',
    Name(CostGlobal)
  );
  SetElementEditValues(ConditionData, 'Function', 'GetItemCount');
  SetElementEditValues(ConditionData, 'Inventory Object', Name(Gold001));
  SetElementEditValues(ConditionData, 'Run On', 'Reference');
  SetElementEditValues(ConditionData, 'Reference', Name(PlayerRef));
  SetElementEditValues(ConditionData, 'Parameter #3', '-1');
end;

procedure ReplaceDestinationConditions(
  InfoRecord, AvailableGlobal, CostGlobal, Gold001, PlayerRef: IInterface;
  HasEnoughGold: Boolean
);
var
  Conditions, Condition, ConditionData: IInterface;
begin
  RemoveElement(InfoRecord, 'Conditions');
  Conditions := Add(InfoRecord, 'Conditions', True);
  Condition := ElementByIndex(Conditions, 0);
  ConditionData := ElementByPath(Condition, 'CTDA');
  ConfigureAvailabilityCondition(ConditionData, AvailableGlobal);

  Condition := ElementAssign(Conditions, HighInteger, nil, False);
  ConditionData := ElementByPath(Condition, 'CTDA');
  ConfigureGoldCondition(
    ConditionData,
    CostGlobal,
    Gold001,
    PlayerRef,
    HasEnoughGold
  );
end;

procedure CreateGlobals;
var
  GlobalsObject, GlobalSet: TJsonObject;
  RuntimeGlobal: TJsonObject;
  Destination, EditorID: string;
  AvailableRecord, CostRecord, HoursRecord: IInterface;
  i: Integer;
begin
  GlobalsObject := Manifest.O['globals'];
  LegacyFreeGlobal := NewGlobal('DNT_LegacyFreeBranchEnabled');
  for i := 0 to Pred(GlobalsObject.Count) do begin
    Destination := GlobalsObject.Names[i];
    GlobalSet := GlobalsObject.O[Destination];

    EditorID := GlobalSet.S['available'];
    AvailableRecord := NewGlobal(EditorID);
    AvailableGlobals.AddObject(Destination, AvailableRecord);

    EditorID := GlobalSet.S['cost'];
    CostRecord := NewGlobal(EditorID);
    CostGlobals.AddObject(Destination, CostRecord);

    EditorID := GlobalSet.S['hours'];
    HoursRecord := NewGlobal(EditorID);
    HoursGlobals.AddObject(Destination, HoursRecord);

    RuntimeGlobal := DialogueRuntime.A['destination_globals'].AddObject;
    RuntimeGlobal.S['available'] := JsonFormRef(AvailableRecord);
    RuntimeGlobal.S['cost'] := JsonFormRef(CostRecord);
    RuntimeGlobal.S['hours'] := JsonFormRef(HoursRecord);
  end;
end;

procedure CreateQuests;
var
  ScriptElement, OriginQuest: IInterface;
  OriginsObject, OriginObject: TJsonObject;
  Origin: string;
  i: Integer;
begin
  RouteQuest := NewQuest('DNT_RouteServiceQuest', 'DNT_RouteService');
  ScriptElement := QuestScript(RouteQuest);
  AddProperty(
    ScriptElement,
    'CW01A',
    'Object',
    Name(ResolveFormRef('__formData|Skyrim.esm|0x0D517A'))
  );
  AddProperty(
    ScriptElement,
    'CW01B',
    'Object',
    Name(ResolveFormRef('__formData|Skyrim.esm|0x0E2D29'))
  );
  AddProperty(
    ScriptElement,
    'CWResolution01',
    'Object',
    Name(ResolveFormRef('__formData|Skyrim.esm|0x02B272'))
  );

  CoordinatorQuest := NewQuest(
    'DNT_TravelCoordinatorQuest',
    'DNT_TravelCoordinator'
  );
  AddPlayerListenerAlias(CoordinatorQuest);

  OriginsObject := Manifest.O['origins'];
  for i := 0 to Pred(OriginsObject.Count) do begin
    Origin := OriginsObject.Names[i];
    OriginObject := OriginsObject.O[Origin];
    OriginQuest := NewQuest(
      'DNT_Origin_' + EditorToken(Origin),
      'DNT_OriginService'
    );
    OriginServices.AddObject(Origin, OriginQuest);
    ScriptElement := QuestScript(OriginQuest);
    AddProperty(ScriptElement, 'RouteService', 'Object', Name(RouteQuest));
    AddProperty(
      ScriptElement,
      'KmodFastTravelQuest',
      'Object',
      Name(ResolveFormRef(Manifest.O['cfto'].S['quest']))
    );
    AddProperty(
      ScriptElement,
      'KmodCarriageDestination',
      'Object',
      Name(ResolveFormRef(Manifest.O['cfto'].S['destination_global']))
    );
    AddProperty(
      ScriptElement,
      'KmodCarriageFreeFaction',
      'Object',
      Name(ResolveFormRef(Manifest.O['cfto'].S['free_faction']))
    );
    AddProperty(
      ScriptElement,
      'PlayerRef',
      'Object',
      Name(ResolveFormRef('__formData|Skyrim.esm|0x000014'))
    );
    AddProperty(
      ScriptElement,
      'Gold001',
      'Object',
      Name(ResolveFormRef('__formData|Skyrim.esm|0x00000F'))
    );
    AddProperty(ScriptElement, 'OriginId', 'String', Origin);
  end;
end;

procedure BuildDialogueRuntime;
var
  OriginsObject, OriginObject, RuntimeOrigin: TJsonObject;
  Entry, RuntimeEntry, ServiceEntry: TJsonObject;
  Entries: TJsonArray;
  Origin, Destination: string;
  OriginQuest: IInterface;
  i, j: Integer;
begin
  OriginsObject := Manifest.O['origins'];
  for i := 0 to Pred(OriginsObject.Count) do begin
    Origin := OriginsObject.Names[i];
    OriginObject := OriginsObject.O[Origin];
    OriginQuest := ListRecord(OriginServices, Origin);

    ServiceEntry := DialogueRuntime.A['origin_services'].AddObject;
    ServiceEntry.S['driver'] := OriginObject.S['driver'];
    ServiceEntry.S['service'] := JsonFormRef(OriginQuest);

    RuntimeOrigin := DialogueRuntime.O['origins'].O[Origin];
    Entries := OriginObject.A['entries'];
    for j := 0 to Pred(Entries.Count) do begin
      Entry := Entries.O[j];
      Destination := Entry.S['destination'];
      RuntimeEntry := RuntimeOrigin.A['entries'].AddObject;
      RuntimeEntry.S['destination'] := Destination;
      RuntimeEntry.S['route'] := Entry.S['route'];
      RuntimeEntry.I['cfto_destination'] := Entry.I['cfto_destination'];
      RuntimeEntry.S['available_global'] :=
        JsonFormRef(ListRecord(AvailableGlobals, Destination));
      RuntimeEntry.S['cost_global'] :=
        JsonFormRef(ListRecord(CostGlobals, Destination));
      RuntimeEntry.S['hours_global'] :=
        JsonFormRef(ListRecord(HoursGlobals, Destination));
    end;
  end;
end;

procedure AddTextDisplayGlobal(QuestOverride, GlobalRecord: IInterface);
var
  Globals, Entry: IInterface;
begin
  Globals := ElementByPath(QuestOverride, 'Text Display Globals');
  if not Assigned(Globals) then begin
    Globals := Add(QuestOverride, 'Text Display Globals', True);
    Entry := ElementByIndex(Globals, 0);
  end
  else
    Entry := ElementAssign(Globals, HighInteger, nil, False);
  SetEditValue(Entry, Name(GlobalRecord));
end;

procedure PatchCFTOQuest;
var
  QuestOverride: IInterface;
  i: Integer;
begin
  QuestOverride := wbCopyElementToFile(
    ResolveFormRef(Manifest.O['cfto'].S['quest']),
    OutputFile,
    False,
    True
  );
  for i := 0 to Pred(CostGlobals.Count) do begin
    AddTextDisplayGlobal(
      QuestOverride,
      ObjectToElement(CostGlobals.Objects[i])
    );
    AddTextDisplayGlobal(
      QuestOverride,
      ObjectToElement(HoursGlobals.Objects[i])
    );
  end;
end;

procedure ReplaceRootLinks(RootInfo: IInterface);
var
  DialogueDestinations, DestinationData: TJsonObject;
  Links, LinkElement, TopicRecord: IInterface;
  Destination: string;
  i: Integer;
begin
  RemoveElement(RootInfo, 'Link To');
  DialogueDestinations := Manifest.O['dialogue'].O['destinations'];
  Links := Add(RootInfo, 'Link To', True);
  for i := 0 to Pred(DialogueDestinations.Count) do begin
    Destination := DialogueDestinations.Names[i];
    DestinationData := DialogueDestinations.O[Destination];
    TopicRecord := ResolveFormRef(DestinationData.S['topic']);
    if i = 0 then
      LinkElement := ElementByIndex(Links, 0)
    else
      LinkElement := ElementAssign(Links, HighInteger, nil, False);
    SetEditValue(LinkElement, Name(TopicRecord));
  end;
end;

procedure RemoveFreeFactionCondition(RootInfo: IInterface);
var
  Conditions, Condition: IInterface;
  i: Integer;
begin
  Conditions := ElementByPath(RootInfo, 'Conditions');
  for i := Pred(ElementCount(Conditions)) downto 0 do begin
    Condition := ElementByIndex(Conditions, i);
    if GetElementEditValues(Condition, 'CTDA\Function') = 'GetInFaction' then
      RemoveElement(Conditions, i);
  end;
end;

procedure DisableLegacyFreeRoot;
var
  FreeRoot, Conditions, Condition, ConditionData: IInterface;
begin
  FreeRoot := wbCopyElementToFile(
    ResolveFormRef(Manifest.O['dialogue'].S['free_root_info']),
    OutputFile,
    False,
    True
  );
  RemoveElement(FreeRoot, 'Conditions');
  Conditions := Add(FreeRoot, 'Conditions', True);
  Condition := ElementByIndex(Conditions, 0);
  ConditionData := ElementByPath(Condition, 'CTDA');
  ConfigureAvailabilityCondition(ConditionData, LegacyFreeGlobal);
end;

procedure PatchDialogue;
var
  DialogueDestinations, DestinationData: TJsonObject;
  RootInfo, TopicRecord, SuccessInfo, FailureInfo: IInterface;
  SuccessScript, RootScript: IInterface;
  AvailableRecord, CostRecord, Gold001, PlayerRef: IInterface;
  Destination, DestinationName: string;
  i: Integer;
begin
  DialogueDestinations := Manifest.O['dialogue'].O['destinations'];
  TemplateInfo := ResolveFormRef(
    DialogueDestinations.O['riften'].S['success_info']
  );
  Gold001 := ResolveFormRef('__formData|Skyrim.esm|0x00000F');
  PlayerRef := ResolveFormRef('__formData|Skyrim.esm|0x000014');

  RootInfo := wbCopyElementToFile(
    ResolveFormRef(Manifest.O['dialogue'].S['root_info']),
    OutputFile,
    False,
    True
  );
  RootScript := ReplaceInfoFragment(RootInfo, 'DNT_PrepareOrigin');
  AddProperty(
    RootScript,
    'Coordinator',
    'Object',
    Name(CoordinatorQuest)
  );
  RemoveFreeFactionCondition(RootInfo);
  ReplaceRootLinks(RootInfo);
  DisableLegacyFreeRoot;

  for i := 0 to Pred(DialogueDestinations.Count) do begin
    Destination := DialogueDestinations.Names[i];
    DestinationData := DialogueDestinations.O[Destination];
    DestinationName := DestinationData.S['name'];
    AvailableRecord := ListRecord(AvailableGlobals, Destination);
    CostRecord := ListRecord(CostGlobals, Destination);

    TopicRecord := wbCopyElementToFile(
      ResolveFormRef(DestinationData.S['topic']),
      OutputFile,
      False,
      True
    );
    SetElementEditValues(
      TopicRecord,
      'FULL',
      DestinationName + '. (<Global=' +
        GetElementEditValues(CostRecord, 'EDID') +
        '> gold, <Global=' +
        GetElementEditValues(ListRecord(HoursGlobals, Destination), 'EDID') +
        '> hours)'
    );

    SuccessInfo := wbCopyElementToFile(
      ResolveFormRef(DestinationData.S['success_info']),
      OutputFile,
      False,
      True
    );
    SuccessScript := ReplaceInfoFragment(
      SuccessInfo,
      'DNT_SelectDestination'
    );
    AddProperty(
      SuccessScript,
      'Coordinator',
      'Object',
      Name(CoordinatorQuest)
    );
    AddProperty(
      SuccessScript,
      'DestinationId',
      'String',
      Destination
    );
    ReplaceDestinationConditions(
      SuccessInfo,
      AvailableRecord,
      CostRecord,
      Gold001,
      PlayerRef,
      True
    );

    FailureInfo := wbCopyElementToFile(
      ResolveFormRef(DestinationData.S['failure_info']),
      OutputFile,
      False,
      True
    );
    ReplaceDestinationConditions(
      FailureInfo,
      AvailableRecord,
      CostRecord,
      Gold001,
      PlayerRef,
      False
    );
  end;
end;

procedure LoadGeneratorConfig;
begin
  GeneratorConfigPath :=
    ScriptsPath + '..\..\build\xedit_generator_config.json';
  if not FileExists(GeneratorConfigPath) then
    raise Exception.Create(
      'Generator config does not exist: ' + GeneratorConfigPath
    );
  GeneratorConfig.LoadFromFile(GeneratorConfigPath);
  ManifestPath := GeneratorConfig.S['manifest'];
  DialogueRuntimePath := GeneratorConfig.S['dialogue_runtime'];
  PluginOutputPath := GeneratorConfig.S['plugin_output'];
  SeqFormIDsPath := GeneratorConfig.S['seq_formids'];
end;

procedure ValidateInputs;
begin
  if ManifestPath = '' then
    raise Exception.Create('Generator config manifest path is empty');
  if DialogueRuntimePath = '' then
    raise Exception.Create('Generator config dialogue output path is empty');
  if PluginOutputPath = '' then
    raise Exception.Create('Generator config plugin output path is empty');
  if SeqFormIDsPath = '' then
    raise Exception.Create('Generator config sequence FormID path is empty');
  if not FileExists(ManifestPath) then
    raise Exception.Create('Manifest does not exist: ' + ManifestPath);
  if not Assigned(FileByPluginName('Skyrim.esm')) then
    raise Exception.Create('Skyrim.esm must be loaded');
  if not Assigned(FileByPluginName('CFTO.esp')) then
    raise Exception.Create('CFTO.esp must be loaded');
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

procedure SaveGeneratedSeqFormIDs;
var
  QuestGroup, QuestRecord, QuestFlags, MasterQuest: IInterface;
  SeqFormIDs: TStringList;
  i: Integer;
begin
  QuestGroup := GroupBySignature(OutputFile, 'QUST');
  if not Assigned(QuestGroup) then
    raise Exception.Create('Generated plugin has no quest group for SEQ');

  SeqFormIDs := TStringList.Create;
  try
    for i := 0 to Pred(ElementCount(QuestGroup)) do begin
      QuestRecord := ElementByIndex(QuestGroup, i);
      QuestFlags := ElementByPath(QuestRecord, 'DNAM\Flags');
      if Assigned(QuestFlags) and
        ((GetNativeValue(QuestFlags) and 1) <> 0) then begin
        // Match xEdit's built-in Create SEQ rule: include newly defined SGE
        // quests and overrides that newly turn SGE on, but not an override
        // whose master quest was already start-game enabled.
        MasterQuest := Master(QuestRecord);
        if not Assigned(MasterQuest) or
          ((GetElementNativeValues(MasterQuest, 'DNAM\Flags') and 1) = 0) then
          SeqFormIDs.Add(IntToHex(FixedFormID(QuestRecord), 8));
      end;
    end;
    if SeqFormIDs.Count = 0 then
      raise Exception.Create(
        'Generated plugin has no start-game quests for SEQ'
      );
    SeqFormIDs.SaveToFile(SeqFormIDsPath);
  finally
    SeqFormIDs.Free;
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  SetJDOLineBreak(#13#10);
  GeneratorStatusPath :=
    ScriptsPath + '..\..\build\xedit_generator.status';
  GeneratorErrorPath :=
    ScriptsPath + '..\..\build\xedit_generator.error';
  WriteGeneratorStatus('running');

  AvailableGlobals := TStringList.Create;
  CostGlobals := TStringList.Create;
  HoursGlobals := TStringList.Create;
  OriginServices := TStringList.Create;
  GeneratorConfig := TJsonObject.Create;
  Manifest := TJsonObject.Create;
  DialogueRuntime := TJsonObject.Create;

  try
    LoadGeneratorConfig;
    ValidateInputs;
    Manifest.LoadFromFile(ManifestPath);
    OutputPluginName := Manifest.S['plugin'];

    OutputFile := AddNewFileName(OutputPluginName);
    if not Assigned(OutputFile) then
      raise Exception.Create(
        'Could not create output plugin: ' + OutputPluginName
      );
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'CFTO.esp');

    CreateGlobals;
    CreateQuests;
    BuildDialogueRuntime;
    PatchCFTOQuest;
    PatchDialogue;
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormIDs;

    DialogueRuntime.SaveToFile(
      DialogueRuntimePath,
      False,
      TEncoding.UTF8,
      True
    );
    AddMessage(
      Format(
        '[DNT] Generated %s: %d destinations, %d origins',
        [OutputPluginName, AvailableGlobals.Count, OriginServices.Count]
      )
    );
    WriteGeneratorStatus('success');
  except
    on E: Exception do begin
      WriteGeneratorError(E.Message);
      WriteGeneratorStatus('failed');
      raise;
    end;
  end;
end;

function Finalize: Integer;
begin
  GeneratorConfig.Free;
  Manifest.Free;
  DialogueRuntime.Free;
  AvailableGlobals.Free;
  CostGlobals.Free;
  HoursGlobals.Free;
  OriginServices.Free;
  Result := 0;
end;

end.
