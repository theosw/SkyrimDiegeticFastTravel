unit DNT_InventoryMajorCityWizardSpokes;

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
    ' | winner=' + GetFileName(GetFile(WinnerRecord)) +
    ' | flags=' + GetElementEditValues(WinnerRecord, 'ACBS\Flags')
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

function ContainingCell(ReferenceRecord: IInterface): IInterface;
begin
  Result := GetContainer(ReferenceRecord);
  while Assigned(Result) and (Signature(Result) <> 'CELL') do
    Result := GetContainer(Result);
end;

procedure ReportActorReferences(
  BaseNpc: IInterface;
  const LabelText: string
);
var
  CandidateRecord, CandidateBase, CellRecord: IInterface;
  BaseFormID: Cardinal;
  CellText: string;
  i: Integer;
begin
  BaseFormID := GetLoadOrderFormID(BaseNpc);
  ReportLines.Add('REFERENCES FOR ' + LabelText + ':');
  for i := 0 to Pred(RecordCount(SkyrimFile)) do begin
    CandidateRecord := RecordByIndex(SkyrimFile, i);
    if Signature(CandidateRecord) <> 'ACHR' then
      Continue;
    CandidateBase := LinksTo(ElementByPath(CandidateRecord, 'NAME'));
    if not Assigned(CandidateBase) or
      (GetLoadOrderFormID(CandidateBase) <> BaseFormID) then
      Continue;
    CellRecord := ContainingCell(CandidateRecord);
    if Assigned(CellRecord) then
      CellText := GetElementEditValues(CellRecord, 'EDID')
    else
      CellText := '<unresolved cell>';
    ReportReference(CandidateRecord, LabelText + ' in ' + CellText);
  end;
end;

procedure ReportCellGroup(
  CellRecord: IInterface;
  GroupType: Integer;
  const GroupLabel: string;
  FirstNpcFormID, SecondNpcFormID: Cardinal
);
var
  ReferenceGroup, ReferenceRecord, BaseRecord: IInterface;
  BaseEditorID: string;
  BaseFormID: Cardinal;
  i: Integer;
begin
  ReferenceGroup := FindChildGroup(ChildGroup(CellRecord), GroupType, CellRecord);
  if not Assigned(ReferenceGroup) then
    Exit;

  for i := 0 to Pred(ElementCount(ReferenceGroup)) do begin
    ReferenceRecord := ElementByIndex(ReferenceGroup, i);
    if (Signature(ReferenceRecord) <> 'REFR') and
      (Signature(ReferenceRecord) <> 'ACHR') then
      Continue;
    BaseRecord := LinksTo(ElementByPath(ReferenceRecord, 'NAME'));
    if not Assigned(BaseRecord) then
      Continue;
    BaseFormID := GetLoadOrderFormID(BaseRecord);
    BaseEditorID := LowerCase(GetElementEditValues(BaseRecord, 'EDID'));
    if
      (BaseFormID = FirstNpcFormID) or
      (BaseFormID = SecondNpcFormID) or
      (Pos('marker', BaseEditorID) > 0) or
      (Pos('xmarker', BaseEditorID) > 0)
    then
      ReportReference(ReferenceRecord, GroupLabel);
  end;
end;

procedure ReportCell(
  CellRecord: IInterface;
  const LabelText: string;
  FirstNpcFormID, SecondNpcFormID: Cardinal
);
begin
  ReportLines.Add('');
  ReportLines.Add(
    'CELL=' + FormHex(CellRecord) +
    ' | ' + LabelText +
    ' | edid=' + GetElementEditValues(CellRecord, 'EDID') +
    ' | winner=' + GetFileName(GetFile(WinningOverride(CellRecord)))
  );
  ReportLines.Add('ACTOR AND MARKER REFERENCES:');
  ReportCellGroup(
    CellRecord,
    8,
    LabelText + ' Persistent',
    FirstNpcFormID,
    SecondNpcFormID
  );
  ReportCellGroup(
    CellRecord,
    9,
    LabelText + ' Temporary',
    FirstNpcFormID,
    SecondNpcFormID
  );
end;

function Initialize: Integer;
var
  Wuunferth, Calcelmo, WindhelmCell, MarkarthCell: IInterface;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\major-city-wizard-spokes.status';
  ErrorPath :=
    ScriptsPath + '..\..\build\major-city-wizard-spokes.error';
  ReportPath :=
    ScriptsPath + '..\..\build\major-city-wizard-spokes.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    Wuunferth := RequireSkyrimRecord($00014146, 'NPC_', 'Wuunferth');
    Calcelmo := RequireSkyrimRecord($0001338E, 'NPC_', 'Calcelmo');
    ReportNpc(Wuunferth, 'Wuunferth the Unliving');
    ReportNpc(Calcelmo, 'Calcelmo');
    ReportActorReferences(Wuunferth, 'Wuunferth the Unliving');
    ReportActorReferences(Calcelmo, 'Calcelmo');

    WindhelmCell := RequireSkyrimRecord(
      $00097299,
      'CELL',
      'WindhelmPalaceUpstairs01'
    );
    MarkarthCell := RequireSkyrimRecord(
      $00016DF2,
      'CELL',
      'MarkarthUnderStoneKeep'
    );
    ReportCell(
      WindhelmCell,
      'Windhelm',
      $00014146,
      $00000000
    );
    ReportCell(
      MarkarthCell,
      'Markarth',
      $0001338E,
      $00000000
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
