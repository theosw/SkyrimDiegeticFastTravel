unit DNT_InventoryCollegeArrivalMarkers;

uses SysUtils, Classes;

var
  SkyrimFile, JKCollegeFile: IInterface;
  ReportLines, SeenFormIDs, TargetEditorIDs: TStringList;
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

function ContainingCell(ReferenceRecord: IInterface): IInterface;
begin
  Result := GetContainer(ReferenceRecord);
  while Assigned(Result) and (Signature(Result) <> 'CELL') do
    Result := GetContainer(Result);
end;

function SafeWinner(RecordElement: IInterface): IInterface;
begin
  Result := WinningOverride(RecordElement);
  if not Assigned(Result) then
    Result := RecordElement;
end;

function CollegeContext(
  ReferenceRecord, CellRecord, LocationRecord, BaseRecord: IInterface
): Boolean;
var
  ReferenceEditorID, CellEditorID, LocationEditorID, BaseEditorID: string;
begin
  ReferenceEditorID := LowerCase(
    GetElementEditValues(ReferenceRecord, 'EDID')
  );
  CellEditorID := '';
  if Assigned(CellRecord) then
    CellEditorID := LowerCase(GetElementEditValues(CellRecord, 'EDID'));
  LocationEditorID := '';
  if Assigned(LocationRecord) then
    LocationEditorID := LowerCase(
      GetElementEditValues(LocationRecord, 'EDID')
    );
  BaseEditorID := '';
  if Assigned(BaseRecord) then
    BaseEditorID := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));

  Result :=
    (Pos('college', ReferenceEditorID) > 0) or
    (Pos('college', CellEditorID) > 0) or
    (Pos('college', LocationEditorID) > 0) or
    (
      (Pos('winterhold', ReferenceEditorID) > 0) and
      ((Pos('marker', ReferenceEditorID) > 0) or
       (Pos('marker', BaseEditorID) > 0))
    );
end;

function IsMarkerReference(
  ReferenceRecord, BaseRecord: IInterface
): Boolean;
var
  ReferenceEditorID, BaseEditorID: string;
begin
  ReferenceEditorID := LowerCase(
    GetElementEditValues(ReferenceRecord, 'EDID')
  );
  BaseEditorID := '';
  if Assigned(BaseRecord) then
    BaseEditorID := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
  Result :=
    (Pos('marker', ReferenceEditorID) > 0) or
    (Pos('marker', BaseEditorID) > 0) or
    (Pos('travel', ReferenceEditorID) > 0) or
    (Pos('teleport', ReferenceEditorID) > 0);
end;

procedure ReportReference(ReferenceRecord: IInterface);
var
  WinnerRecord, BaseRecord, CellRecord, CellWinner, LocationRecord: IInterface;
  FormIDText, CellText, LocationText, PositionText, RotationText: string;
begin
  FormIDText := IntToHex(GetLoadOrderFormID(ReferenceRecord), 8);
  if SeenFormIDs.IndexOf(FormIDText) >= 0 then
    Exit;

  WinnerRecord := SafeWinner(ReferenceRecord);
  BaseRecord := LinksTo(ElementByPath(WinnerRecord, 'NAME'));
  CellRecord := ContainingCell(ReferenceRecord);
  if Assigned(CellRecord) then begin
    CellWinner := SafeWinner(CellRecord);
    LocationRecord := LinksTo(ElementByPath(CellWinner, 'XLCN'));
    CellText := GetElementEditValues(CellWinner, 'EDID');
  end else begin
    CellWinner := nil;
    LocationRecord := nil;
    CellText := '<unresolved>';
  end;
  if Assigned(LocationRecord) then
    LocationText := GetElementEditValues(LocationRecord, 'EDID')
  else
    LocationText := '<none>';

  if not IsMarkerReference(WinnerRecord, BaseRecord) then
    Exit;

  SeenFormIDs.Add(FormIDText);
  PositionText :=
    GetElementEditValues(WinnerRecord, 'DATA\Position\X') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Y') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Z');
  RotationText :=
    GetElementEditValues(WinnerRecord, 'DATA\Rotation\X') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Rotation\Y') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Rotation\Z');

  ReportLines.Add(
    FormIDText +
    ' | edid=' + GetElementEditValues(WinnerRecord, 'EDID') +
    ' | base=' + GetElementEditValues(BaseRecord, 'EDID') +
    ' | cell=' + CellText +
    ' | location=' + LocationText +
    ' | position=' + PositionText +
    ' | rotation=' + RotationText +
    ' | origin=' + GetFileName(GetFile(MasterOrSelf(ReferenceRecord))) +
    ' | winner=' + GetFileName(GetFile(WinnerRecord)) +
    ' | flags=' + GetElementEditValues(
      WinnerRecord,
      'Record Header\Record Flags'
    )
  );
