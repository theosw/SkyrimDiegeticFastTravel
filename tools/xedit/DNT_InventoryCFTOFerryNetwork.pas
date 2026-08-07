unit DNT_InventoryCFTOFerryNetwork;

uses SysUtils, Classes;

const
  MaxDumpDepth = 14;

var
  CftoFile, BcdFile, PatchFile: IInterface;
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
  const EditorIDValue: string
): IInterface;
var
  RecordElement: IInterface;
  i: Integer;
begin
  Result := nil;
  for i := 0 to Pred(RecordCount(PluginFile)) do begin
    RecordElement := RecordByIndex(PluginFile, i);
    if GetElementEditValues(RecordElement, 'EDID') = EditorIDValue then begin
      Result := RecordElement;
      Exit;
    end;
  end;
end;

procedure DumpElement(Element: IInterface; Depth: Integer);
var
  ChildCount, i: Integer;
  Prefix, Value: string;
begin
  if not Assigned(Element) then
    Exit;

  Prefix := StringOfChar(' ', Depth * 2);
  ChildCount := ElementCount(Element);
  if (ChildCount = 0) or (Depth >= MaxDumpDepth) then begin
    Value := GetEditValue(Element);
    ReportLines.Add(Prefix + Name(Element) + ' = ' + Value);
    Exit;
  end;

  ReportLines.Add(Prefix + Name(Element));
  for i := 0 to Pred(ChildCount) do
    DumpElement(ElementByIndex(Element, i), Succ(Depth));
end;

function RecordContainsFerryScript(RecordElement: IInterface): Boolean;
var
  Scripts, ScriptEntry: IInterface;
  i: Integer;
  ScriptName: string;
begin
  Result := False;
  Scripts := ElementByPath(RecordElement, 'VMAD\Scripts');
  if not Assigned(Scripts) then
    Exit;

  for i := 0 to Pred(ElementCount(Scripts)) do begin
    ScriptEntry := ElementByIndex(Scripts, i);
    ScriptName := LowerCase(GetElementEditValues(ScriptEntry, 'ScriptName'));
    if Pos('kmodferry', ScriptName) > 0 then begin
      Result := True;
      Exit;
    end;
  end;
end;

procedure DumpRecord(RecordElement: IInterface; const SectionName: string);
begin
  ReportLines.Add('');
  ReportLines.Add(
    '[' + SectionName + '] form=' +
    IntToHex(GetLoadOrderFormID(RecordElement), 8) +
    ' signature=' + Signature(RecordElement) +
    ' edid=' + GetElementEditValues(RecordElement, 'EDID') +
    ' name=' + Name(RecordElement) +
    ' origin=' + GetFileName(GetFile(RecordElement))
  );
  DumpElement(RecordElement, 1);
end;

procedure DumpPatchRecords;
var
  RecordElement: IInterface;
  i: Integer;
begin
  ReportLines.Add('[PATCH_SUMMARY] records=' + IntToStr(RecordCount(PatchFile)));
  for i := 0 to Pred(RecordCount(PatchFile)) do begin
    RecordElement := RecordByIndex(PatchFile, i);
    DumpRecord(RecordElement, 'PATCH_RECORD');
  end;
end;

procedure DumpCftoFerryInfos;
var
  RecordElement: IInterface;
  i, Count: Integer;
begin
  Count := 0;
  for i := 0 to Pred(RecordCount(CftoFile)) do begin
    RecordElement := RecordByIndex(CftoFile, i);
    if (Signature(RecordElement) = 'INFO') and
      RecordContainsFerryScript(RecordElement) then begin
      Inc(Count);
      DumpRecord(RecordElement, 'CFTO_FERRY_INFO');
    end;
  end;
  ReportLines.Insert(0, '[CFTO_FERRY_INFO_SUMMARY] records=' + IntToStr(Count));
end;

procedure DumpSupportingRecords;
var
  RecordElement: IInterface;
