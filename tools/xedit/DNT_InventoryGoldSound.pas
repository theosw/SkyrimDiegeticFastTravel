unit DNT_InventoryGoldSound;

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

function Initialize: Integer;
var
  Candidate, Winner: IInterface;
  i: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\gold-sound.status';
  ErrorPath := ScriptsPath + '..\..\build\gold-sound.error';
  ReportPath := ScriptsPath + '..\..\build\gold-sound.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    for i := 0 to Pred(RecordCount(SkyrimFile)) do begin
      Candidate := RecordByIndex(SkyrimFile, i);
      if GetElementEditValues(Candidate, 'EDID') <> 'ITMGoldDown' then
        Continue;
      Winner := WinningOverride(Candidate);
      if not Assigned(Winner) then
        Winner := Candidate;
      ReportLines.Add(
        IntToHex(GetLoadOrderFormID(Candidate), 8) +
        ' | signature=' + Signature(Candidate) +
        ' | edid=' + GetElementEditValues(Candidate, 'EDID') +
        ' | origin=' + GetFileName(GetFile(MasterOrSelf(Candidate))) +
        ' | winner=' + GetFileName(GetFile(Winner))
      );
      Break;
    end;

    if ReportLines.Count <> 1 then
      raise Exception.Create('ITMGoldDown was not found exactly once');
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
