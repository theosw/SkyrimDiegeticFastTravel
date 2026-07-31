{
  Read-only structural dump of the Court Wizard Teleport Services learning
  source. The wrapper loads a staged copy with its masters and captures these
  AddMessage lines in xEdit's report log.
}
unit DNT_AuditCourtWizardTeleportServices;

const
  TargetPluginName = 'CourtWizardTeleportServices.esp';
  MaxDumpDepth = 12;

var
  TargetFile: IInterface;

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
    AddMessage(Prefix + Name(Element) + ' = ' + Value);
    Exit;
  end;

  AddMessage(Prefix + Name(Element));
  for i := 0 to Pred(ChildCount) do
    DumpElement(ElementByIndex(Element, i), Succ(Depth));
end;

function Initialize: Integer;
var
  RecordElement: IInterface;
  i: Integer;
begin
  Result := 1;
  TargetFile := FileByPluginName(TargetPluginName);
  if not Assigned(TargetFile) then
    raise Exception.Create(TargetPluginName + ' is not loaded');

  AddMessage('[DNT_AUDIT] plugin=' + GetFileName(TargetFile));
  AddMessage(
    '[DNT_AUDIT] masters=' + IntToStr(MasterCount(TargetFile)) +
    ' records=' + IntToStr(RecordCount(TargetFile))
  );

  for i := 0 to Pred(RecordCount(TargetFile)) do begin
    RecordElement := RecordByIndex(TargetFile, i);
    AddMessage('');
    AddMessage(
      '[DNT_AUDIT] record=' + IntToHex(FormID(RecordElement), 8) +
      ' signature=' + Signature(RecordElement) +
      ' editorid=' + GetElementEditValues(RecordElement, 'EDID')
    );
    DumpElement(RecordElement, 1);
  end;

  AddMessage('[DNT_AUDIT] complete');
end;

function Finalize: Integer;
begin
  Result := 0;
end;

end.
