unit DNT_InventoryWizardFormalMapTransform;

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

function ContainingRecordOfSignature(
  RecordElement: IInterface;
  const ExpectedSignature: string
): IInterface;
begin
  Result := GetContainer(RecordElement);
  while Assigned(Result) and (Signature(Result) <> ExpectedSignature) do
    Result := GetContainer(Result);
end;

function ValueOrMissing(RecordElement: IInterface; const ElementPath: string): string;
begin
  Result := GetElementEditValues(RecordElement, ElementPath);
  if Result = '' then
    Result := '<missing>';
end;

procedure ReportMarker(FormIDValue: Cardinal);
var
  MarkerRecord, CellRecord, WorldRecord, ParentWorld: IInterface;
begin
  MarkerRecord := RecordByFormID(SkyrimFile, FormIDValue, True);
  if not Assigned(MarkerRecord) then
    raise Exception.Create('Could not resolve marker ' + IntToHex(FormIDValue, 8));

  CellRecord := ContainingRecordOfSignature(MarkerRecord, 'CELL');
  WorldRecord := ContainingRecordOfSignature(MarkerRecord, 'WRLD');
  if Assigned(WorldRecord) then
    ParentWorld := LinksTo(ElementByPath(WorldRecord, 'Parent Worldspace\World'))
  else
    ParentWorld := nil;

  ReportLines.Add('MARKER ' + IntToHex(FormIDValue, 8));
  ReportLines.Add('  edid=' + ValueOrMissing(MarkerRecord, 'EDID'));
  ReportLines.Add(
    '  position=' + ValueOrMissing(MarkerRecord, 'DATA\Position\X') + ',' +
    ValueOrMissing(MarkerRecord, 'DATA\Position\Y') + ',' +
    ValueOrMissing(MarkerRecord, 'DATA\Position\Z')
  );
  if Assigned(CellRecord) then begin
    ReportLines.Add(
      '  cell=' + IntToHex(GetLoadOrderFormID(CellRecord), 8) +
      ' edid=' + ValueOrMissing(CellRecord, 'EDID') +
      ' grid=' + ValueOrMissing(CellRecord, 'XCLC\X') + ',' +
      ValueOrMissing(CellRecord, 'XCLC\Y')
    );
  end else
    ReportLines.Add('  cell=<unresolved>');
  if Assigned(WorldRecord) then begin
    ReportLines.Add(
      '  world=' + IntToHex(GetLoadOrderFormID(WorldRecord), 8) +
      ' edid=' + ValueOrMissing(WorldRecord, 'EDID')
    );
    if Assigned(ParentWorld) then
      ReportLines.Add(
        '  parent=' + IntToHex(GetLoadOrderFormID(ParentWorld), 8) +
        ' edid=' + ValueOrMissing(ParentWorld, 'EDID')
      )
    else
      ReportLines.Add('  parent=<none>');
    ReportLines.Add(
      '  parentFlags=' +
      ValueOrMissing(WorldRecord, 'Parent Worldspace\Flags')
    );
    ReportLines.Add(
      '  mapOffset=' +
      ValueOrMissing(WorldRecord, 'World Map Offset Data\World Map Scale') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Offset Data\Cell X Offset') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Offset Data\Cell Y Offset') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Offset Data\Cell Z Offset')
    );
    ReportLines.Add(
      '  mapDimensions=' +
      ValueOrMissing(WorldRecord, 'World Map Data\Usable Dimensions\X') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Data\Usable Dimensions\Y')
    );
    ReportLines.Add(
      '  mapCellsNW=' +
      ValueOrMissing(WorldRecord, 'World Map Data\Cell Coordinates\NW Cell\X') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Data\Cell Coordinates\NW Cell\Y')
    );
    ReportLines.Add(
      '  mapCellsSE=' +
      ValueOrMissing(WorldRecord, 'World Map Data\Cell Coordinates\SE Cell\X') + ',' +
      ValueOrMissing(WorldRecord, 'World Map Data\Cell Coordinates\SE Cell\Y')
    );
  end else
    ReportLines.Add('  world=<unresolved>');
  ReportLines.Add('');
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-formal-map-transform.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-formal-map-transform.error';
  ReportPath := ScriptsPath + '..\..\build\wizard-formal-map-transform.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    ReportMarker($000162CE); // Whiterun
    ReportMarker($0001C390); // Riften
    ReportMarker($0004D0F4); // Solitude
    ReportMarker($00038436); // Windhelm
    ReportMarker($0001C38A); // Markarth
    ReportMarker($0001773A); // Dawnstar
    ReportMarker($000177B0); // Morthal
    ReportMarker($00046BDF); // College of Winterhold

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
