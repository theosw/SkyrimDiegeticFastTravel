{
  Read-only, exact-record audit for the College-centred wizard-guide star.
  It intentionally reports only the five visible travel/menu INFOs needed by
  the current gameplay milestone.
}
unit DNT_AuditWizardGuideStar;

const
  TargetPluginName = 'DiegeticTravelWizardGuides.esp';
  OnBeginFragmentMask = $01;
  DirectResponseFlagsMask = $0A01;
  HubResponseFlagsMask = $0A00;

var
  TargetFile: IInterface;
  StatusPath, ErrorPath, ReportPath: string;
  ReportLines: TStringList;

procedure WriteTextFile(const Path, TextValue: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add(TextValue);
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

function DefinedRecordByObjectID(ObjectID: Cardinal): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(TargetFile) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(
    TargetFile,
    FileFormID
  );
  Result := RecordByFormID(TargetFile, LoadOrderFormID, True);
end;

function RequireRecord(
  ObjectID: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(ObjectID);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve object ID ' + IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      'Object ID ' + IntToHex(ObjectID, 6) + ' has EditorID "' +
      GetElementEditValues(Result, 'EDID') + '", expected "' +
      ExpectedEditorID + '"'
    );
end;

procedure AssertOwnedResponse(
  InfoRecord: IInterface;
  const EditorID, ExpectedText: string
);
var
  Responses: IInterface;
begin
  if Assigned(ElementByPath(InfoRecord, 'DNAM')) then
    raise Exception.Create(EditorID + ' still uses Shared Info');
  Responses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(Responses) or (ElementCount(Responses) <> 1) then
    raise Exception.Create(EditorID + ' must own exactly one response');
  if GetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM1'
  ) <> ExpectedText then
    raise Exception.Create(EditorID + ' response text does not match');
end;

procedure AssertSpeaker(
  InfoRecord: IInterface;
  const EditorID: string;
  ExpectedFormID: Cardinal
);
var
  Speaker: IInterface;
begin
  Speaker := LinksTo(ElementByPath(InfoRecord, 'ANAM'));
  if not Assigned(Speaker) or (FormID(Speaker) <> ExpectedFormID) then
    raise Exception.Create(EditorID + ' speaker does not match');
end;

procedure AssertTravelFragment(
  InfoRecord: IInterface;
  const EditorID, ExpectedDestinationID: string
);
var
  VMAD, Scripts, ScriptEntry, Properties, PropertyEntry: IInterface;
  PropertyName: string;
  FoundDestination, FoundService: Boolean;
  i: Integer;
begin
  VMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(VMAD) then
    raise Exception.Create(EditorID + ' has no VMAD');
  if GetElementNativeValues(
    VMAD,
    'Script Fragments\Flags'
  ) <> OnBeginFragmentMask then
    raise Exception.Create(EditorID + ' fragment is not OnBegin');
  if GetElementEditValues(
    VMAD,
    'Script Fragments\FileName'
  ) <> 'DNT_WizardTravelFragment' then
    raise Exception.Create(EditorID + ' fragment filename does not match');

  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create(EditorID + ' must bind one fragment script');
  ScriptEntry := ElementByIndex(Scripts, 0);
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    raise Exception.Create(EditorID + ' fragment has no properties');

  FoundDestination := False;
  FoundService := False;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyEntry := ElementByIndex(Properties, i);
    PropertyName := GetElementEditValues(PropertyEntry, 'propertyName');
    if PropertyName = 'DestinationId' then begin
      if GetElementEditValues(PropertyEntry, 'String') <>
        ExpectedDestinationID then
        raise Exception.Create(
          EditorID + ' DestinationId is not ' + ExpectedDestinationID
        );
      FoundDestination := True;
    end else if PropertyName = 'Service' then begin
      if not Assigned(
        LinksTo(
          ElementByPath(
            PropertyEntry,
            'Value\Object Union\Object v2\FormID'
          )
        )
      ) then
        raise Exception.Create(EditorID + ' Service property is null');
      FoundService := True;
    end;
  end;
  if not FoundDestination then
    raise Exception.Create(EditorID + ' DestinationId is missing');
  if not FoundService then
    raise Exception.Create(EditorID + ' Service is missing');
