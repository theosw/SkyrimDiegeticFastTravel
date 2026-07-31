{
  Build the first College-centred wizard-guide slice:

    Farengar Secret-Fire -> College of Winterhold
    Phinis Gestor        -> Whiterun

  Each top-level INFO owns its response text, closes the dialogue, and runs the
  travel fragment on begin. This avoids Shared Info voice-data inheritance and
  avoids depending on a second dialogue menu for the first end-to-end test.

  The existing destination INFOs remain as fragment donors and as scaffolding
  for the later College destination menu. The script operates on a staged
  DiegeticTravelWizardGuides.esp and writes a separate verified output file.
}
unit DNT_FixWizardRootInfo;

const
  OnBeginFragmentMask = $01;
  DirectResponseFlagsMask = $0A01; { Goodbye + Force Subtitle + No LIP File }

var
  TargetFile: IInterface;
  StatusPath, OutputPath: string;

procedure WriteStatus(const Status: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add(Status);
    Lines.SaveToFile(StatusPath);
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

function DefinedRecordByObjectID(
  FileElement: IInterface;
  ObjectID: Cardinal
): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(FileElement) shl 24) or (ObjectID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(
    FileElement,
    FileFormID
  );
  Result := RecordByFormID(FileElement, LoadOrderFormID, True);
end;

function RequireInfo(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(TargetFile, ObjectID);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve INFO object ID ' + IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> 'INFO' then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected INFO'
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      'Object ID ' + IntToHex(ObjectID, 6) + ' has EditorID "' +
      GetElementEditValues(Result, 'EDID') + '", expected "' +
      ExpectedEditorID + '"'
    );
end;

procedure ConfigureOwnedResponse(
  InfoRecord: IInterface;
  const ExpectedEditorID, ResponseText: string;
  ResponseTemplateFormID: Cardinal
);
var
  SkyrimFile, ResponseTemplate, SourceResponses, TargetResponses,
    ResponseRecord: IInterface;
begin
  SkyrimFile := FileByPluginName('Skyrim.esm');
  if not Assigned(SkyrimFile) then
    raise Exception.Create('Skyrim.esm is not loaded');

  ResponseTemplate := RecordByFormID(
    SkyrimFile,
    ResponseTemplateFormID,
    True
  );
  if not Assigned(ResponseTemplate) then
    raise Exception.Create(
      ExpectedEditorID + ' could not resolve response template ' +
      IntToHex(ResponseTemplateFormID, 8)
    );
  if Signature(ResponseTemplate) <> 'INFO' then
    raise Exception.Create(
      ExpectedEditorID + ' response template resolved to ' +
      Signature(ResponseTemplate) + ', expected INFO'
    );

  SourceResponses := ElementByPath(ResponseTemplate, 'Responses');
  if not Assigned(SourceResponses) or (ElementCount(SourceResponses) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' response template must own exactly one response'
    );

  if Assigned(ElementByPath(InfoRecord, 'DNAM')) then
    RemoveElement(InfoRecord, 'DNAM');
  if Assigned(ElementByPath(InfoRecord, 'Responses')) then
    RemoveElement(InfoRecord, 'Responses');

  Add(InfoRecord, 'Responses', True);
  TargetResponses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(TargetResponses) then
    raise Exception.Create(
      ExpectedEditorID + ' could not create owned Responses'
    );
  ElementAssign(TargetResponses, LowInteger, SourceResponses, False);

  SetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM1',
    ResponseText
  );
  SetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM2',
    ''
  );
  SetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM3',
    ''
  );
  SetElementNativeValues(
    InfoRecord,
    'Responses\Response\TRDT\Sound',
    0
  );
  SetElementNativeValues(
    InfoRecord,
    'Responses\Response\TRDT\Use Emotion Animation',
    0
  );

  ResponseRecord := ElementByPath(InfoRecord, 'Responses\Response');
  if not Assigned(ResponseRecord) then
    raise Exception.Create(
      ExpectedEditorID + ' owned response did not resolve'
    );
  if Assigned(ElementByPath(ResponseRecord, 'SNAM')) then
    RemoveElement(ResponseRecord, 'SNAM');
  if Assigned(ElementByPath(ResponseRecord, 'LNAM')) then
    RemoveElement(ResponseRecord, 'LNAM');

  if Assigned(ElementByPath(InfoRecord, 'DNAM')) then
    raise Exception.Create(
      ExpectedEditorID + ' still has Shared Info after conversion'
    );
  TargetResponses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(TargetResponses) or (ElementCount(TargetResponses) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' does not own exactly one response'
    );
  if GetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM1'
  ) <> ResponseText then
    raise Exception.Create(
      ExpectedEditorID + ' response text did not read back'
    );
end;

procedure ValidateFragmentProperties(
  InfoRecord: IInterface;
  const ExpectedEditorID, DestinationID: string
);
var
  TargetVMAD, Scripts, ScriptEntry, Properties, PropertyEntry,
    PropertyObject: IInterface;
  PropertyName: string;
  FoundService, FoundDestination: Boolean;
  i: Integer;
