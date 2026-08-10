unit DNT_InventoryCFTOPrivateFerries;

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

function ContainingCell(ReferenceRecord: IInterface): IInterface;
begin
  Result := GetContainer(ReferenceRecord);
  while Assigned(Result) and (Signature(Result) <> 'CELL') do
    Result := GetContainer(Result);
end;

procedure AddActor(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  ActorRecord, VoiceType: IInterface;
begin
  ActorRecord := RequireRecord(CftoFile, ObjectID, 'NPC_', ExpectedEditorID);
  VoiceType := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  ReportLines.Add(
    'ACTOR=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(ActorRecord), 8) +
    '|NAME=' + GetElementEditValues(ActorRecord, 'FULL') +
    '|VOICE=' + GetElementEditValues(VoiceType, 'EDID')
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
    '|X=' + GetElementEditValues(MarkerRecord, 'DATA\Position\X') +
    '|Y=' + GetElementEditValues(MarkerRecord, 'DATA\Position\Y') +
    '|Z=' + GetElementEditValues(MarkerRecord, 'DATA\Position\Z')
  );
end;

procedure AddGlobal(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  GlobalRecord: IInterface;
begin
  GlobalRecord := RequireRecord(CftoFile, ObjectID, 'GLOB', ExpectedEditorID);
  ReportLines.Add(
    'GLOBAL=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(GlobalRecord), 8) +
    '|VALUE=' + GetElementEditValues(GlobalRecord, 'FLTV')
  );
end;

procedure AddItem(ObjectID: Cardinal; const ExpectedEditorID: string);
var
  ItemRecord: IInterface;
begin
  ItemRecord := RequireRecord(CftoFile, ObjectID, 'MISC', ExpectedEditorID);
  ReportLines.Add(
    'ITEM=' + ExpectedEditorID +
    '|FORM=' + IntToHex(FixedFormID(ItemRecord), 8) +
    '|NAME=' + GetElementEditValues(ItemRecord, 'FULL')
  );
end;

procedure ReportPlacedActors;
var
  Candidate, BaseRecord, CellRecord: IInterface;
  BaseEditorID, CellEditorID: string;
  i: Integer;
begin
  for i := 0 to Pred(RecordCount(CftoFile)) do begin
    Candidate := RecordByIndex(CftoFile, i);
    if Signature(Candidate) <> 'ACHR' then
      Continue;
    BaseRecord := LinksTo(ElementByPath(Candidate, 'NAME'));
    if not Assigned(BaseRecord) then
      Continue;
    BaseEditorID := GetElementEditValues(BaseRecord, 'EDID');
    if (BaseEditorID <> 'KmodFerrymanHoneyside') and
      (BaseEditorID <> 'KmodFerrymanLakeview') and
      (BaseEditorID <> 'KmodFerrymanWindstad') and
      (BaseEditorID <> 'KmodFerrymanVolkihar') then
      Continue;
    CellRecord := ContainingCell(Candidate);
    if Assigned(CellRecord) then
      CellEditorID := GetElementEditValues(CellRecord, 'EDID')
    else
      CellEditorID := '<unresolved>';
    ReportLines.Add(
      'PLACED_ACTOR=' + BaseEditorID +
      '|FORM=' + IntToHex(FixedFormID(Candidate), 8) +
      '|CELL=' + CellEditorID +
      '|FLAGS=' + GetElementEditValues(
        Candidate,
        'Record Header\Record Flags'
      ) +
      '|ENABLE_PARENT=' + GetElementEditValues(Candidate, 'XESP\Reference')
    );
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\cfto-private-ferries-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\cfto-private-ferries-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\cfto-private-ferries-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(CftoFile) then
      raise Exception.Create('Required CFTO file is missing');

    AddActor($014C8C, 'KmodFerrymanHoneyside');
    AddActor($014C80, 'KmodFerrymanLakeview');
    AddActor($014C89, 'KmodFerrymanWindstad');
    AddActor($1F0E6A, 'KmodFerrymanVolkihar');

    AddMarker($014C8E, 'KmodFerryHoneysideMarker');
    AddMarker($014C7E, 'KmodFerryLakeviewMarker');
    AddMarker($014C86, 'KmodFerryWindstadMarker');
    AddMarker($03840F, 'KmodFerryIcewaterMarker');

    AddGlobal($00AA12, 'KmodFerryCost');
    AddGlobal($0BBF93, 'KmodFerryCostLocal');
    AddGlobal($038425, 'KmodFerryCostExtra');
    AddGlobal($038426, 'KmodFerryVolkihar');
    AddItem($019DBB, 'KmodHouse1Dock');
    AddItem($019DBE, 'KmodHouse2Dock');
    ReportPlacedActors;

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
