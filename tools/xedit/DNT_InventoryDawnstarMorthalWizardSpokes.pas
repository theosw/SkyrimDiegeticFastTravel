unit DNT_InventoryDawnstarMorthalWizardSpokes;

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
  if (ExpectedEditorID <> '') and
    (GetElementEditValues(Result, 'EDID') <> ExpectedEditorID) then
    raise Exception.Create(
      IntToHex(FormIDValue, 8) + ' is not ' + ExpectedEditorID +
      '; actual=' + GetElementEditValues(Result, 'EDID')
    );
end;

procedure ReportNpc(NpcRecord: IInterface; const LabelText: string);
var
  WinnerRecord, VoiceRecord: IInterface;
begin
  WinnerRecord := WinningOverride(NpcRecord);
  if not Assigned(WinnerRecord) then
    WinnerRecord := NpcRecord;
  VoiceRecord := LinksTo(ElementByPath(WinnerRecord, 'VTCK'));
  if not Assigned(VoiceRecord) then
    raise Exception.Create(LabelText + ' has no voice type');
  ReportLines.Add(
    'NPC=' + FormHex(NpcRecord) +
    ' | ' + LabelText +
    ' | edid=' + GetElementEditValues(NpcRecord, 'EDID') +
    ' | voice=' + GetElementEditValues(VoiceRecord, 'EDID') +
    ' | voice_form=' + FormHex(VoiceRecord) +
    ' | winner=' + GetFileName(GetFile(WinnerRecord))
  );
end;

function ContainingCell(ReferenceRecord: IInterface): IInterface;
begin
  Result := GetContainer(ReferenceRecord);
  while Assigned(Result) and (Signature(Result) <> 'CELL') do
    Result := GetContainer(Result);
end;

procedure ReportReference(ReferenceRecord: IInterface; const LabelText: string);
var
  WinnerRecord, BaseRecord, CellRecord: IInterface;
  CellText, PositionText, WinnerText: string;
begin
  WinnerRecord := WinningOverride(ReferenceRecord);
  if not Assigned(WinnerRecord) then
    WinnerRecord := ReferenceRecord;
  BaseRecord := LinksTo(ElementByPath(WinnerRecord, 'NAME'));
  CellRecord := ContainingCell(WinnerRecord);
  if Assigned(CellRecord) then
    CellText := GetElementEditValues(CellRecord, 'EDID') + ' ' +
      FormHex(CellRecord)
  else
    CellText := '<unresolved cell>';
  PositionText :=
    GetElementEditValues(WinnerRecord, 'DATA\Position\X') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Y') + ',' +
    GetElementEditValues(WinnerRecord, 'DATA\Position\Z');
  WinnerText := GetFileName(GetFile(WinnerRecord));
  ReportLines.Add(
    FormHex(ReferenceRecord) + ' | ' + LabelText +
    ' | edid=' + GetElementEditValues(ReferenceRecord, 'EDID') +
    ' | base=' + GetElementEditValues(BaseRecord, 'EDID') +
    ' | cell=' + CellText +
    ' | position=' + PositionText +
    ' | winner=' + WinnerText +
    ' | flags=' + GetElementEditValues(
      WinnerRecord,
      'Record Header\Record Flags'
    )
  );
end;

procedure ReportNamedCandidatesInLoadedFiles;
var
  PluginFile, Candidate, WinnerRecord, BaseRecord: IInterface;
  PluginName, EditorIDText, BaseEditorIDText, SearchText: string;
  IsMorthalFile, IsRelevant: Boolean;
  FileIndex, RecordIndex: Integer;
begin
  ReportLines.Add('LOADED MORTHAL/FALION NAMED CANDIDATES:');
  for FileIndex := 0 to Pred(FileCount) do begin
    PluginFile := FileByIndex(FileIndex);
    PluginName := LowerCase(GetFileName(PluginFile));
    IsMorthalFile :=
      (Pos('morthal', PluginName) > 0) or
      (PluginName = 'cfto.esp');
    if not IsMorthalFile then
      Continue;

    for RecordIndex := 0 to Pred(RecordCount(PluginFile)) do begin
      Candidate := RecordByIndex(PluginFile, RecordIndex);
      if (Signature(Candidate) <> 'REFR') and
        (Signature(Candidate) <> 'ACHR') then
        Continue;
      BaseRecord := LinksTo(ElementByPath(Candidate, 'NAME'));
      EditorIDText := LowerCase(GetElementEditValues(Candidate, 'EDID'));
      BaseEditorIDText := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
      SearchText := EditorIDText + ' ' + BaseEditorIDText;
      IsRelevant :=
        (Pos('falion', SearchText) > 0) or
        (Pos('morthal', EditorIDText) > 0) or
        (Pos('carriage', EditorIDText) > 0) or
        (Pos('travel', EditorIDText) > 0) or
        (Pos('arrival', EditorIDText) > 0) or
        (Pos('destination', EditorIDText) > 0);
      if not IsRelevant then
        Continue;

      WinnerRecord := WinningOverride(Candidate);
      if not Assigned(WinnerRecord) then
        WinnerRecord := Candidate;
      if GetFileName(GetFile(WinnerRecord)) <> GetFileName(PluginFile) then
        Continue;
      ReportReference(WinnerRecord, 'loaded named candidate');
    end;
  end;
end;

procedure ReportCellMarkers(CellRecord: IInterface; const CellLabel: string);
var
  GroupRecord, ReferenceRecord, BaseRecord: IInterface;
  BaseEditorID: string;
  GroupType, i: Integer;
