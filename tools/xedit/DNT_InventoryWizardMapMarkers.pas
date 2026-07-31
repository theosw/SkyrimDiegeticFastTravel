unit DNT_InventoryWizardMapMarkers;

uses SysUtils, Classes;

var
  BCDFile: IInterface;
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

function FindRecordByEditorID(
  PluginFile: IInterface;
  const RecordSignature, EditorIDValue: string
): IInterface;
var
  RecordGroup, Candidate: IInterface;
  i: Integer;
begin
  Result := nil;
  RecordGroup := GroupBySignature(PluginFile, RecordSignature);
  if not Assigned(RecordGroup) then
    Exit;
  for i := 0 to Pred(ElementCount(RecordGroup)) do begin
    Candidate := ElementByIndex(RecordGroup, i);
    if GetElementEditValues(Candidate, 'EDID') = EditorIDValue then begin
      Result := Candidate;
      Exit;
    end;
  end;
end;

procedure ReportFormList(const EditorIDValue: string);
var
  ListRecord, Entries, Entry, LinkedRecord, WinnerRecord: IInterface;
  i: Integer;
begin
  ListRecord := FindRecordByEditorID(BCDFile, 'FLST', EditorIDValue);
  if not Assigned(ListRecord) then
    raise Exception.Create('Could not find FLST ' + EditorIDValue);
  Entries := ElementByPath(ListRecord, 'FormIDs');
  if not Assigned(Entries) then
    raise Exception.Create(EditorIDValue + ' has no FormIDs');

  ReportLines.Add('[' + EditorIDValue + ']');
  for i := 0 to Pred(ElementCount(Entries)) do begin
    Entry := ElementByIndex(Entries, i);
    LinkedRecord := LinksTo(Entry);
    if not Assigned(LinkedRecord) then begin
      ReportLines.Add(IntToStr(i) + ' | <unresolved> | ' + GetEditValue(Entry));
      Continue;
    end;
    WinnerRecord := WinningOverride(LinkedRecord);
    if not Assigned(WinnerRecord) then
      WinnerRecord := LinkedRecord;
    ReportLines.Add(
      IntToStr(i) +
      ' | ' + IntToHex(GetLoadOrderFormID(LinkedRecord), 8) +
      ' | ' + Signature(LinkedRecord) +
      ' | edid=' + GetElementEditValues(LinkedRecord, 'EDID') +
      ' | name=' + Name(LinkedRecord) +
      ' | origin=' + GetFileName(GetFile(LinkedRecord)) +
      ' | winner=' + GetFileName(GetFile(WinnerRecord))
    );
  end;
  ReportLines.Add('');
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\wizard-map-markers.status';
  ErrorPath := ScriptsPath + '..\..\build\wizard-map-markers.error';
  ReportPath := ScriptsPath + '..\..\build\wizard-map-markers.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    BCDFile := FileByPluginName('Better Carriage Destinations.esp');
    if not Assigned(BCDFile) then
      raise Exception.Create('Better Carriage Destinations.esp is not loaded');

    ReportFormList('BCD_CarriageLocationsList');
    ReportFormList('BCD_AutoUnlockMarkers');
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
