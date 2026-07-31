unit DNT_InventorySolitudeWizardSpoke;

uses SysUtils, Classes;

var
  SkyrimFile: IInterface;
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

function FormHex(RecordElement: IInterface): string;
begin
  Result := IntToHex(GetLoadOrderFormID(RecordElement), 8);
end;

function RequireSkyrimRecord(
  FormIDValue: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := RecordByFormID(SkyrimFile, FormIDValue, True);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve Skyrim record ' + IntToHex(FormIDValue, 8)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      IntToHex(FormIDValue, 8) + ' is not ' + ExpectedEditorID
    );
end;

procedure ReportReference(ReferenceRecord: IInterface; const GroupLabel: string);
var
  WinnerRecord, BaseRecord: IInterface;
  BaseEditorID, BaseName, PositionText, FlagsText, WinnerName: string;
begin
  WinnerRecord := WinningOverride(ReferenceRecord);
  if not Assigned(WinnerRecord) then
    WinnerRecord := ReferenceRecord;
  BaseRecord := LinksTo(ElementByPath(ReferenceRecord, 'NAME'));
  if Assigned(BaseRecord) then begin
    BaseEditorID := GetElementEditValues(BaseRecord, 'EDID');
    BaseName := Name(BaseRecord);
  end else begin
    BaseEditorID := '<unresolved>';
    BaseName := '<unresolved>';
  end;

  PositionText :=
    GetElementEditValues(WinnerRecord, 'DATA\Position\X') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Y') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Z');
  FlagsText := GetElementEditValues(
    WinnerRecord,
    'Record Header\Record Flags'
  );
  WinnerName := GetFileName(GetFile(WinnerRecord));

  ReportLines.Add(
    FormHex(ReferenceRecord) +
    ' | ' + GroupLabel +
    ' | ' + GetElementEditValues(ReferenceRecord, 'EDID') +
    ' | base=' + BaseEditorID +
    ' | ' + BaseName +
    ' | position=' + PositionText +
    ' | winner=' + WinnerName +
    ' | flags=' + FlagsText
  );
end;

procedure ReportCellGroup(CellRecord: IInterface; GroupType: Integer;
  const GroupLabel: string);
var
  ReferenceGroup, ReferenceRecord, BaseRecord: IInterface;
  BaseEditorID: string;
  i: Integer;
begin
  ReferenceGroup := FindChildGroup(ChildGroup(CellRecord), GroupType, CellRecord);
  if not Assigned(ReferenceGroup) then
    Exit;

  for i := 0 to Pred(ElementCount(ReferenceGroup)) do begin
    ReferenceRecord := ElementByIndex(ReferenceGroup, i);
    if Signature(ReferenceRecord) <> 'REFR' then
      Continue;
    BaseRecord := LinksTo(ElementByPath(ReferenceRecord, 'NAME'));
    if not Assigned(BaseRecord) then
      Continue;
    BaseEditorID := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
    if
      (Pos('marker', BaseEditorID) > 0) or
      (Pos('xmarker', BaseEditorID) > 0)
    then
      ReportReference(ReferenceRecord, GroupLabel);
  end;
end;

function Initialize: Integer;
var
  Sybille, SybilleVoice, SybilleRef, SybilleBase, BluePalace: IInterface;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\solitude-wizard-spoke.status';
  ErrorPath :=
    ScriptsPath + '..\..\build\solitude-wizard-spoke.error';
  ReportPath :=
    ScriptsPath + '..\..\build\solitude-wizard-spoke.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    Sybille := RequireSkyrimRecord($000132AA, 'NPC_', 'SybilleStentor');
    SybilleVoice := LinksTo(ElementByPath(Sybille, 'VTCK'));
    if not Assigned(SybilleVoice) then
      raise Exception.Create('Sybille has no voice type');
    ReportLines.Add(
      'NPC=' + FormHex(Sybille) +
      ' | ' + GetElementEditValues(Sybille, 'EDID') +
      ' | voice=' + GetElementEditValues(SybilleVoice, 'EDID')
    );

    SybilleRef := RecordByFormID(SkyrimFile, $000198C5, True);
    if not Assigned(SybilleRef) or (Signature(SybilleRef) <> 'ACHR') then
      raise Exception.Create('Sybille reference 000198C5 did not resolve');
    SybilleBase := LinksTo(ElementByPath(SybilleRef, 'NAME'));
    if not Assigned(SybilleBase) or
      (GetLoadOrderFormID(SybilleBase) <> $000132AA) then
      raise Exception.Create('Sybille reference has the wrong base actor');
    ReportLines.Add(
      'REFERENCE=' + FormHex(SybilleRef) +
      ' | base=' + GetElementEditValues(SybilleBase, 'EDID') +
      ' | position=' +
      GetElementEditValues(SybilleRef, 'DATA\Position\X') + ',' +
      GetElementEditValues(SybilleRef, 'DATA\Position\Y') + ',' +
      GetElementEditValues(SybilleRef, 'DATA\Position\Z')
    );

    BluePalace := RequireSkyrimRecord(
      $00016A04,
      'CELL',
      'SolitudeBluePalace'
    );
    ReportLines.Add(
      'CELL=' + FormHex(BluePalace) +
      ' | ' + GetElementEditValues(BluePalace, 'EDID')
    );
    ReportLines.Add('MARKER REFERENCES:');
    ReportCellGroup(BluePalace, 8, 'Persistent');
    ReportCellGroup(BluePalace, 9, 'Temporary');

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
