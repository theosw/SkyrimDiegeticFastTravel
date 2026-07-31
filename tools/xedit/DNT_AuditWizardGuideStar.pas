{
  Read-only, exact-record audit for the College-centred wizard-guide star.
  It checks the five inbound court-wizard routes, the shared College faculty
  hub, all five voiced faculty destinations, Mirabelle's five subtitle-only
  fallbacks, and all three extended service-marker bindings.
}
unit DNT_AuditWizardGuideStar;

const
  TargetPluginName = 'DiegeticTravelWizardGuides.esp';
  OnBeginFragmentMask = $01;
  DirectResponseFlagsMask = $0001;
  SilentDirectResponseFlagsMask = $0A01;
  HubResponseFlagsMask = $0A00;
  MiscDialogueCategory = 7;
  EqualConditionType = $00;
  GreaterThanOrEqualConditionType = $60;
  NotEqualConditionType = $20;

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

procedure AssertSharedResponse(
  InfoRecord: IInterface;
  const EditorID, ExpectedText: string;
  ExpectedSharedInfoFormID, ExpectedSharedInfoTopicFormID: Cardinal
);
var
  SkyrimFile, Responses, SharedInfo, SharedInfoTopic, SharedInfoGroup,
    CandidateInfo: IInterface;
  i: Integer;
  DonorIsTopicChild: Boolean;
begin
  SkyrimFile := FileByPluginName('Skyrim.esm');
  if not Assigned(SkyrimFile) then
    raise Exception.Create('Skyrim.esm is not loaded');
  SharedInfo := LinksTo(ElementByPath(InfoRecord, 'DNAM'));
  if not Assigned(SharedInfo) then
    raise Exception.Create(EditorID + ' has no Shared Info donor');
  if FormID(SharedInfo) <> ExpectedSharedInfoFormID then
    raise Exception.Create(EditorID + ' Shared Info donor does not match');
  if Trim(GetElementEditValues(SharedInfo, 'EDID')) = '' then
    raise Exception.Create(EditorID + ' Shared Info donor has no EditorID');

  SharedInfoTopic := RecordByFormID(
    SkyrimFile,
    ExpectedSharedInfoTopicFormID,
    True
  );
  if not Assigned(SharedInfoTopic) or
    (Signature(SharedInfoTopic) <> 'DIAL') then
    raise Exception.Create(EditorID + ' SharedInfo topic does not resolve');
  if GetElementNativeValues(
    SharedInfoTopic,
    'DATA\Category'
  ) <> MiscDialogueCategory then
    raise Exception.Create(EditorID + ' donor topic is not Misc dialogue');
  if GetElementEditValues(SharedInfoTopic, 'SNAM') <> 'SharedInfo' then
    raise Exception.Create(
      EditorID + ' donor topic subtype name is not SharedInfo'
    );

  SharedInfoGroup := ChildGroup(SharedInfoTopic);
  DonorIsTopicChild := False;
  if Assigned(SharedInfoGroup) then
    for i := 0 to Pred(ElementCount(SharedInfoGroup)) do begin
      CandidateInfo := ElementByIndex(SharedInfoGroup, i);
      if (Signature(CandidateInfo) = 'INFO') and
        (FormID(CandidateInfo) = ExpectedSharedInfoFormID) then begin
        DonorIsTopicChild := True;
        Break;
      end;
    end;
  if not DonorIsTopicChild then
    raise Exception.Create(
      EditorID + ' donor is not a child of its SharedInfo topic'
    );
  Responses := ElementByPath(InfoRecord, 'Responses');
  if Assigned(Responses) and (ElementCount(Responses) > 0) then
    raise Exception.Create(EditorID + ' unexpectedly owns response data');
  if GetElementEditValues(
    SharedInfo,
    'Responses\Response\NAM1'
  ) <> ExpectedText then
    raise Exception.Create(EditorID + ' shared response text does not match');
end;

