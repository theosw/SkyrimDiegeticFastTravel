unit DNT_InventoryApparitionTravel;

uses SysUtils, Classes;

var
  SourceFile, PatchFile: IInterface;
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

procedure DumpElement(Element: IInterface; Depth: Integer);
var
  i: Integer;
  Prefix: string;
begin
  if not Assigned(Element) then
    Exit;
  Prefix := StringOfChar(' ', Depth * 2);
  if (ElementCount(Element) = 0) or (Depth >= 12) then begin
    ReportLines.Add(Prefix + Name(Element) + ' = ' + GetEditValue(Element));
    Exit;
  end;
  ReportLines.Add(Prefix + Name(Element));
  for i := 0 to Pred(ElementCount(Element)) do
    DumpElement(ElementByIndex(Element, i), Succ(Depth));
end;

function ContainsApparitionTravel(RecordElement: IInterface): Boolean;
var
  SearchText: string;
begin
  SearchText := LowerCase(
    GetElementEditValues(RecordElement, 'EDID') + '|' +
    GetElementEditValues(RecordElement, 'FULL') + '|' +
    GetElementEditValues(RecordElement, 'DESC')
  );
  Result := Pos('apparition', SearchText) > 0;
end;

procedure DumpMatchingRecords(PluginFile: IInterface; const LabelName: string);
var
  RecordElement: IInterface;
  i: Integer;
begin
  if not Assigned(PluginFile) then
    Exit;
  for i := 0 to Pred(RecordCount(PluginFile)) do begin
    RecordElement := RecordByIndex(PluginFile, i);
    if ContainsApparitionTravel(RecordElement) then begin
      ReportLines.Add('');
      ReportLines.Add(
        '[' + LabelName + '] form=' + IntToHex(FixedFormID(RecordElement), 8) +
        ' signature=' + Signature(RecordElement) +
        ' edid=' + GetElementEditValues(RecordElement, 'EDID') +
        ' name=' + GetElementEditValues(RecordElement, 'FULL') +
        ' origin=' + GetFileName(GetFile(RecordElement))
      );
      DumpElement(RecordElement, 1);
    end;
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\apparition-travel-inventory.status';
  ErrorPath := ScriptsPath + '..\..\build\apparition-travel-inventory.error';
  ReportPath := ScriptsPath + '..\..\build\apparition-travel-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    SourceFile := FileByPluginName('WizardingTraversal.esl');
    PatchFile := FileByPluginName(
      'Requiem - Wizarding Traversal - Magic Redone Patch.esp'
    );
    if not Assigned(SourceFile) then
      raise Exception.Create('WizardingTraversal.esl is not loaded');
    DumpMatchingRecords(SourceFile, 'SOURCE_RECORD');
    DumpMatchingRecords(PatchFile, 'PATCH_RECORD');
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
