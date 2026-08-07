unit DNT_InventoryBoatSolstheim;

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

procedure AddActorVoice(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
);
var
  ActorRecord, VoiceType: IInterface;
begin
  ActorRecord := RequireRecord(
    CftoFile,
    ObjectID,
    'NPC_',
    ExpectedEditorID
  );
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

procedure AddMarker(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
);
var
  MarkerRecord: IInterface;
begin
  MarkerRecord := RequireRecord(
    CftoFile,
    ObjectID,
    'REFR',
    ExpectedEditorID
  );
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

procedure AddGlobal(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
);
var
  GlobalRecord: IInterface;
begin
  GlobalRecord := RequireRecord(
    CftoFile,
    ObjectID,
    'GLOB',
    ExpectedEditorID
  );
  ReportLines.Add(
    'GLOBAL=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(GlobalRecord), 8) +
    '|VALUE=' + GetElementEditValues(GlobalRecord, 'FLTV')
  );
end;

procedure AddTopic(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
);
var
  TopicRecord: IInterface;
begin
  TopicRecord := RequireRecord(
    CftoFile,
    ObjectID,
    'DIAL',
    ExpectedEditorID
  );
  ReportLines.Add(
    'TOPIC=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(TopicRecord), 8) +
    '|PROMPT=' + GetElementEditValues(TopicRecord, 'FULL')
  );
end;

function Initialize: Integer;
var
  SharedInfo, RouteFaction: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\boat-solstheim-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\boat-solstheim-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\boat-solstheim-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CftoFile := FileByPluginName('CFTO.esp');
    DawnguardFile := FileByPluginName('Dawnguard.esm');
    if not Assigned(CftoFile) or not Assigned(DawnguardFile) then
      raise Exception.Create('Required CFTO or Dawnguard file is missing');

    AddActorVoice($014C6C, 'KmodFerrymanSkaal');
    AddActorVoice($014C6E, 'KmodFerrymanRavenRock');
    AddActorVoice($014C78, 'KmodFerrymanTelMithryn');

    AddMarker($014C6B, 'KmodFerrySkaalMarker');
    AddMarker($014C72, 'KmodFerryRavenRockMarker');
    AddMarker($014C7A, 'KmodFerryTelMithrynMarker');
    AddMarker($195C44, 'KmodFerryTelMithrynFollowerMarker');
    AddMarker($195C45, 'KmodFerrySkaalFollowerMarker');

    AddMarker($03840C, 'KmodFerryNorthshoreMarker');
    AddMarker($03840D, 'KmodFerryBujoldMarker');

    AddGlobal($00AA12, 'KmodFerryCost');

    RouteFaction := RequireRecord(
      CftoFile,
      $02E1E0,
      'FACT',
      'KmodFerryRoute4Faction'
    );
    ReportLines.Add(
      'ROUTE_FACTION=' + GetElementEditValues(RouteFaction, 'EDID') +
      '|FORM=' + IntToHex(FixedFormID(RouteFaction), 8)
    );

    AddTopic($0383FE, 'KmodFastTravelFerryTopic04');
    AddTopic($038400, 'KmodFastTravelFerryRavenRock');
    AddTopic($038404, 'KmodFastTravelFerryTelMithryn');
    AddTopic($038408, 'KmodFastTravelFerrySkaal');
    AddTopic($03842D, 'KmodFastTravelFerryNorthshore');
    AddTopic($038431, 'KmodFastTravelFerryBujold');

    SharedInfo := RequireRecord(DawnguardFile, $01683A, 'INFO', '');
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