procedure AssertOwnedResponse(
  InfoRecord: IInterface;
  const EditorID, ExpectedText: string
);
var
  Responses: IInterface;
begin
  if Assigned(ElementByPath(InfoRecord, 'DNAM')) then
    raise Exception.Create(EditorID + ' unexpectedly uses Shared Info');
  Responses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(Responses) or (ElementCount(Responses) <> 1) then
    raise Exception.Create(EditorID + ' must own exactly one response');
  if GetElementEditValues(
    InfoRecord,
    'Responses\Response\NAM1'
  ) <> ExpectedText then
    raise Exception.Create(EditorID + ' owned response text does not match');
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

procedure AssertConditionAt(
  InfoRecord: IInterface;
  const EditorID: string;
  ConditionIndex: Integer;
  const ExpectedFunction: string;
  ExpectedParameterFormID, ExpectedType: Cardinal;
  ExpectedComparisonValue: Double
);
var
  Conditions, ConditionEntry, ConditionData, ParameterRecord: IInterface;
  ActualComparisonValue: Double;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or
    (ConditionIndex >= ElementCount(Conditions)) then
    raise Exception.Create(EditorID + ' condition index is missing');
  ConditionEntry := ElementByIndex(Conditions, ConditionIndex);
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create(EditorID + ' condition has no CTDA');
  if GetElementEditValues(ConditionData, 'Function') <>
    ExpectedFunction then
    raise Exception.Create(EditorID + ' condition function does not match');
  if GetElementNativeValues(ConditionData, 'Type') <> ExpectedType then
    raise Exception.Create(EditorID + ' condition type does not match');
  if GetElementNativeValues(ConditionData, 'Run On') <> 0 then
    raise Exception.Create(EditorID + ' condition does not run on Subject');
  ActualComparisonValue := GetElementNativeValues(
    ConditionData,
    'Comparison Value - Float'
  );
  if Abs(ActualComparisonValue - ExpectedComparisonValue) > 0.001 then
    raise Exception.Create(
      EditorID + ' condition comparison value does not match'
    );
  ParameterRecord := LinksTo(ElementByPath(ConditionData, 'Parameter #1'));
  if not Assigned(ParameterRecord) or
    (FormID(ParameterRecord) <> ExpectedParameterFormID) then
    raise Exception.Create(EditorID + ' condition parameter does not match');
end;

procedure AssertDirectSpeakerGate(
  InfoRecord: IInterface;
  const EditorID: string;
  ExpectedFormID: Cardinal
);
var
  Conditions: IInterface;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) or (ElementCount(Conditions) <> 1) then
    if not Assigned(Conditions) then
      raise Exception.Create(EditorID + ' has no exact-speaker condition')
    else
      raise Exception.Create(
        EditorID + ' exact-speaker condition count=' +
        IntToStr(ElementCount(Conditions)) + ', expected=1'
      );
  AssertConditionAt(
    InfoRecord,
    EditorID,
    0,
    'GetIsID',
    ExpectedFormID,
    EqualConditionType,
    1.0
  );
end;

procedure AssertCollegeFacultySpeaker(
  InfoRecord: IInterface;
  const EditorID: string;
  ExcludeMirabelle: Boolean
);
var
  Conditions, Speaker: IInterface;
  ExpectedConditionCount: Integer;
