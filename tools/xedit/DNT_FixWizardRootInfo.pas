{
  Build the first College-centred wizard-guide star:

    Farengar Secret-Fire -> College of Winterhold
    Wylandriah           -> College of Winterhold
    Phinis Gestor        -> Whiterun or Riften

  Terminal travel INFOs deliberately share response data from short vanilla
  INFOs for which the speaker's exact voice type has shipped FUZ/LIP data.
  Court wizards use direct top-level routes to the College. Phinis's branching
  hub owns an unvoiced forced-subtitle response because gameplay proved that a
  cross-topic Shared Info donor speaks but suppresses the custom LinkTo
  transition. Each destination INFO closes the dialogue and runs its travel
  fragment on begin.

  The shared-response donor FormIDs are explicit and audited. The script
  operates on a staged DiegeticTravelWizardGuides.esp and writes a separate
  verified output file.
}
unit DNT_FixWizardRootInfo;

const
  OnBeginFragmentMask = $01;
  DirectResponseFlagsMask = $0001; { Goodbye }
  HubResponseFlagsMask = $0A00; { Force Subtitle + No LIP File }
  MiscDialogueCategory = 7;

var
  TargetFile: IInterface;
  StatusPath, ErrorPath, OutputPath: string;

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

procedure WriteError(const ErrorText: string);
var
  Lines: TStringList;
begin
  Lines := TStringList.Create;
  try
    Lines.Add(ErrorText);
    Lines.SaveToFile(ErrorPath);
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

function RequireTopic(
  ObjectID: Cardinal;
  const ExpectedEditorID: string
): IInterface;
begin
  Result := DefinedRecordByObjectID(TargetFile, ObjectID);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve DIAL object ID ' + IntToHex(ObjectID, 6)
    );
  if Signature(Result) <> 'DIAL' then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected DIAL'
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      'Object ID ' + IntToHex(ObjectID, 6) + ' has EditorID "' +
      GetElementEditValues(Result, 'EDID') + '", expected "' +
      ExpectedEditorID + '"'
    );
end;

procedure ConfigureSharedResponse(
  InfoRecord: IInterface;
  const ExpectedEditorID, ResponseText: string;
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal
);
var
  SkyrimFile, SharedInfo, SharedInfoTopic, SharedInfoGroup, CandidateInfo,
    SourceResponses, SharedInfoElement, SharedInfoTarget,
    TargetResponses: IInterface;
  i: Integer;
  DonorIsTopicChild: Boolean;
