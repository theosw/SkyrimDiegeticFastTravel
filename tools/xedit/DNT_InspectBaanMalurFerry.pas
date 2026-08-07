{
  Read-only structural inventory of Journey to Baan Malur's sea-travel
  records. The report is intentionally generated from the installed plugin so
  later adapter work can preserve its provider gates and execution fragments.
}
unit DNT_InspectBaanMalurFerry;

const
  TargetPluginName = 'Journey to Baan Malur.esp';
  MaxDumpDepth = 14;

var
  TargetFile: IInterface;
  ReportLines: TStringList;
  StatusPath, ErrorPath, ReportPath: string;

procedure WriteTextFile(const PathValue, TextValue: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Text := TextValue;
    Lines.SaveToFile(PathValue);
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

function HasFerryEditorID(RecordElement: IInterface): Boolean;
var
  EditorIDValue, LowerEditorID: string;
begin
  EditorIDValue := GetElementEditValues(RecordElement, 'EDID');
  LowerEditorID := LowerCase(EditorIDValue);
  Result :=
    (EditorIDValue = 'RavenRockSailorCaptain') or
    (EditorIDValue = 'SOMRSailorCaptainFaction') or
    (Pos('somrferry', LowerEditorID) = 1) or
    (Pos('somrboattravel', LowerEditorID) = 1);
end;

function ParentDialogueEditorID(RecordElement: IInterface): string;
var
  ParentElement: IInterface;
begin
  Result := '';
  ParentElement := GetContainer(RecordElement);
  while Assigned(ParentElement) do begin
    if Signature(ParentElement) = 'DIAL' then begin
      Result := GetElementEditValues(ParentElement, 'EDID');
      Exit;
    end;
    ParentElement := GetContainer(ParentElement);
  end;
end;

procedure DumpRecord(RecordElement: IInterface; const ParentTopic: string);
begin
  ReportLines.Add('');
  ReportLines.Add(
    'RECORD fixed=' + IntToHex(FixedFormID(RecordElement), 8) +
    ' form=' + IntToHex(FormID(RecordElement), 8) +
    ' signature=' + Signature(RecordElement) +
    ' editorid=' + GetElementEditValues(RecordElement, 'EDID') +
    ' parentTopic=' + ParentTopic
  );
  DumpElement(RecordElement, 1);
end;

function DumpTopicInfos(TopicRecord: IInterface): Integer;
var
  InfoGroup, InfoRecord: IInterface;
  TopicEditorID: string;
  i: Integer;
begin
  Result := 0;
  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) then
    Exit;
  TopicEditorID := GetElementEditValues(TopicRecord, 'EDID');
  for i := 0 to Pred(ElementCount(InfoGroup)) do begin
    InfoRecord := ElementByIndex(InfoGroup, i);
    if Signature(InfoRecord) = 'INFO' then begin
      DumpRecord(InfoRecord, TopicEditorID);
      Inc(Result);
    end;
  end;
end;

function Initialize: Integer;
var
  RecordElement: IInterface;
  ParentTopic, LowerParentTopic: string;
  i, SelectedCount: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath + '..\..\build\baan-malur-ferry-inspect.status';
  ErrorPath := ScriptsPath + '..\..\build\baan-malur-ferry-inspect.error';
  ReportPath := ScriptsPath + '..\..\build\baan-malur-ferry-inspect.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  try
    TargetFile := FileByPluginName(TargetPluginName);
    if not Assigned(TargetFile) then
      raise Exception.Create(TargetPluginName + ' is not loaded');

    ReportLines.Add('PLUGIN=' + GetFileName(TargetFile));
    ReportLines.Add('MASTERS=' + IntToStr(MasterCount(TargetFile)));
    ReportLines.Add('RECORDS=' + IntToStr(RecordCount(TargetFile)));
    SelectedCount := 0;

    for i := 0 to Pred(RecordCount(TargetFile)) do begin
      RecordElement := RecordByIndex(TargetFile, i);
      ParentTopic := '';
      if Signature(RecordElement) = 'INFO' then
        ParentTopic := ParentDialogueEditorID(RecordElement);
      LowerParentTopic := LowerCase(ParentTopic);
      if HasFerryEditorID(RecordElement) or
        (Pos('somrferry', LowerParentTopic) = 1) or
        (Pos('somrboattravel', LowerParentTopic) = 1) then begin
        DumpRecord(RecordElement, ParentTopic);
        Inc(SelectedCount);
        if Signature(RecordElement) = 'DIAL' then
          SelectedCount := SelectedCount + DumpTopicInfos(RecordElement);
      end;
    end;

    ReportLines.Insert(3, 'SELECTED=' + IntToStr(SelectedCount));
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