begin
  Speaker := LinksTo(ElementByPath(InfoRecord, 'ANAM'));
  if Assigned(Speaker) then
    raise Exception.Create(EditorID + ' unexpectedly has an exact speaker');
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if ExcludeMirabelle then
    ExpectedConditionCount := 4
  else
    ExpectedConditionCount := 3;
  if not Assigned(Conditions) or
    (ElementCount(Conditions) <> ExpectedConditionCount) then
    if not Assigned(Conditions) then
      raise Exception.Create(EditorID + ' has no faculty conditions')
    else
      raise Exception.Create(
        EditorID + ' faculty condition count=' +
        IntToStr(ElementCount(Conditions)) + ', expected=' +
        IntToStr(ExpectedConditionCount)
      );

  AssertConditionAt(
    InfoRecord,
    EditorID,
    0,
    'GetFactionRank',
    $0001F259,
    GreaterThanOrEqualConditionType,
    3.0
  );
  AssertConditionAt(
    InfoRecord,
    EditorID,
    1,
    'GetIsID',
    $0006A152,
    NotEqualConditionType,
    1.0
  );
  AssertConditionAt(
    InfoRecord,
    EditorID,
    2,
    'GetIsID',
    $0003B0E4,
    NotEqualConditionType,
    1.0
  );
  if ExcludeMirabelle then
    AssertConditionAt(
      InfoRecord,
      EditorID,
      3,
      'GetIsID',
      $0001C1A0,
      NotEqualConditionType,
      1.0
    );
end;

procedure AssertTopicChild(
  TopicRecord, InfoRecord: IInterface;
  const EditorID: string
);
var
  InfoGroup, CandidateInfo: IInterface;
  i: Integer;
begin
  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) then
    raise Exception.Create(EditorID + ' topic has no INFO group');
  for i := 0 to Pred(ElementCount(InfoGroup)) do begin
    CandidateInfo := ElementByIndex(InfoGroup, i);
    if Assigned(CandidateInfo) and
      (Signature(CandidateInfo) = 'INFO') and
      (FormID(CandidateInfo) = FormID(InfoRecord)) then
      Exit;
  end;
  raise Exception.Create(EditorID + ' is not a child of its destination topic');
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

procedure AuditServiceMarker(
  const PropertyNameValue: string;
  ExpectedMarkerFormID: Cardinal;
  const ExpectedMarkerEditorID: string
);
var
  ServiceQuest, VMAD, Scripts, ScriptEntry, Properties, PropertyEntry,
    MarkerRecord: IInterface;
  PropertyName: string;
  i, MatchCount: Integer;
begin
  ServiceQuest := RequireRecord(
    $000800,
    'QUST',
    'DNT_WizardTravelQuest'
  );
  VMAD := ElementByPath(ServiceQuest, 'VMAD');
  Scripts := ElementByPath(VMAD, 'Scripts');
  if not Assigned(Scripts) then
    raise Exception.Create('Wizard travel service quest has no scripts');
  ScriptEntry := nil;
  for i := 0 to Pred(ElementCount(Scripts)) do
    if GetElementEditValues(
      ElementByIndex(Scripts, i),
      'ScriptName'
    ) = 'DNT_WizardTravelService' then begin
      ScriptEntry := ElementByIndex(Scripts, i);
      Break;
    end;
  if not Assigned(ScriptEntry) then
    raise Exception.Create('Wizard travel service script is not bound');

  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    raise Exception.Create('Wizard travel service has no properties');
  MatchCount := 0;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyEntry := ElementByIndex(Properties, i);
    PropertyName := GetElementEditValues(PropertyEntry, 'propertyName');
    if PropertyName = PropertyNameValue then begin
      Inc(MatchCount);
      MarkerRecord := LinksTo(
        ElementByPath(
          PropertyEntry,
          'Value\Object Union\Object v2\FormID'
        )
      );
      if not Assigned(MarkerRecord) or
        (FormID(MarkerRecord) <> ExpectedMarkerFormID) then
        raise Exception.Create(
          PropertyNameValue + ' does not point to ' +
          IntToHex(ExpectedMarkerFormID, 8)
        );
      if GetElementEditValues(MarkerRecord, 'EDID') <>
        ExpectedMarkerEditorID then
        raise Exception.Create(
          PropertyNameValue + ' marker EditorID does not match'
        );
    end;
  end;
  if MatchCount <> 1 then
    raise Exception.Create(
      'Wizard travel service ' + PropertyNameValue + ' count=' +
      IntToStr(MatchCount)
    );
  ReportLines.Add(
    'PASS service ' + PropertyNameValue + ' -> ' +
    ExpectedMarkerEditorID + ' ' + IntToHex(ExpectedMarkerFormID, 8)
  );