begin
  SkyrimFile := FileByPluginName('Skyrim.esm');
  if not Assigned(SkyrimFile) then
    raise Exception.Create('Skyrim.esm is not loaded');

  SharedInfo := RecordByFormID(
    SkyrimFile,
    SharedInfoFormID,
    True
  );
  if not Assigned(SharedInfo) then
    raise Exception.Create(
      ExpectedEditorID + ' could not resolve shared response donor ' +
      IntToHex(SharedInfoFormID, 8)
    );
  if Signature(SharedInfo) <> 'INFO' then
    raise Exception.Create(
      ExpectedEditorID + ' shared response donor resolved to ' +
      Signature(SharedInfo) + ', expected INFO'
    );
  if Trim(GetElementEditValues(SharedInfo, 'EDID')) = '' then
    raise Exception.Create(
      ExpectedEditorID + ' shared response donor has no EditorID'
    );

  SharedInfoTopic := RecordByFormID(
    SkyrimFile,
    SharedInfoTopicFormID,
    True
  );
  if not Assigned(SharedInfoTopic) or
    (Signature(SharedInfoTopic) <> 'DIAL') then
    raise Exception.Create(
      ExpectedEditorID + ' could not resolve SharedInfo topic ' +
      IntToHex(SharedInfoTopicFormID, 8)
    );
  if GetElementNativeValues(
    SharedInfoTopic,
    'DATA\Category'
  ) <> MiscDialogueCategory then
    raise Exception.Create(
      ExpectedEditorID + ' donor topic is not Misc dialogue: category=' +
      GetElementEditValues(SharedInfoTopic, 'DATA\Category')
    );
  if GetElementEditValues(SharedInfoTopic, 'SNAM') <> 'SharedInfo' then
    raise Exception.Create(
      ExpectedEditorID + ' donor topic subtype name is not SharedInfo: ' +
      GetElementEditValues(SharedInfoTopic, 'SNAM')
    );

  SharedInfoGroup := ChildGroup(SharedInfoTopic);
  DonorIsTopicChild := False;
  if Assigned(SharedInfoGroup) then
    for i := 0 to Pred(ElementCount(SharedInfoGroup)) do begin
      CandidateInfo := ElementByIndex(SharedInfoGroup, i);
      if (Signature(CandidateInfo) = 'INFO') and
        (FormID(CandidateInfo) = SharedInfoFormID) then begin
        DonorIsTopicChild := True;
        Break;
      end;
    end;
  if not DonorIsTopicChild then
    raise Exception.Create(
      ExpectedEditorID + ' donor is not a child of its SharedInfo topic'
    );

  SourceResponses := ElementByPath(SharedInfo, 'Responses');
  if not Assigned(SourceResponses) or (ElementCount(SourceResponses) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' shared response donor must own one response'
    );
  if GetElementEditValues(
    SharedInfo,
    'Responses\Response\NAM1'
  ) <> ResponseText then
    raise Exception.Create(
      ExpectedEditorID + ' shared response donor text is not "' +
      ResponseText + '"'
    );

  if Assigned(ElementByPath(InfoRecord, 'Responses')) then
    RemoveElement(InfoRecord, 'Responses');

  SharedInfoElement := ElementByPath(InfoRecord, 'DNAM');
  if not Assigned(SharedInfoElement) then begin
    Add(InfoRecord, 'DNAM', True);
    SharedInfoElement := ElementByPath(InfoRecord, 'DNAM');
  end;
  if not Assigned(SharedInfoElement) then
    raise Exception.Create(
      ExpectedEditorID + ' could not create Shared Info'
    );
  SetEditValue(SharedInfoElement, Name(SharedInfo));
  SharedInfoTarget := LinksTo(SharedInfoElement);
  if not Assigned(SharedInfoTarget) or
    (FormID(SharedInfoTarget) <> SharedInfoFormID) then
    raise Exception.Create(
      ExpectedEditorID + ' shared response donor did not read back'
    );

  TargetResponses := ElementByPath(InfoRecord, 'Responses');
  if Assigned(TargetResponses) and (ElementCount(TargetResponses) > 0) then
    raise Exception.Create(
      ExpectedEditorID + ' still owns response data'
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
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal
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

  ConfigureSharedResponse(
    RootInfo,
    RootEditorID,
    ResponseText,
    SharedInfoFormID,
    SharedInfoTopicFormID
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
    '; voiced shared response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureTravelInfo(
  InfoObjectID: Cardinal;
  const InfoEditorID, PromptText, ResponseText, DestinationID: string;
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal
);
var
  InfoRecord, TargetVMAD, Links: IInterface;
  ReadBackFlags: Cardinal;
begin
  InfoRecord := RequireInfo(InfoObjectID, InfoEditorID);

  SetElementEditValues(InfoRecord, 'RNAM', PromptText);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(
      InfoEditorID + ' destination prompt did not read back'
    );

  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) then
    RemoveElement(InfoRecord, 'Link To');

  ConfigureSharedResponse(
    InfoRecord,
    InfoEditorID,
    ResponseText,
    SharedInfoFormID,
    SharedInfoTopicFormID
  );
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    DirectResponseFlagsMask
  );
  ReadBackFlags := GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> DirectResponseFlagsMask then
    raise Exception.Create(
      InfoEditorID + ' response flags did not read back'
    );

  TargetVMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create(
      InfoEditorID + ' has no travel fragment VMAD'
    );
  SetElementNativeValues(
    TargetVMAD,
    'Script Fragments\Flags',
    OnBeginFragmentMask
  );
  ValidateFragmentProperties(
    InfoRecord,
    InfoEditorID,
    DestinationID
  );

  AddMessage(
    '[DNT] ' + InfoEditorID + ' -> ' + DestinationID +
    '; voiced shared response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureHubMenu;
const
  HubPrompt = 'Can you teleport me somewhere? (250 gold per trip)';
  HubResponse = 'Where do you need to go?';
var
  HubInfo, LinkTemplateInfo, WhiterunTopic, RiftenTopic, SourceLinks,
    SourceLink, TargetLinks, FirstLink, SecondLink: IInterface;
  ReadBackFlags: Cardinal;
begin
  HubInfo := RequireInfo($000808, 'DNT_WG_Request_Phinis');
  LinkTemplateInfo := RequireInfo(
    $000807,
    'DNT_WG_Request_Wylandriah'
  );
  WhiterunTopic := RequireTopic($000803, 'DNT_WG_ToWhiterun');
  RiftenTopic := RequireTopic($000804, 'DNT_WG_ToRiften');

  SetElementEditValues(HubInfo, 'RNAM', HubPrompt);
  if GetElementEditValues(HubInfo, 'RNAM') <> HubPrompt then
    raise Exception.Create('Phinis hub prompt did not read back');

  ConfigureOwnedResponse(
    HubInfo,
    'DNT_WG_Request_Phinis',
    HubResponse,
    $000C819B
  );
  SetElementNativeValues(
    HubInfo,
    'ENAM\Response Flags',
    HubResponseFlagsMask
  );
  ReadBackFlags := GetElementNativeValues(
    HubInfo,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> HubResponseFlagsMask then
    raise Exception.Create('Phinis hub response flags did not read back');

  if Assigned(ElementByPath(HubInfo, 'VMAD')) then
    RemoveElement(HubInfo, 'VMAD');
  if Assigned(ElementByPath(HubInfo, 'VMAD')) then
    raise Exception.Create('Phinis hub still has a travel VMAD');

  TargetLinks := ElementByPath(HubInfo, 'Link To');
  if Assigned(TargetLinks) and (ElementCount(TargetLinks) = 2) then begin
    FirstLink := ElementByIndex(TargetLinks, 0);
    SecondLink := ElementByIndex(TargetLinks, 1);
  end else begin
    SourceLinks := ElementByPath(LinkTemplateInfo, 'Link To');
    if not Assigned(SourceLinks) or (ElementCount(SourceLinks) <> 1) then
      raise Exception.Create(
        'No reusable Link To structure exists for the Phinis hub'
      );
    SourceLink := ElementByIndex(SourceLinks, 0);

    if Assigned(TargetLinks) then
      RemoveElement(HubInfo, 'Link To');
    Add(HubInfo, 'Link To', True);
    TargetLinks := ElementByPath(HubInfo, 'Link To');
    if not Assigned(TargetLinks) then
      raise Exception.Create('Could not create Phinis hub Link To array');

    FirstLink := ElementAssign(
      TargetLinks,
      HighInteger,
      SourceLink,
      False
    );
    if not Assigned(FirstLink) then
      raise Exception.Create('Could not create Whiterun hub link');

    SecondLink := ElementAssign(
      TargetLinks,
      HighInteger,
      SourceLink,
      False
    );
    if not Assigned(SecondLink) then
      raise Exception.Create('Could not create Riften hub link');
  end;

  SetEditValue(FirstLink, Name(WhiterunTopic));
  SetEditValue(SecondLink, Name(RiftenTopic));

  TargetLinks := ElementByPath(HubInfo, 'Link To');
  if not Assigned(TargetLinks) or (ElementCount(TargetLinks) <> 2) then
    raise Exception.Create(
      'Phinis hub does not have exactly two Link To entries'
    );
  FirstLink := LinksTo(ElementByIndex(TargetLinks, 0));
  SecondLink := LinksTo(ElementByIndex(TargetLinks, 1));
  if not Assigned(FirstLink) or
    (FormID(FirstLink) <> FormID(WhiterunTopic)) then
    raise Exception.Create('Phinis first hub link is not Whiterun');
  if not Assigned(SecondLink) or
    (FormID(SecondLink) <> FormID(RiftenTopic)) then
    raise Exception.Create('Phinis second hub link is not Riften');

  AddMessage(
    '[DNT] DNT_WG_Request_Phinis hub -> whiterun,riften; ' +
    'owned unvoiced response; flags=0x' + IntToHex(ReadBackFlags, 4)
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
  ErrorPath :=
    ScriptsPath + '..\..\build\wizard-guide-fix.error';
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

    ConfigureHubMenu;
    ConfigureDirectRoute(
      $000806,
      'DNT_WG_Request_Farengar',
      $000809,
      'DNT_WG_College_FromFarengar',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Yes.',
      'college',
      $000730FA,
      $00035B52
    );
    ConfigureDirectRoute(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      $000DBA22,
      $0001F319
    );
    ConfigureTravelInfo(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      'Send me to Whiterun. (250 gold)',
      'Of course.',
      'whiterun',
      $000DBA22,
      $0001F319
    );
    ConfigureTravelInfo(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      'Send me to Riften. (250 gold)',
      'Of course.',
      'riften',
      $000DBA22,
      $0001F319
    );

    SavePatchedPlugin;
    WriteStatus('success');
  except
    on E: Exception do begin
      WriteError(E.Message);
      WriteStatus('failed');
      raise;
    end;
  end;
end;

function Finalize: Integer;
begin
  Result := 0;
end;

end.
