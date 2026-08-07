unit DNT_InventoryBoatNorthCoast;

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
  const ExpectedSignature, ExpectedEditorID: string
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
  if (ExpectedEditorID <> '') and
    (GetElementEditValues(Result, 'EDID') <> ExpectedEditorID) then
    raise Exception.Create(IntToHex(ObjectID, 6) + ' is not ' +
      ExpectedEditorID);
end;

procedure AddActorVoice(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  ActorRecord, VoiceType: IInterface;
begin
  ActorRecord := RequireRecord(CftoFile, ObjectID, 'NPC_', ExpectedEditorID);
  VoiceType := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  if not Assigned(VoiceType) then
    raise Exception.Create(ExpectedEditorID + ' has no voice type');
  ReportLines.Add(
    'ACTOR=' + ExpectedEditorID +
    '|NAME=' + GetElementEditValues(ActorRecord, 'FULL') +
    '|FORM=' + IntToHex(FixedFormID(ActorRecord), 8) +
    '|VOICE=' + GetElementEditValues(VoiceType, 'EDID') +
    '|VOICE_FORM=' + IntToHex(FixedFormID(VoiceType), 8)
  );
end;

procedure AddMarker(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  MarkerRecord: IInterface;
begin
  MarkerRecord := RequireRecord(CftoFile, ObjectID, 'REFR', ExpectedEditorID);
  ReportLines.Add(
    'MARKER=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(MarkerRecord), 8) +
    '|X=' + FloatToStr(GetElementNativeValues(
      MarkerRecord,
      'DATA\Position\X'
    )) +
    '|Y=' + FloatToStr(GetElementNativeValues(
      MarkerRecord,
      'DATA\Position\Y'
    )) +
    '|Z=' + FloatToStr(GetElementNativeValues(
      MarkerRecord,
      'DATA\Position\Z'
    )) +
    '|ANGLE_Z=' + FloatToStr(GetElementNativeValues(
      MarkerRecord,
      'DATA\Rotation\Z'
    ))
  );
end;

procedure AddTopic(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  TopicRecord: IInterface;
begin
  TopicRecord := RequireRecord(CftoFile, ObjectID, 'DIAL', ExpectedEditorID);
  ReportLines.Add(
    'TOPIC=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(TopicRecord), 8) +
    '|PROMPT=' + GetElementEditValues(TopicRecord, 'FULL')
  );
end;

function Initialize: Integer;
var
  FareGlobal, RouteFaction, DialogueFaction, SharedInfo: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\boat-north-coast-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\boat-north-coast-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-north-coast-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CftoFile := FileByPluginName('CFTO.esp');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    if not Assigned(CftoFile) or not Assigned(DawnguardFile) then
      raise Exception.Create('Required CFTO or Dawnguard file is missing');

    AddActorVoice($00AA07, 'KmodFerrymanDawnstar');
    AddActorVoice($00AA08, 'KmodFerrymanSolitude');
    AddActorVoice($00AA09, 'KmodFerrymanWindhelm');
    AddActorVoice($00AA0B, 'KmodFerrymanMorthal');
    AddActorVoice($014C5A, 'KmodFerrymanLighthouse');
    AddActorVoice($158FFC, 'KmodFerrymanWinterhold');
    AddActorVoice($2D4C09, 'KmodFerrymanDragonBridge');
    AddActorVoice($1F0E6A, 'KmodFerrymanVolkihar');

    AddMarker($00FB1F, 'KmodFerryDawnstarMarker');
    AddMarker($00FB1E, 'KmodFerrySolitudeMarker');
    AddMarker($00FB1D, 'KmodFerryWindhelmMarker');
    AddMarker($00FB17, 'KmodFerryMorthalMarker');
    AddMarker($019DB2, 'KmodFerryLighthouseMarker');
    AddMarker($038413, 'KmodFerryWinterholdMarker');
    AddMarker($29D0A4, 'KmodFerryDragonBridgeMarker');
    AddMarker($038411, 'KmodFerryFrostflowMarker');
    AddMarker($03840F, 'KmodFerryIcewaterMarker');

    FareGlobal := RequireRecord(
      CftoFile,
      $00AA12,
      'GLOB',
      'KmodFerryCost'
    );
    ReportLines.Add(
      'GLOBAL=KmodFerryCost|FORM=' +
      IntToHex(FixedFormID(FareGlobal), 8) +
      '|VALUE=' + GetElementEditValues(FareGlobal, 'FLTV')
    );
    RouteFaction := RequireRecord(
      CftoFile,
      $019DC6,
      'FACT',
      'KmodFerryRoute1Faction'
    );
    DialogueFaction := RequireRecord(
      CftoFile,
      $00AA05,
      'FACT',
      'KmodFastTravelDialogueFaction'
    );
    ReportLines.Add(
      'ROUTE_FACTION=' + GetElementEditValues(RouteFaction, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(RouteFaction), 8)
    );
    ReportLines.Add(
      'DIALOGUE_FACTION=' + GetElementEditValues(DialogueFaction, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(DialogueFaction), 8)
    );

    AddTopic($00AA0E, 'KmodFastTravelFerryTopic');
    AddTopic($00AA10, 'KmodFastTravelFerryMorthal');
    AddTopic($014CA7, 'KmodFastTravelFerrySolitude');
    AddTopic($019DAC, 'KmodFastTravelFerryWindhelm');
    AddTopic($019DB0, 'KmodFastTravelFerryLighthouse');
    AddTopic($019DB5, 'KmodFastTravelFerryDawnstar');
    AddTopic($038414, 'KmodFastTravelFerryFrostflow');
    AddTopic($038418, 'KmodFastTravelFerryWinterhold');
    AddTopic($038427, 'KmodFastTravelFerryIcewater');
    AddTopic($2D9D0B, 'KmodFastTravelFerryDragonBridge');

    SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO', '');
    ReportLines.Add(
      'SHARED_INFO=' + GetElementEditValues(SharedInfo, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(SharedInfo), 8) +
      '|TEXT=' + GetElementEditValues(
        SharedInfo,
        'Responses\Response\NAM1'
      )
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
