unit DNT_FinalizeReleasePlugin;

uses SysUtils, Classes;

const
  OutputPluginName = 'DiegeticTravel.esp';
  ExpectedMasterCount = 6;
  ExpectedStartGameQuestCount = 18;

var
  OutputFile: IInterface;
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

function OutputHasMaster(const MasterName: string): Boolean;
var
  i: Integer;
begin
  Result := False;
  for i := 0 to Pred(MasterCount(OutputFile)) do
    if LowerCase(GetFileName(MasterByIndex(OutputFile, i))) =
      LowerCase(MasterName) then begin
      Result := True;
      Exit;
    end;
end;

procedure ValidateMasters;
begin
  if MasterCount(OutputFile) <> ExpectedMasterCount then
    raise Exception.Create(
      'Release plugin has ' + IntToStr(MasterCount(OutputFile)) +
      ' masters; expected ' + IntToStr(ExpectedMasterCount)
    );
  if not OutputHasMaster('Skyrim.esm') or
    not OutputHasMaster('Update.esm') or
    not OutputHasMaster('Dawnguard.esm') or
    not OutputHasMaster('HearthFires.esm') or
    not OutputHasMaster('Dragonborn.esm') or
    not OutputHasMaster('CFTO.esp') then
    raise Exception.Create('Release plugin master set is incomplete');
  if OutputHasMaster('DiegeticTravelWizardGuides.esp') or
    OutputHasMaster('DiegeticTravelWizardParchment.esp') or
    OutputHasMaster('DiegeticTravelCarriageParchment.esp') or
    OutputHasMaster('Better Carriage Destinations.esp') or
    OutputHasMaster('Journey to Baan Malur.esp') then
    raise Exception.Create('Release plugin retained a development-only master');
end;

procedure ValidateFormIDRange;
var
  FileHeader: IInterface;
  NextObjectID: Cardinal;
begin
  FileHeader := ElementByIndex(OutputFile, 0);
  if not Assigned(FileHeader) then
    raise Exception.Create('Release plugin has no file header');
  NextObjectID := GetElementNativeValues(
    FileHeader,
    'HEDR\Next Object ID'
  );
  if (NextObjectID <= $000800) or (NextObjectID > $001000) then
    raise Exception.Create(
      'Release plugin Next Object ID is outside the ESL range: ' +
      IntToHex(NextObjectID, 6)
    );
end;

procedure SaveCombinedSeqManifest;
var
  QuestGroup, QuestRecord, QuestFlags, MasterQuest: IInterface;
  SeqFormIDs: TStringList;
  i: Integer;
begin
  QuestGroup := GroupBySignature(OutputFile, 'QUST');
  if not Assigned(QuestGroup) then
    raise Exception.Create('Release plugin has no quest group');

  SeqFormIDs := TStringList.Create;
  try
    SeqFormIDs.Sorted := True;
    SeqFormIDs.Duplicates := dupError;
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
    if SeqFormIDs.Count <> ExpectedStartGameQuestCount then
      raise Exception.Create(
        'Release plugin has ' + IntToStr(SeqFormIDs.Count) +
        ' SEQ quests; expected ' + IntToStr(ExpectedStartGameQuestCount)
      );
    SeqFormIDs.SaveToFile(SeqFormIDsPath);
  finally
    SeqFormIDs.Free;
  end;
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
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\release-finalize.status';
  ErrorPath := ScriptsPath + '..\..\build\release-finalize.error';
  PluginOutputPath := ScriptsPath +
    '..\..\build\release\DiegeticTravel.esp';
  SeqFormIDsPath := ScriptsPath +
    '..\..\build\release-seq-formids.txt';
  WriteTextFile(StatusPath, 'running');

  try
    OutputFile := FileByPluginName(OutputPluginName);
    if not Assigned(OutputFile) then
      raise Exception.Create('Consolidated release plugin is not loaded');
    ValidateMasters;
    ValidateFormIDRange;
    if not CanBeESL(OutputFile) then
      raise Exception.Create('xEdit reports that the release plugin cannot be ESL');
    SetIsESL(OutputFile, True);
    if not GetIsESL(OutputFile) then
      raise Exception.Create('Could not set the ESL flag');
    SaveCombinedSeqManifest;
    SaveGeneratedPlugin;
    WriteTextFile(StatusPath, 'success');
    AddMessage('[DNT] Finalized consolidated ESL-flagged release plugin');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
      raise;
    end;
  end;
end;

end.
