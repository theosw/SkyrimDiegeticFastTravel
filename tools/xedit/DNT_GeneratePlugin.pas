{
  Generate the core carriage service quests for DiegeticTravel.esp.

  The native travel catalog owns destination availability, fare, duration,
  marker presentation, and selection. This generator only binds CFTO's nine
  carriage drivers to lightweight Papyrus services.
}
unit DNT_GeneratePlugin;

var
  GeneratorConfig, Manifest: TJsonObject;
  OutputFile, CoordinatorQuest: IInterface;
  GeneratorConfigPath, ManifestPath, PluginOutputPath, SeqFormIDsPath,
    GeneratorStatusPath, GeneratorErrorPath, OutputPluginName: string;

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
  LocalFormID := (MasterCount(SourceFile) shl 24) or
    (LocalFormID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(SourceFile, LocalFormID);
  Result := RecordByFormID(SourceFile, LoadOrderFormID, True);
  if not Assigned(Result) then
    raise Exception.Create('Could not resolve form: ' + RefText);
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

procedure ReserveNextObjectID(StartObjectID: Cardinal);
var
  FileHeader: IInterface;
  CurrentObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(OutputFile, 0);
  if not Assigned(FileHeader) then
    raise Exception.Create('Output plugin has no file header');
  CurrentObjectID := GetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID'
  );
  if CurrentObjectID > StartObjectID then
    raise Exception.Create(
      'Core FormID range starts at ' + IntToHex(StartObjectID, 6) +
      ', but the seed already reached ' + IntToHex(CurrentObjectID, 6)
    );
  SetElementNativeValues(FileHeader, 'HEDR\Next Object ID', StartObjectID);
  if GetElementNativeValues(FileHeader, 'HEDR\Next Object ID') <>
    StartObjectID then
    raise Exception.Create('Could not reserve the core FormID range');
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

procedure CreateQuests;
var
  CoordinatorScript, OriginScript, OriginQuest: IInterface;
  OriginsObject, OriginObject: TJsonObject;
  Origin, Token: string;
  i: Integer;
begin
  CoordinatorQuest := NewQuest(
    'DNT_TravelCoordinatorQuest',
    'DNT_TravelCoordinator'
  );
  CoordinatorScript := QuestScript(CoordinatorQuest);

  OriginsObject := Manifest.O['origins'];
  for i := 0 to Pred(OriginsObject.Count) do begin
    Origin := OriginsObject.Names[i];
    Token := EditorToken(Origin);
    OriginObject := OriginsObject.O[Origin];
    OriginQuest := NewQuest(
      'DNT_Origin_' + Token,
      'DNT_OriginService'
    );
    OriginScript := QuestScript(OriginQuest);
    AddProperty(
      OriginScript,
      'KmodCarriageDestination',
      'Object',
      Name(ResolveFormRef(Manifest.O['cfto'].S['destination_global']))
    );
    AddProperty(
      OriginScript,
      'KmodCarriageFreeFaction',
      'Object',
      Name(ResolveFormRef(Manifest.O['cfto'].S['free_faction']))
    );
    AddProperty(
      OriginScript,
      'PlayerRef',
      'Object',
      Name(ResolveFormRef('__formData|Skyrim.esm|0x000014'))
    );
    AddProperty(
      OriginScript,
      'Gold001',
      'Object',
      Name(ResolveFormRef('__formData|Skyrim.esm|0x00000F'))
    );
    AddProperty(OriginScript, 'OriginId', 'String', Origin);

    AddProperty(
      CoordinatorScript,
      Token + 'Driver',
      'Object',
      Name(ResolveFormRef(OriginObject.S['driver']))
    );
    AddProperty(
      CoordinatorScript,
      Token + 'Service',
      'Object',
      Name(OriginQuest)
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
  PluginOutputPath := GeneratorConfig.S['plugin_output'];
  SeqFormIDsPath := GeneratorConfig.S['seq_formids'];
end;

procedure ValidateInputs;
begin
  if ManifestPath = '' then
    raise Exception.Create('Generator config manifest path is empty');
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

  GeneratorConfig := TJsonObject.Create;
  Manifest := TJsonObject.Create;

  try
    LoadGeneratorConfig;
    ValidateInputs;
    Manifest.LoadFromFile(ManifestPath);
    OutputPluginName := Manifest.S['plugin'];

    if GeneratorConfig.B['append_existing'] then begin
      OutputFile := FileByPluginName(OutputPluginName);
      if not Assigned(OutputFile) then
        raise Exception.Create(
          'Could not find release seed plugin: ' + OutputPluginName
        );
      ReserveNextObjectID($000900);
    end else begin
      OutputFile := AddNewFileName(OutputPluginName);
      if not Assigned(OutputFile) then
        raise Exception.Create(
          'Could not create output plugin: ' + OutputPluginName
        );
    end;
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'CFTO.esp');

    CreateQuests;
    SaveGeneratedPlugin;
    SaveGeneratedSeqFormIDs;

    AddMessage(
      Format(
        '[DNT] Generated %s: %d carriage origins',
        [OutputPluginName, Manifest.O['origins'].Count]
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
  Result := 0;
end;

end.