end;

procedure AuditDirect(
  ObjectID: Cardinal;
  const EditorID, PromptText, ResponseText, DestinationID: string;
  SpeakerFormID: Cardinal
);
var
  InfoRecord, Links: IInterface;
begin
  InfoRecord := RequireRecord(ObjectID, 'INFO', EditorID);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(EditorID + ' prompt does not match');
  AssertOwnedResponse(InfoRecord, EditorID, ResponseText);
  AssertSpeaker(InfoRecord, EditorID, SpeakerFormID);
  if GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  ) <> DirectResponseFlagsMask then
    raise Exception.Create(EditorID + ' direct response flags do not match');
  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) and (ElementCount(Links) > 0) then
    raise Exception.Create(EditorID + ' unexpectedly has Link To entries');
  AssertTravelFragment(InfoRecord, EditorID, DestinationID);
  ReportLines.Add(
    'PASS direct ' + EditorID + ' -> ' + DestinationID
  );
end;

procedure AuditHub;
var
  HubInfo, Links, FirstTarget, SecondTarget, WhiterunTopic,
    RiftenTopic: IInterface;
begin
  HubInfo := RequireRecord($000808, 'INFO', 'DNT_WG_Request_Phinis');
  WhiterunTopic := RequireRecord(
    $000803,
    'DIAL',
    'DNT_WG_ToWhiterun'
  );
  RiftenTopic := RequireRecord($000804, 'DIAL', 'DNT_WG_ToRiften');

  if GetElementEditValues(HubInfo, 'RNAM') <>
    'Can you teleport me somewhere? (250 gold per trip)' then
    raise Exception.Create('Phinis hub prompt does not match');
  AssertOwnedResponse(
    HubInfo,
    'DNT_WG_Request_Phinis',
    'Where do you need to go?'
  );
  AssertSpeaker(
    HubInfo,
    'DNT_WG_Request_Phinis',
    $0001C199
  );
  if GetElementNativeValues(
    HubInfo,
    'ENAM\Response Flags'
  ) <> HubResponseFlagsMask then
    raise Exception.Create('Phinis hub response flags do not match');
  if Assigned(ElementByPath(HubInfo, 'VMAD')) then
    raise Exception.Create('Phinis hub unexpectedly has a travel VMAD');

  Links := ElementByPath(HubInfo, 'Link To');
  if not Assigned(Links) or (ElementCount(Links) <> 2) then
    raise Exception.Create('Phinis hub must have exactly two Link To entries');
  FirstTarget := LinksTo(ElementByIndex(Links, 0));
  SecondTarget := LinksTo(ElementByIndex(Links, 1));
  if not Assigned(FirstTarget) or
    (FormID(FirstTarget) <> FormID(WhiterunTopic)) then
    raise Exception.Create('Phinis first hub target is not Whiterun');
  if not Assigned(SecondTarget) or
    (FormID(SecondTarget) <> FormID(RiftenTopic)) then
    raise Exception.Create('Phinis second hub target is not Riften');

  ReportLines.Add('PASS hub DNT_WG_Request_Phinis -> whiterun,riften');
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\wizard-guide-audit.status';
  ErrorPath :=
    ScriptsPath + '..\..\build\wizard-guide-audit.error';
  ReportPath :=
    ScriptsPath + '..\..\build\wizard-guide-audit.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    TargetFile := FileByPluginName(TargetPluginName);
    if not Assigned(TargetFile) then
      raise Exception.Create(TargetPluginName + ' is not loaded');

    AuditDirect(
      $000806,
      'DNT_WG_Request_Farengar',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Very well. The College, then.',
      'college',
      $00013BBB
    );
    AuditDirect(
      $000807,
      'DNT_WG_Request_Wylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'The College? Very well.',
      'college',
      $00019DEF
    );
    AuditHub;
    AuditDirect(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      'Send me to Whiterun. (250 gold)',
      'Very well. Whiterun, then.',
      'whiterun',
      $0001C199
    );
    AuditDirect(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      'Send me to Riften. (250 gold)',
      'Very well. Riften, then.',
      'riften',
      $0001C199
    );

    ReportLines.Add('PASS wizard-guide star audit complete');
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
