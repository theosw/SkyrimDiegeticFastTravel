unit DNT_ExportFwmfMeshJson;

uses SysUtils, Classes;

var
  StatusPath, ErrorPath, InputPath, OutputPath: string;

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

function Initialize: Integer;
var
  Nif: TwbNifFile;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\fwmf-transform\export.status';
  ErrorPath := ScriptsPath + '..\..\build\fwmf-transform\export.error';
  InputPath := ScriptsPath + '..\..\build\fwmf-transform\tamriel.nif';
  OutputPath := ScriptsPath + '..\..\build\fwmf-transform\tamriel.json';

  try
    if not FileExists(InputPath) then
      raise Exception.Create('Staged FWMF mesh not found: ' + InputPath);

    Nif := TwbNifFile.Create;
    try
      Nif.LoadFromFile(InputPath);
      Nif.SaveToJsonFile(OutputPath, False);
    finally
      Nif.Free;
    end;

    WriteTextFile(StatusPath, 'success');
  except
    on E: Exception do begin
      WriteTextFile(ErrorPath, E.Message);
      WriteTextFile(StatusPath, 'failed');
    end;
  end;
end;

end.