end;

procedure AuditDirect(
  ObjectID: Cardinal;
  const EditorID, PromptText, ResponseText, DestinationID: string;
  SpeakerFormID, SharedInfoFormID, SharedInfoTopicFormID: Cardinal
);
var
  InfoRecord, Links: IInterface;
begin
  InfoRecord := RequireRecord(ObjectID, 'INFO', EditorID);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(EditorID + ' prompt does not match');
  AssertSharedResponse(
    InfoRecord,
    EditorID,
    ResponseText,
    SharedInfoFormID,
    SharedInfoTopicFormID
  );
  AssertSpeaker(InfoRecord, EditorID, SpeakerFormID);
  AssertDirectSpeakerGate(InfoRecord, EditorID, SpeakerFormID);
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

procedure AuditFacultyVoicedDestination(
  ObjectID: Cardinal;
  const EditorID, PromptText, DestinationID: string;
  DestinationTopic: IInterface
);
var
  InfoRecord, Links: IInterface;
begin
  InfoRecord := RequireRecord(ObjectID, 'INFO', EditorID);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(EditorID + ' prompt does not match');
  AssertSharedResponse(
    InfoRecord,
    EditorID,
    'Of course.',
    $000DBA22,
    $0001F319
  );
  AssertCollegeFacultySpeaker(InfoRecord, EditorID, True);
  if GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  ) <> DirectResponseFlagsMask then
    raise Exception.Create(EditorID + ' direct response flags do not match');
  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) and (ElementCount(Links) > 0) then
    raise Exception.Create(EditorID + ' unexpectedly has Link To entries');
  AssertTravelFragment(InfoRecord, EditorID, DestinationID);
  AssertTopicChild(DestinationTopic, InfoRecord, EditorID);
  ReportLines.Add(
    'PASS voiced faculty ' + EditorID + ' -> ' + DestinationID
  );
end;

procedure AuditMirabelleDestination(
  ObjectID: Cardinal;
  const EditorID, PromptText, DestinationID: string;
  DestinationTopic: IInterface
);
var
  InfoRecord, Links: IInterface;
begin
  InfoRecord := RequireRecord(ObjectID, 'INFO', EditorID);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(EditorID + ' prompt does not match');
  AssertOwnedResponse(InfoRecord, EditorID, 'Of course.');
  AssertSpeaker(InfoRecord, EditorID, $0001C1A0);
  AssertDirectSpeakerGate(InfoRecord, EditorID, $0001C1A0);
  if GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  ) <> SilentDirectResponseFlagsMask then
    raise Exception.Create(EditorID + ' silent flags do not match');
  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) and (ElementCount(Links) > 0) then
    raise Exception.Create(EditorID + ' unexpectedly has Link To entries');
  AssertTravelFragment(InfoRecord, EditorID, DestinationID);
  AssertTopicChild(DestinationTopic, InfoRecord, EditorID);
  ReportLines.Add(
    'PASS Mirabelle subtitle ' + EditorID + ' -> ' + DestinationID
  );
end;

procedure AuditHub;
var
  HubInfo, Links, FirstTarget, SecondTarget, ThirdTarget, FourthTarget,
    FifthTarget, WhiterunTopic, RiftenTopic, SolitudeTopic, WindhelmTopic,
    MarkarthTopic: IInterface;