begin
  RecordElement := FindRecordByEditorID(BcdFile, 'BCD_FerryWhitelist');
  if not Assigned(RecordElement) then
    raise Exception.Create('BCD_FerryWhitelist was not found');
  DumpRecord(RecordElement, 'BASE_FERRY_ROUTE_1');

  RecordElement := FindRecordByEditorID(CftoFile, 'KmodFerryCost');
  if not Assigned(RecordElement) then
    raise Exception.Create('KmodFerryCost was not found');
  DumpRecord(RecordElement, 'CFTO_FERRY_COST');
end;

procedure ReportFerrymanRoutes;
var
  RecordElement, Factions, FactionEntry, FactionLink: IInterface;
  i, j: Integer;
  RouteText, FactionEditorID: string;
begin
  ReportLines.Add('');
  ReportLines.Add('[FERRYMAN_ROUTE_MEMBERSHIP]');
  for i := 0 to Pred(RecordCount(CftoFile)) do begin
    RecordElement := RecordByIndex(CftoFile, i);
    if Signature(RecordElement) <> 'NPC_' then
      Continue;
    Factions := ElementByPath(RecordElement, 'Factions');
    if not Assigned(Factions) then
      Continue;

    RouteText := '';
    for j := 0 to Pred(ElementCount(Factions)) do begin
      FactionEntry := ElementByIndex(Factions, j);
      FactionLink := LinksTo(ElementByPath(FactionEntry, 'Faction'));
      if not Assigned(FactionLink) then
        Continue;
      FactionEditorID := GetElementEditValues(FactionLink, 'EDID');
      if Pos('KmodFerryRoute', FactionEditorID) = 1 then begin
        if RouteText <> '' then
          RouteText := RouteText + ',';
        RouteText := RouteText + FactionEditorID;
      end;
    end;

    if RouteText <> '' then
      ReportLines.Add(
        GetElementEditValues(RecordElement, 'EDID') +
        ' | name=' + GetElementEditValues(RecordElement, 'FULL') +
        ' | routes=' + RouteText +
        ' | form=' + IntToHex(GetLoadOrderFormID(RecordElement), 8)
      );
  end;
end;

procedure ReportCftoFerryTopics;
var
  RecordElement, QuestLink, BranchLink: IInterface;
  i: Integer;
  EditorIDValue: string;
begin
  ReportLines.Add('');
  ReportLines.Add('[CFTO_FERRY_TOPICS]');
  for i := 0 to Pred(RecordCount(CftoFile)) do begin
    RecordElement := RecordByIndex(CftoFile, i);
    if Signature(RecordElement) <> 'DIAL' then
      Continue;
    EditorIDValue := GetElementEditValues(RecordElement, 'EDID');
    if Pos('Ferry', EditorIDValue) = 0 then
      Continue;
    QuestLink := LinksTo(ElementByPath(RecordElement, 'QNAM'));
    BranchLink := LinksTo(ElementByPath(RecordElement, 'BNAM'));
    ReportLines.Add(
      EditorIDValue +
      ' | prompt=' + GetElementEditValues(RecordElement, 'FULL') +
      ' | form=' + IntToHex(GetLoadOrderFormID(RecordElement), 8) +
      ' | quest=' + GetElementEditValues(QuestLink, 'EDID') +
      ' | branch=' + GetElementEditValues(BranchLink, 'EDID')
    );
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\cfto-ferry-network.status';
  ErrorPath := ScriptsPath + '..\..\build\cfto-ferry-network.error';
  ReportPath := ScriptsPath + '..\..\build\cfto-ferry-network.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    CftoFile := FileByPluginName('CFTO.esp');
    if not Assigned(CftoFile) then
      raise Exception.Create('CFTO.esp is not loaded');
    BcdFile := FileByPluginName('Better Carriage Destinations.esp');
    if not Assigned(BcdFile) then
      raise Exception.Create('Better Carriage Destinations.esp is not loaded');
    PatchFile := FileByPluginName('Better Carriage Destinations - CFTO.esp');
    if not Assigned(PatchFile) then
      raise Exception.Create('Better Carriage Destinations - CFTO.esp is not loaded');

    DumpCftoFerryInfos;
    DumpSupportingRecords;
    ReportFerrymanRoutes;
    ReportCftoFerryTopics;
    DumpPatchRecords;
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
