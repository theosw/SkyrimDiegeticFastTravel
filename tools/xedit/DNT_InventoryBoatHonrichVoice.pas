unit DNT_InventoryBoatHonrichVoice;

uses SysUtils, Classes;

var
  CftoFile, DawnguardFile: IInterface;
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

procedure AddActorVoice(ObjectID: Cardinal);
var
  ActorRecord, VoiceType: IInterface;
begin
  ActorRecord := RequireRecord(CftoFile, ObjectID, 'NPC_');
  VoiceType := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  if not Assigned(VoiceType) then
    raise Exception.Create(GetElementEditValues(ActorRecord, 'EDID') +
      ' has no voice type');
  ReportLines.Add(
    'ACTOR=' + GetElementEditValues(ActorRecord, 'EDID') +
    '|NAME=' + GetElementEditValues(ActorRecord, 'FULL') +
    '|VOICE=' + GetElementEditValues(VoiceType, 'EDID') +
    '|VOICE_FORM=' + IntToHex(FixedFormID(VoiceType), 8)
  );
end;

function Initialize: Integer;
var
  SharedInfo: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\boat-honrich-voice-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\boat-honrich-voice-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-honrich-voice-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CftoFile := FileByPluginName('CFTO.esp');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    if not Assigned(CftoFile) or not Assigned(DawnguardFile) then
      raise Exception.Create('Required CFTO or Dawnguard file is missing');
    AddActorVoice($00FB28);
    AddActorVoice($00FB24);
    AddActorVoice($014C52);
    SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO');
    ReportLines.Add(
      'SHARED_INFO=' + GetElementEditValues(SharedInfo, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(SharedInfo), 8) +
      '|TEXT=' + GetElementEditValues(SharedInfo, 'Responses\Response\NAM1')
    );
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