begin
  TargetVMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create(ExpectedEditorID + ' has no VMAD');
  if GetElementEditValues(
    TargetVMAD,
    'Script Fragments\FileName'
  ) <> 'DNT_WizardTravelFragment' then
    raise Exception.Create(
      ExpectedEditorID + ' fragment filename did not read back'
    );
  if GetElementNativeValues(
    TargetVMAD,
    'Script Fragments\Flags'
  ) <> OnBeginFragmentMask then
    raise Exception.Create(
      ExpectedEditorID + ' fragment is not wired to OnBegin'
    );

  Scripts := ElementByPath(TargetVMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' VMAD does not have exactly one script'
    );
  ScriptEntry := ElementByIndex(Scripts, 0);
  if GetElementEditValues(ScriptEntry, 'ScriptName') <>
    'DNT_WizardTravelFragment' then
    raise Exception.Create(
      ExpectedEditorID + ' fragment script name did not read back'
    );

  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) or (ElementCount(Properties) <> 2) then
    raise Exception.Create(
      ExpectedEditorID + ' fragment does not have two properties'
    );

  FoundService := False;
  FoundDestination := False;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyEntry := ElementByIndex(Properties, i);
    PropertyName := GetElementEditValues(PropertyEntry, 'propertyName');
    if PropertyName = 'Service' then begin
      PropertyObject := LinksTo(
        ElementByPath(
          PropertyEntry,
          'Value\Object Union\Object v2\FormID'
        )
      );
      if not Assigned(PropertyObject) then
        raise Exception.Create(
          ExpectedEditorID + ' Service property is null'
        );
      FoundService := True;
    end else if PropertyName = 'DestinationId' then begin
      if GetElementEditValues(PropertyEntry, 'String') <> DestinationID then
        raise Exception.Create(
          ExpectedEditorID + ' DestinationId is not ' + DestinationID
        );
      FoundDestination := True;
    end;
  end;

  if not FoundService then
    raise Exception.Create(
      ExpectedEditorID + ' Service property is missing'
    );
  if not FoundDestination then
    raise Exception.Create(
      ExpectedEditorID + ' DestinationId property is missing'
    );
end;

procedure ConfigureDirectRoute(
  RootObjectID: Cardinal;
  const RootEditorID: string;
  DestinationObjectID: Cardinal;
  const DestinationEditorID, PromptText, ResponseText, DestinationID: string;
  ResponseTemplateFormID: Cardinal
);
var
  RootInfo, DestinationInfo, SourceVMAD, TargetVMAD, Links: IInterface;
  ReadBackFlags: Cardinal;
begin
  RootInfo := RequireInfo(RootObjectID, RootEditorID);
  DestinationInfo := RequireInfo(
    DestinationObjectID,
    DestinationEditorID
  );

  SetElementEditValues(RootInfo, 'RNAM', PromptText);
  if GetElementEditValues(RootInfo, 'RNAM') <> PromptText then
    raise Exception.Create(
      RootEditorID + ' direct-route prompt did not read back'
    );

  Links := ElementByPath(RootInfo, 'Link To');
  if Assigned(Links) then
    RemoveElement(RootInfo, 'Link To');
  Links := ElementByPath(RootInfo, 'Link To');
  if Assigned(Links) and (ElementCount(Links) > 0) then
    raise Exception.Create(
      RootEditorID + ' direct route still has Link To entries'
    );

  ConfigureOwnedResponse(
    RootInfo,
    RootEditorID,
    ResponseText,
    ResponseTemplateFormID
  );

  SetElementNativeValues(
    RootInfo,
    'ENAM\Response Flags',
    DirectResponseFlagsMask
  );
  ReadBackFlags := GetElementNativeValues(
    RootInfo,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> DirectResponseFlagsMask then
    raise Exception.Create(
      RootEditorID + ' response flags did not read back'
    );

  SourceVMAD := ElementByPath(DestinationInfo, 'VMAD');
  if not Assigned(SourceVMAD) then
    raise Exception.Create(
      DestinationEditorID + ' has no travel fragment VMAD'
    );
  if Assigned(ElementByPath(RootInfo, 'VMAD')) then
    RemoveElement(RootInfo, 'VMAD');
  Add(RootInfo, 'VMAD', True);
  TargetVMAD := ElementByPath(RootInfo, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create(
      RootEditorID + ' could not create direct-route VMAD'
    );
  ElementAssign(TargetVMAD, LowInteger, SourceVMAD, False);
  TargetVMAD := ElementByPath(RootInfo, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create(
      RootEditorID + ' VMAD disappeared after assignment'
    );

  SetElementNativeValues(
    TargetVMAD,
    'Script Fragments\Flags',
    OnBeginFragmentMask
  );
  ValidateFragmentProperties(
    RootInfo,
    RootEditorID,
    DestinationID
  );

  AddMessage(
    '[DNT] ' + RootEditorID + ' -> ' + DestinationID +
    '; owned response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure SavePatchedPlugin;
var
  OutputStream: TFileStream;
begin
  OutputStream := TFileStream.Create(OutputPath, fmCreate);
  try
    FileWriteToStream(TargetFile, OutputStream, False);
  finally
    OutputStream.Free;
  end;
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\wizard-guide-fix.status';
  OutputPath :=
    ScriptsPath + '..\..\build\wizard-guide-fix\' +
    'DiegeticTravelWizardGuides.esp';
  WriteStatus('running');

  try
    TargetFile := FileByPluginName('DiegeticTravelWizardGuides.esp');
    if not Assigned(TargetFile) then
      raise Exception.Create(
        'DiegeticTravelWizardGuides.esp is not loaded'
      );

    ConfigureDirectRoute(
      $000806,
      'DNT_WG_Request_Farengar',
      $000809,
      'DNT_WG_College_FromFarengar',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Very well. The College, then.',
      'college',
      $000904FF
    );
    ConfigureDirectRoute(
      $000808,
      'DNT_WG_Request_Phinis',
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      'Can you teleport me to Whiterun? (250 gold)',
      'Very well. Whiterun, then.',
      'whiterun',
      $000C819B
    );

    SavePatchedPlugin;
    WriteStatus('success');
  except
    WriteStatus('failed');
    raise;
  end;
end;

function Finalize: Integer;
begin
  Result := 0;
end;

end.