begin
  HubInfo := RequireRecord($000808, 'INFO', 'DNT_WG_Request_Phinis');
  WhiterunTopic := RequireRecord(
    $000803,
    'DIAL',
    'DNT_WG_ToWhiterun'
  );
  RiftenTopic := RequireRecord($000804, 'DIAL', 'DNT_WG_ToRiften');
  SolitudeTopic := RequireRecord($00080F, 'DIAL', 'DNT_WG_ToSolitude');
  WindhelmTopic := RequireRecord($000813, 'DIAL', 'DNT_WG_ToWindhelm');
  MarkarthTopic := RequireRecord($000817, 'DIAL', 'DNT_WG_ToMarkarth');

  if GetElementEditValues(HubInfo, 'RNAM') <>
    'Can you teleport me somewhere? (250 gold per trip)' then
    raise Exception.Create('Phinis hub prompt does not match');
  AssertOwnedResponse(
    HubInfo,
    'DNT_WG_Request_Phinis',
    'Where do you need to go?'
  );
  AssertCollegeFacultySpeaker(HubInfo, 'DNT_WG_Request_Phinis', False);
  if GetElementNativeValues(
    HubInfo,
    'ENAM\Response Flags'
  ) <> HubResponseFlagsMask then
    raise Exception.Create('Phinis hub response flags do not match');
  if Assigned(ElementByPath(HubInfo, 'VMAD')) then
    raise Exception.Create('Phinis hub unexpectedly has a travel VMAD');

  Links := ElementByPath(HubInfo, 'Link To');
  if not Assigned(Links) or (ElementCount(Links) <> 5) then
    raise Exception.Create('Phinis hub must have exactly five Link To entries');
  FirstTarget := LinksTo(ElementByIndex(Links, 0));
  SecondTarget := LinksTo(ElementByIndex(Links, 1));
  ThirdTarget := LinksTo(ElementByIndex(Links, 2));
  FourthTarget := LinksTo(ElementByIndex(Links, 3));
  FifthTarget := LinksTo(ElementByIndex(Links, 4));
  if not Assigned(FirstTarget) or
    (FormID(FirstTarget) <> FormID(WhiterunTopic)) then
    raise Exception.Create('Phinis first hub target is not Whiterun');
  if not Assigned(SecondTarget) or
    (FormID(SecondTarget) <> FormID(RiftenTopic)) then
    raise Exception.Create('Phinis second hub target is not Riften');
  if not Assigned(ThirdTarget) or
    (FormID(ThirdTarget) <> FormID(SolitudeTopic)) then
    raise Exception.Create('Phinis third hub target is not Solitude');
  if not Assigned(FourthTarget) or
    (FormID(FourthTarget) <> FormID(WindhelmTopic)) then
    raise Exception.Create('Phinis fourth hub target is not Windhelm');
  if not Assigned(FifthTarget) or
    (FormID(FifthTarget) <> FormID(MarkarthTopic)) then
    raise Exception.Create('Phinis fifth hub target is not Markarth');

  ReportLines.Add(
    'PASS hub DNT_WG_Request_Phinis -> ' +
    'whiterun,riften,solitude,windhelm,markarth'
  );
end;

