unit DNT_GenerateBcdLoreRimCompat;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravelLoreRimBcdCompat.esp';
  GateEditorID = 'DNT_ShowBcdTravelDialogue';
  EqualConditionType = $00;

var
  OutputFile, CftoFile, BcdBaseFile, BcdCftoFile, WciiFile, BcdWciiFile: IInterface;
  StatusPath, ErrorPath, PluginOutputPath: string;
  GatedInfoCount: Integer;

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
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(PluginFile, FileFormID);
  Result := RecordByFormID(PluginFile, LoadOrderFormID, True);
end;

function RequireRecord(
  PluginFile: IInterface;
  ObjectID: Cardinal;
  const ExpectedSignature: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(PluginFile, ObjectID);
  if not Assigned(Result) or (Signature(Result) <> ExpectedSignature) then
    raise Exception.Create(
      'Could not resolve ' + ExpectedSignature + ' object ' +
      IntToHex(ObjectID, 6) + ' in ' + GetFileName(PluginFile)
    );
end;

function EnsureTopGroup(const SignatureValue: string): IInterface;
begin
  Result := GroupBySignature(OutputFile, SignatureValue);
  if not Assigned(Result) then
    Result := Add(OutputFile, 'GRUP', True);
  if Signature(Result) <> SignatureValue then
    SetElementEditValues(Result, 'Record Header\Signature', SignatureValue);
end;

function ScriptByName(
  RecordElement: IInterface;
  const ScriptNameValue: string
): IInterface;
var
  Scripts, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  Scripts := ElementByPath(RecordElement, 'VMAD\Scripts');
  if not Assigned(Scripts) then
    Exit;
  for i := 0 to Pred(ElementCount(Scripts)) do begin
    Candidate := ElementByIndex(Scripts, i);
    if LowerCase(GetElementEditValues(Candidate, 'ScriptName')) =
      LowerCase(ScriptNameValue) then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

function EnsureGateGlobal: IInterface;
var
  TemplateGlobal: IInterface;
begin
  TemplateGlobal := RequireRecord(CftoFile, $00AA12, 'GLOB');
  Result := wbCopyElementToFile(TemplateGlobal, OutputFile, True, False);
  if not Assigned(Result) then
    raise Exception.Create('Could not create BCD dialogue gate global');
  SetElementEditValues(Result, 'EDID', GateEditorID);
  SetElementNativeValues(Result, 'FLTV', 0.0);
end;

function GateConditionCount(
  InfoRecord, GateGlobal: IInterface
): Integer;
var
  Conditions, Entry, ConditionData, ParameterRecord: IInterface;
  i: Integer;
begin
  Result := 0;
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then
    Exit;
  for i := 0 to Pred(ElementCount(Conditions)) do begin
    Entry := ElementByIndex(Conditions, i);
    ConditionData := ElementByPath(Entry, 'CTDA');
    if not Assigned(ConditionData) or
      (GetElementEditValues(ConditionData, 'Function') <> 'GetGlobalValue') then
      Continue;
    ParameterRecord := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
    if Assigned(ParameterRecord) and
      (FormID(ParameterRecord) = FormID(GateGlobal)) then
      Inc(Result);
  end;
end;

procedure AddDialogueGate(
  InfoRecord, GateGlobal: IInterface;
  const LabelValue: string
);
var
  Conditions, ConditionEntry, ConditionData, ParameterElement,
    ReadBackParameter: IInterface;
begin
  if GateConditionCount(InfoRecord, GateGlobal) <> 0 then
    raise Exception.Create(LabelValue + ' already has a BCD dialogue gate');

  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then begin
    Add(InfoRecord, 'Conditions', True);
    Conditions := ElementByPath(InfoRecord, 'Conditions');
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create conditions for ' + LabelValue);

  ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create(LabelValue + ' gate has no CTDA');
  SetElementNativeValues(ConditionData, 'Type', EqualConditionType);
  SetElementNativeValues(ConditionData, 'Comparison Value - Float', 1.0);
  SetElementEditValues(ConditionData, 'Function', 'GetGlobalValue');
  SetElementNativeValues(ConditionData, 'Run On', 0);
  ParameterElement := ElementByPath(ConditionData, 'Parameter #1');
  SetEditValue(ParameterElement, Name(GateGlobal));
  ReadBackParameter := LinksTo(ParameterElement);
  if not Assigned(ReadBackParameter) or
    (FormID(ReadBackParameter) <> FormID(GateGlobal)) then
    raise Exception.Create(LabelValue + ' gate did not read back');
  if GateConditionCount(InfoRecord, GateGlobal) <> 1 then
    raise Exception.Create(LabelValue + ' gate count did not read back as one');
end;

procedure GateWinningInfo(
  SourceRecord, GateGlobal: IInterface;
  const ExpectedScript, LabelValue: string
);
var
  Winner, OverrideInfo: IInterface;
begin
  Winner := WinningOverride(SourceRecord);
  if not Assigned(Winner) then
    Winner := SourceRecord;
  if not Assigned(ScriptByName(Winner, ExpectedScript)) then
    raise Exception.Create(LabelValue + ' winning override lost ' + ExpectedScript);
  OverrideInfo := wbCopyElementToFile(Winner, OutputFile, False, True);
  if not Assigned(OverrideInfo) then
    raise Exception.Create('Could not override ' + LabelValue);
  AddDialogueGate(OverrideInfo, GateGlobal, LabelValue);
  Inc(GatedInfoCount);
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

function Initialize: Integer;
var
  GateGlobal, FileHeader: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\bcd-lorerim-compat.status';
  ErrorPath := ScriptsPath + '..\..\build\bcd-lorerim-compat.error';
  PluginOutputPath := ScriptsPath +
    '..\..\build\bcd-lorerim-compat\DiegeticTravelLoreRimBcdCompat.esp';
  WriteTextFile(StatusPath, 'running');

  try
    CftoFile := FileByPluginName('CFTO.esp');
    BcdBaseFile := FileByPluginName('Better Carriage Destinations.esp');
    BcdCftoFile := FileByPluginName('Better Carriage Destinations - CFTO.esp');
    WciiFile := FileByPluginName('WaitCarriageInns.esp');
    BcdWciiFile := FileByPluginName(
      'Better Carriage Destinations - Wait Carriage in Inns Patch.esp'
    );
    if not Assigned(CftoFile) or not Assigned(BcdBaseFile) or
      not Assigned(BcdCftoFile) or not Assigned(WciiFile) or
      not Assigned(BcdWciiFile) or
      not Assigned(FileByPluginName('DiegeticTravel.esp')) then
      raise Exception.Create('Required DNT, CFTO, WCI, or BCD plugin is missing');

    OutputFile := AddNewFileName(OutputPluginName);
    AddMasterIfMissing(OutputFile, 'Skyrim.esm');
    AddMasterIfMissing(OutputFile, 'Update.esm');
    AddMasterIfMissing(OutputFile, 'Dawnguard.esm');
    AddMasterIfMissing(OutputFile, 'HearthFires.esm');
    AddMasterIfMissing(OutputFile, 'Dragonborn.esm');
    AddMasterIfMissing(OutputFile, 'SkyUI_SE.esp');
    AddMasterIfMissing(OutputFile, 'WaitCarriageInns.esp');
    AddMasterIfMissing(OutputFile, 'Better Carriage Destinations.esp');
    AddMasterIfMissing(OutputFile,
      'Better Carriage Destinations - Wait Carriage in Inns Patch.esp');
    AddMasterIfMissing(OutputFile, 'CFTO.esp');
    AddMasterIfMissing(OutputFile, 'Better Carriage Destinations - CFTO.esp');
    AddMasterIfMissing(OutputFile, 'DiegeticTravel.esp');

    FileHeader := ElementByIndex(OutputFile, 0);
    SetElementNativeValues(FileHeader, 'HEDR\Next Object ID', $000800);
    GateGlobal := EnsureGateGlobal;
    { wbCopyElementToFile allocates the new global at 0x800 in this xEdit
      build but does not advance HEDR. Keep the next allocation explicit. }
    SetElementNativeValues(FileHeader, 'HEDR\Next Object ID', $000801);
    GatedInfoCount := 0;
    GateWinningInfo(
      RequireRecord(BcdBaseFile, $000015, 'INFO'),
      GateGlobal,
      'BCD_DialogScript',
      'BCD carriage dialogue'
    );
    GateWinningInfo(
      RequireRecord(BcdBaseFile, $00001A, 'INFO'),
      GateGlobal,
      'BCD_CFTOFerryDialogScript',
      'BCD CFTO ferry dialogue'
    );
    GateWinningInfo(
      RequireRecord(WciiFile, $000802, 'INFO'),
      GateGlobal,
      'BCD_WCII_DialogScript',
      'BCD WCI carriage dialogue'
    );
    if GatedInfoCount <> 3 then
      raise Exception.Create('Expected exactly three BCD dialogue overrides');
    { In this patched xEdit build CanBeESL reports whether the file is already
      assigned to a light load-order slot, so it cannot validate a new file
      before the ESL flag is set. The Next Object ID and reload audit enforce
      the actual compact-form range. }
    SetIsESL(OutputFile, True);
    if not GetIsESL(OutputFile) then
      raise Exception.Create('Could not set the BCD compatibility ESL flag');
    SaveGeneratedPlugin;
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Generated LoreRim BCD coexistence ESL with three gated INFOs');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