end;

procedure AddTarget(const EditorIDValue: string);
begin
  TargetEditorIDs.Add(LowerCase(EditorIDValue));
end;

procedure ScanTargets(PluginFile: IInterface);
var
  Candidate: IInterface;
  CandidateEditorID: string;
  FoundCount, i: Integer;
begin
  FoundCount := 0;
  for i := 0 to Pred(RecordCount(PluginFile)) do begin
    Candidate := RecordByIndex(PluginFile, i);
    if Signature(Candidate) <> 'REFR' then
      Continue;
    CandidateEditorID := LowerCase(
      GetElementEditValues(Candidate, 'EDID')
    );
    if TargetEditorIDs.IndexOf(CandidateEditorID) < 0 then
      Continue;
    ReportReference(Candidate);
    Inc(FoundCount);
    if FoundCount = TargetEditorIDs.Count then
      Break;
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\college-arrival-markers.status';
  ErrorPath := ScriptsPath +
    '..\..\build\college-arrival-markers.error';
  ReportPath := ScriptsPath +
    '..\..\build\college-arrival-markers.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  SeenFormIDs := TStringList.Create;
  SeenFormIDs.Sorted := True;
  SeenFormIDs.Duplicates := dupIgnore;
  TargetEditorIDs := TStringList.Create;
  TargetEditorIDs.Sorted := True;
  TargetEditorIDs.Duplicates := dupIgnore;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    JKCollegeFile := FileByPluginName('JK''s College of Winterhold.esp');
    if not Assigned(SkyrimFile) or not Assigned(JKCollegeFile) then
      raise Exception.Create('Skyrim.esm or JK''s College is not loaded');

    ReportLines.Add(
      'College arrival-marker candidates from Skyrim and JK''s College'
    );
    ReportLines.Add('');
    AddTarget('WinterholdCollegeMapMarkerRef');
    AddTarget('MG01TourMarkerExtClass');
    AddTarget('MG01TourMarkerExtDorm');
    AddTarget('MG01TourMarkerHallExt');
    AddTarget('MG01TourMarker1');
    AddTarget('MG05PlayerStartMarker');
    AddTarget('MG05PlayerMarker');
    AddTarget('MG05PlayerFollowerMarker');
    AddTarget('MG05MirabelleStartMarker');
    AddTarget('MG05MirabelleDefendMarker');
    AddTarget('MG05MirabelleEndMarker');
    AddTarget('MG05FaraldaTraveltoBridgeMarker');
    AddTarget('MG05ArnielTraveltoBridgeMarker');
    AddTarget('MG07FaraldaBridgeMarker');
    AddTarget('MG07TolfdirBridgeMarker');
    AddTarget('MG07ArnielGaneBridgeMarker');
    AddTarget('MGPhinisSleepMarker');
    ScanTargets(SkyrimFile);
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
  if Assigned(TargetEditorIDs) then
    TargetEditorIDs.Free;
  if Assigned(SeenFormIDs) then
    SeenFormIDs.Free;
  if Assigned(ReportLines) then
    ReportLines.Free;
  Result := 0;
end;

end.