function Initialize: Integer;
var
  WhiterunTopic, RiftenTopic, SolitudeTopic, WindhelmTopic, MarkarthTopic,
    SolitudeInfoGroup, WindhelmInfoGroup, MarkarthInfoGroup: IInterface;
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
      'Yes.',
      'college',
      $00013BBB,
      $000730FA,
      $00035B52
    );
    AuditDirect(
      $000807,
      'DNT_WG_Request_Wylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      $00019DEF,
      $000DBA22,
      $0001F319
    );
    AuditDirect(
      $000812,
      'DNT_WG_Request_Sybille',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      $000132AA,
      $000DBA22,
      $0001F319
    );
    AuditDirect(
      $000816,
      'DNT_WG_Request_Wuunferth',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      $00014146,
      $000DBA22,
      $0001F319
    );
    AuditDirect(
      $00081A,
      'DNT_WG_Request_Calcelmo',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      $0001338E,
      $000DBA22,
      $0001F319
    );
    AuditServiceMarker(
      'SolitudeMarker',
      $0002C194,
      'BluePalaceAudienceMarker'
    );
    AuditServiceMarker(
      'WindhelmMarker',
      $000A3F1C,
      'WindhelmWuunferthLabMarker'
    );
    AuditServiceMarker(
      'MarkarthMarker',
      $0003692A,
      'MarkarthCastleWizardVendorMarkerREF'
    );
    AuditHub;
    WhiterunTopic := RequireRecord(
      $000803,
      'DIAL',
      'DNT_WG_ToWhiterun'
    );
    RiftenTopic := RequireRecord(
      $000804,
      'DIAL',
      'DNT_WG_ToRiften'
    );
    SolitudeTopic := RequireRecord(
      $00080F,
      'DIAL',
      'DNT_WG_ToSolitude'
    );
    WindhelmTopic := RequireRecord(
      $000813,
      'DIAL',
      'DNT_WG_ToWindhelm'
    );
    MarkarthTopic := RequireRecord(
      $000817,
      'DIAL',
      'DNT_WG_ToMarkarth'
    );
    SolitudeInfoGroup := ChildGroup(SolitudeTopic);
    if not Assigned(SolitudeInfoGroup) or
      (ElementCount(SolitudeInfoGroup) <> 2) then
      raise Exception.Create(
        'DNT_WG_ToSolitude must contain exactly two INFO records'
      );
    WindhelmInfoGroup := ChildGroup(WindhelmTopic);
    if not Assigned(WindhelmInfoGroup) or
      (ElementCount(WindhelmInfoGroup) <> 2) then
      raise Exception.Create(
        'DNT_WG_ToWindhelm must contain exactly two INFO records'
      );
    MarkarthInfoGroup := ChildGroup(MarkarthTopic);
    if not Assigned(MarkarthInfoGroup) or
      (ElementCount(MarkarthInfoGroup) <> 2) then
      raise Exception.Create(
        'DNT_WG_ToMarkarth must contain exactly two INFO records'
      );
    AuditFacultyVoicedDestination(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      'Send me to Whiterun. (250 gold)',
      'whiterun',
      WhiterunTopic
    );
    AuditFacultyVoicedDestination(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      'Send me to Riften. (250 gold)',
      'riften',
      RiftenTopic
    );
    AuditMirabelleDestination(
      $00080D,
      'DNT_WG_Whiterun_FromMirabelle',
      'Send me to Whiterun. (250 gold)',
      'whiterun',
      WhiterunTopic
    );
    AuditMirabelleDestination(
      $00080E,
      'DNT_WG_Riften_FromMirabelle',
      'Send me to Riften. (250 gold)',
      'riften',
      RiftenTopic
    );
    AuditFacultyVoicedDestination(
      $000810,
      'DNT_WG_Solitude_FromPhinis',
      'Send me to Solitude. (250 gold)',
      'solitude',
      SolitudeTopic
    );
    AuditMirabelleDestination(
      $000811,
      'DNT_WG_Solitude_FromMirabelle',
      'Send me to Solitude. (250 gold)',
      'solitude',
      SolitudeTopic
    );
    AuditFacultyVoicedDestination(
      $000814,
      'DNT_WG_Windhelm_FromPhinis',
      'Send me to Windhelm. (250 gold)',
      'windhelm',
      WindhelmTopic
    );
    AuditMirabelleDestination(
      $000815,
      'DNT_WG_Windhelm_FromMirabelle',
      'Send me to Windhelm. (250 gold)',
      'windhelm',
      WindhelmTopic
    );
    AuditFacultyVoicedDestination(
      $000818,
      'DNT_WG_Markarth_FromPhinis',
      'Send me to Markarth. (250 gold)',
      'markarth',
      MarkarthTopic
    );
    AuditMirabelleDestination(
      $000819,
      'DNT_WG_Markarth_FromMirabelle',
      'Send me to Markarth. (250 gold)',
      'markarth',
      MarkarthTopic
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