begin
  if not Assigned(CellRecord) then
    raise Exception.Create(CellLabel + ' actor reference has no containing cell');
  ReportLines.Add(
    'CELL MARKERS ' + CellLabel +
    ' edid=' + GetElementEditValues(CellRecord, 'EDID') +
    ' form=' + FormHex(CellRecord) + ':'
  );
  for GroupType := 8 to 9 do begin
    GroupRecord := FindChildGroup(ChildGroup(CellRecord), GroupType, CellRecord);
    if not Assigned(GroupRecord) then
      Continue;
    for i := 0 to Pred(ElementCount(GroupRecord)) do begin
      ReferenceRecord := ElementByIndex(GroupRecord, i);
      if (Signature(ReferenceRecord) <> 'REFR') and
        (Signature(ReferenceRecord) <> 'ACHR') then
        Continue;
      BaseRecord := LinksTo(ElementByPath(ReferenceRecord, 'NAME'));
      BaseEditorID := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
      if (Pos('marker', BaseEditorID) > 0) or
        (Pos('xmarker', BaseEditorID) > 0) or
        (Pos('madena', LowerCase(GetElementEditValues(
          ReferenceRecord,
          'EDID'
        ))) > 0) or
        (Pos('falion', LowerCase(GetElementEditValues(
          ReferenceRecord,
          'EDID'
        ))) > 0) then
        ReportReference(ReferenceRecord, CellLabel);
    end;
  end;
end;

procedure ReportCellsContaining(const SearchTerm, LabelText: string);
var
  CellGroup, CellRecord: IInterface;
  EditorIDText: string;
  MatchCount, i: Integer;
begin
  CellGroup := GroupBySignature(SkyrimFile, 'CELL');
  if not Assigned(CellGroup) then
    raise Exception.Create('Skyrim.esm has no CELL group');
  MatchCount := 0;
  for i := 0 to Pred(ElementCount(CellGroup)) do begin
    CellRecord := ElementByIndex(CellGroup, i);
    EditorIDText := GetElementEditValues(CellRecord, 'EDID');
    if Pos(LowerCase(SearchTerm), LowerCase(EditorIDText)) = 0 then
      Continue;
    Inc(MatchCount);
    ReportCellMarkers(CellRecord, LabelText + ' ' + EditorIDText);
  end;
  if MatchCount = 0 then
    ReportLines.Add('NO INTERIOR CELL MATCH FOR ' + SearchTerm);
end;

procedure ReportRelevantReferences;
var
  Candidate, BaseRecord: IInterface;
  EditorIDText, BaseEditorIDText, SearchText: string;
  IsRelevant: Boolean;
  i: Integer;
begin
  ReportLines.Add('RELEVANT NAMED REFERENCES:');
  for i := 0 to Pred(RecordCount(SkyrimFile)) do begin
    Candidate := RecordByIndex(SkyrimFile, i);
    if (Signature(Candidate) <> 'REFR') and
      (Signature(Candidate) <> 'ACHR') then
      Continue;
    BaseRecord := LinksTo(ElementByPath(Candidate, 'NAME'));
    EditorIDText := LowerCase(GetElementEditValues(Candidate, 'EDID'));
    BaseEditorIDText := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
    SearchText := EditorIDText + ' ' + BaseEditorIDText;
    IsRelevant :=
      (Pos('madena', SearchText) > 0) or
      (Pos('falion', SearchText) > 0) or
      (EditorIDText = 'dawnstarmapmarkerref') or
      (EditorIDText = 'morthalmapmarkerref') or
      (
        ((Pos('dawnstar', EditorIDText) > 0) or
          (Pos('morthal', EditorIDText) > 0)) and
        ((Pos('wizard', SearchText) > 0) or
          (Pos('vendor', SearchText) > 0) or
          (Pos('mapmarker', SearchText) > 0))
      );
    if IsRelevant then
      ReportReference(Candidate, 'relevant named reference');
  end;
end;

function Initialize: Integer;
var
  Madena, Falion, MadenaRef, FalionRef: IInterface;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\dawnstar-morthal-wizard-spokes.status';
  ErrorPath := ScriptsPath + '..\..\build\dawnstar-morthal-wizard-spokes.error';
  ReportPath := ScriptsPath + '..\..\build\dawnstar-morthal-wizard-spokes.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    Madena := RequireSkyrimRecord($0001361D, 'NPC_', 'Madena');
    Falion := RequireSkyrimRecord($000135E9, 'NPC_', 'Falion');
    MadenaRef := RequireSkyrimRecord($0001A6C3, 'ACHR', '');
    FalionRef := RequireSkyrimRecord($0001AA5E, 'ACHR', '');
    ReportNpc(Madena, 'Madena');
    ReportNpc(Falion, 'Falion');
    ReportReference(MadenaRef, 'Madena actor');
    ReportReference(FalionRef, 'Falion actor');
    ReportCellsContaining('whitehall', 'Madena candidate');
    ReportCellsContaining('falion', 'Falion candidate');
    ReportRelevantReferences;
    ReportNamedCandidatesInLoadedFiles;

    ReportLines.SaveToFile(ReportPath);
    WriteTextFile(StatusPath, 'success');
  except
    on E: Exception do begin
      ReportLines.Add('ERROR=' + E.Message);
      ReportLines.SaveToFile(ReportPath);
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
