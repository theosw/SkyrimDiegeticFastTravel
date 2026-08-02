{
  Build the College-centred wizard-guide star:

    Farengar Secret-Fire -> College of Winterhold
    Wylandriah           -> College of Winterhold
    Sybille Stentor      -> College of Winterhold
    Wuunferth the Unliving -> College of Winterhold
    Calcelmo             -> College of Winterhold
    Madena               -> College of Winterhold
    Falion               -> College of Winterhold
    College faculty      -> Whiterun, Riften, Solitude, Windhelm, Markarth,
                            Dawnstar, or Morthal

  Terminal travel INFOs deliberately share response data from short vanilla
  INFOs for which the speaker's exact voice type has shipped FUZ/LIP data.
  Court wizards use direct top-level routes to the College. The faculty hub
  owns an unvoiced forced-subtitle response because gameplay proved that a
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
  SilentDirectResponseFlagsMask = $0A01; { Goodbye + subtitle + no LIP }
  HubResponseFlagsMask = $0A00; { Force Subtitle + No LIP File }
  MiscDialogueCategory = 7;
  EqualConditionType = $00;
  GreaterThanOrEqualConditionType = $60;
  NotEqualConditionType = $20;
  LessThanConditionType = $80;
  FareGoldAmount = 250.0;

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

function RecordByPluginLocalFormID(
  FileElement: IInterface;
  LocalFormID: Cardinal
): IInterface;
var
  FileFormID, LoadOrderFormID: Cardinal;
begin
  FileFormID :=
    (MasterCount(FileElement) shl 24) or (LocalFormID and $00FFFFFF);
  LoadOrderFormID := FileFormIDtoLoadOrderFormID(FileElement, FileFormID);
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

function AddInfoFromTemplate(
  TopicRecord, TemplateInfo: IInterface
): IInterface;
var
  SourceVMAD, TargetVMAD: IInterface;
begin
  Result := Add(TopicRecord, 'INFO', True);
  if not Assigned(Result) then
    raise Exception.Create('Could not create INFO under destination topic');
  Add(Result, 'ENAM', True);
  Add(Result, 'CNAM', True);

  SourceVMAD := ElementByPath(TemplateInfo, 'VMAD');
  if not Assigned(SourceVMAD) then
    raise Exception.Create('Template INFO has no travel VMAD');
  Add(Result, 'VMAD', True);
  TargetVMAD := ElementByPath(Result, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create('Could not create destination INFO VMAD');
  ElementAssign(TargetVMAD, LowInteger, SourceVMAD, False);
  if not Assigned(ElementByPath(Result, 'VMAD')) then
    raise Exception.Create('Destination INFO VMAD disappeared');
end;

function EnsureClonedInfo(
  TemplateObjectID: Cardinal;
  const TemplateEditorID: string;
  InfoObjectID: Cardinal;
  const InfoEditorID: string
): IInterface;
var
  TemplateInfo: IInterface;
begin
  Result := DefinedRecordByObjectID(TargetFile, InfoObjectID);
  if not Assigned(Result) then begin
    TemplateInfo := RequireInfo(TemplateObjectID, TemplateEditorID);
    Result := wbCopyElementToFile(
      TemplateInfo,
      TargetFile,
      True,
      True
    );
    if not Assigned(Result) then
      raise Exception.Create('Could not create INFO ' + InfoEditorID);
    if (FormID(Result) and $00FFFFFF) <> InfoObjectID then
      raise Exception.Create(
        InfoEditorID + ' received object ID ' +
        IntToHex(FormID(Result) and $00FFFFFF, 6) +
        ', expected ' + IntToHex(InfoObjectID, 6)
      );
    SetElementEditValues(Result, 'EDID', InfoEditorID);
  end;

  if Signature(Result) <> 'INFO' then
    raise Exception.Create(InfoEditorID + ' is not an INFO');
  if GetElementEditValues(Result, 'EDID') <> InfoEditorID then
    raise Exception.Create(
      IntToHex(InfoObjectID, 6) + ' is not ' + InfoEditorID
    );
end;

procedure EnsureDestinationTopic(
  TopicObjectID: Cardinal;
  const TopicEditorID, DestinationLabel: string;
  GeneralInfoObjectID: Cardinal;
  const GeneralInfoEditorID: string;
  MirabelleInfoObjectID: Cardinal;
  const MirabelleInfoEditorID: string
);
var
  TemplateTopic, DestinationTopic, InfoGroup, GeneralInfo,
    MirabelleInfo: IInterface;
begin
  DestinationTopic := DefinedRecordByObjectID(TargetFile, TopicObjectID);
  if not Assigned(DestinationTopic) then begin
    TemplateTopic := RequireTopic($000804, 'DNT_WG_ToRiften');
    DestinationTopic := wbCopyElementToFile(
      TemplateTopic,
      TargetFile,
      True,
      True
    );
    if not Assigned(DestinationTopic) then
      raise Exception.Create(
        'Could not create ' + DestinationLabel + ' destination topic'
      );
    if (FormID(DestinationTopic) and $00FFFFFF) <> TopicObjectID then
      raise Exception.Create(
        DestinationLabel + ' topic received object ID ' +
        IntToHex(FormID(DestinationTopic) and $00FFFFFF, 6) +
        ', expected ' + IntToHex(TopicObjectID, 6)
      );
    SetElementEditValues(DestinationTopic, 'EDID', TopicEditorID);
  end;

  if Signature(DestinationTopic) <> 'DIAL' then
    raise Exception.Create(TopicEditorID + ' is not a DIAL');
  if GetElementEditValues(DestinationTopic, 'EDID') <> TopicEditorID then
    raise Exception.Create(
      IntToHex(TopicObjectID, 6) + ' is not ' + TopicEditorID
    );

  InfoGroup := ChildGroup(DestinationTopic);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) = 0) then begin
    GeneralInfo := AddInfoFromTemplate(
      DestinationTopic,
      RequireInfo($00080C, 'DNT_WG_Riften_FromPhinis')
    );
    MirabelleInfo := AddInfoFromTemplate(
      DestinationTopic,
      RequireInfo($00080E, 'DNT_WG_Riften_FromMirabelle')
    );
    InfoGroup := ChildGroup(DestinationTopic);
    SetElementNativeValues(
      DestinationTopic,
      'TIFC',
      ElementCount(InfoGroup)
    );
  end;
  if not Assigned(InfoGroup) or
    ((ElementCount(InfoGroup) <> 2) and
    (ElementCount(InfoGroup) <> 3)) then
    raise Exception.Create(
      TopicEditorID + ' must contain two funded INFO records and ' +
      'optionally one denial INFO record'
    );
  GeneralInfo := ElementByIndex(InfoGroup, 0);
  MirabelleInfo := ElementByIndex(InfoGroup, 1);
  if (FormID(GeneralInfo) and $00FFFFFF) <> GeneralInfoObjectID then
    raise Exception.Create(
      DestinationLabel + ' general INFO is not object ' +
      IntToHex(GeneralInfoObjectID, 6)
    );
  if (FormID(MirabelleInfo) and $00FFFFFF) <> MirabelleInfoObjectID then
    raise Exception.Create(
      DestinationLabel + ' Mirabelle INFO is not object ' +
      IntToHex(MirabelleInfoObjectID, 6)
    );
  SetElementEditValues(
    GeneralInfo,
    'EDID',
    GeneralInfoEditorID
  );
  SetElementEditValues(
    MirabelleInfo,
    'EDID',
    MirabelleInfoEditorID
  );
  SetElementNativeValues(
    DestinationTopic,
    'TIFC',
    ElementCount(InfoGroup)
  );
end;

function RequirePluginRecord(
  const PluginName: string;
  FormIDValue: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
var
  PluginFile: IInterface;
begin
  PluginFile := FileByPluginName(PluginName);
  if not Assigned(PluginFile) then
    raise Exception.Create(PluginName + ' is not loaded');
  Result := RecordByPluginLocalFormID(PluginFile, FormIDValue);
  if not Assigned(Result) then
    raise Exception.Create(
      'Could not resolve ' + PluginName + ' record ' +
      IntToHex(FormIDValue, 8)
    );
  if Signature(Result) <> ExpectedSignature then
    raise Exception.Create(
      ExpectedEditorID + ' resolved to ' + Signature(Result) +
      ', expected ' + ExpectedSignature
    );
  if GetElementEditValues(Result, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      PluginName + ':' + IntToHex(FormIDValue, 8) + ' is not ' +
      ExpectedEditorID
    );
end;

function RequireSkyrimRecord(
  FormIDValue: Cardinal;
  const ExpectedSignature, ExpectedEditorID: string
): IInterface;
begin
  Result := RequirePluginRecord(
    'Skyrim.esm',
    FormIDValue,
    ExpectedSignature,
    ExpectedEditorID
  );
end;

procedure AddSubjectCondition(
  InfoRecord: IInterface;
  const FunctionName: string;
  ParameterRecord: IInterface;
  ConditionType: Cardinal;
  ComparisonValue: Double
);
var
  Conditions, ConditionEntry, ConditionData, ParameterElement,
    ReadBackParameter: IInterface;
  CreatedConditions: Boolean;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  CreatedConditions := False;
  if not Assigned(Conditions) then begin
    Add(InfoRecord, 'Conditions', True);
    Conditions := ElementByPath(InfoRecord, 'Conditions');
    CreatedConditions := True;
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create INFO conditions');

  if CreatedConditions and (ElementCount(Conditions) > 0) then
    ConditionEntry := ElementByIndex(Conditions, 0)
  else if ElementCount(Conditions) = 0 then
    ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False)
  else if (
    ElementCount(Conditions) = 1
  ) and (
    Trim(GetElementEditValues(
      ElementByIndex(Conditions, 0),
      'CTDA\Function'
    )) = ''
  ) then
    ConditionEntry := ElementByIndex(Conditions, 0)
  else
    ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);

  if not Assigned(ConditionEntry) then
    raise Exception.Create('Could not create INFO condition entry');
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create('INFO condition has no CTDA');

  SetElementNativeValues(ConditionData, 'Type', ConditionType);
  SetElementNativeValues(
    ConditionData,
    'Comparison Value - Float',
    ComparisonValue
  );
  SetElementEditValues(ConditionData, 'Function', FunctionName);
  SetElementNativeValues(ConditionData, 'Run On', 0);
  ParameterElement := ElementByPath(ConditionData, 'Parameter #1');
  if not Assigned(ParameterElement) then
    raise Exception.Create(
      FunctionName + ' condition has no Parameter #1 after function setup'
    );
  SetEditValue(ParameterElement, Name(ParameterRecord));
  ReadBackParameter := LinksTo(ParameterElement);
  if not Assigned(ReadBackParameter) or
    (FormID(ReadBackParameter) <> FormID(ParameterRecord)) then
    raise Exception.Create(
      FunctionName + ' condition parameter did not read back'
    );
end;

procedure RemoveGoldConditions(InfoRecord: IInterface);
var
  Conditions, ConditionEntry: IInterface;
  i: Integer;
begin
  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then
    Exit;
  for i := Pred(ElementCount(Conditions)) downto 0 do begin
    ConditionEntry := ElementByIndex(Conditions, i);
    if GetElementEditValues(
      ConditionEntry,
      'CTDA\Function'
    ) = 'GetItemCount' then
      RemoveElement(Conditions, i);
  end;
end;

procedure AddPlayerGoldCondition(
  InfoRecord: IInterface;
  HasEnoughGold: Boolean
);
var
  Conditions, ConditionEntry, ConditionData, GoldElement, PlayerElement,
    GoldRecord, PlayerRef, ReadBackRecord: IInterface;
  ConditionType: Cardinal;
begin
  GoldRecord := RequireSkyrimRecord($0000000F, 'MISC', 'Gold001');
  PlayerRef := RequireSkyrimRecord($00000014, 'PLYR', 'PlayerRef');
  RemoveGoldConditions(InfoRecord);

  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then begin
    Add(InfoRecord, 'Conditions', True);
    Conditions := ElementByPath(InfoRecord, 'Conditions');
  end;
  if not Assigned(Conditions) then
    raise Exception.Create('Could not create gold conditions');

  ConditionEntry := ElementAssign(Conditions, HighInteger, nil, False);
  if not Assigned(ConditionEntry) then
    raise Exception.Create('Could not create gold condition entry');
  ConditionData := ElementByPath(ConditionEntry, 'CTDA');
  if not Assigned(ConditionData) then
    raise Exception.Create('Gold condition has no CTDA');

  if HasEnoughGold then
    ConditionType := GreaterThanOrEqualConditionType
  else
    ConditionType := LessThanConditionType;
  SetElementEditValues(ConditionData, 'Function', 'GetItemCount');
  SetElementNativeValues(ConditionData, 'Type', ConditionType);
  SetElementNativeValues(
    ConditionData,
    'Comparison Value - Float',
    FareGoldAmount
  );
  SetElementEditValues(ConditionData, 'Inventory Object', Name(GoldRecord));
  SetElementEditValues(ConditionData, 'Run On', 'Reference');
  SetElementEditValues(ConditionData, 'Reference', Name(PlayerRef));
  SetElementEditValues(ConditionData, 'Parameter #3', '-1');

  GoldElement := ElementByPath(ConditionData, 'Inventory Object');
  if not Assigned(GoldElement) then
    GoldElement := ElementByPath(ConditionData, 'Parameter #1');
  ReadBackRecord := LinksTo(GoldElement);
  if not Assigned(ReadBackRecord) or
    (FormID(ReadBackRecord) <> FormID(GoldRecord)) then
    raise Exception.Create('Gold condition inventory object did not read back');
  PlayerElement := ElementByPath(ConditionData, 'Reference');
  ReadBackRecord := LinksTo(PlayerElement);
  if not Assigned(ReadBackRecord) or
    (FormID(ReadBackRecord) <> FormID(PlayerRef)) then
    raise Exception.Create('Gold condition player reference did not read back');
  if GetElementEditValues(ConditionData, 'Run On') <> 'Reference' then
    raise Exception.Create('Gold condition does not run on Reference');
end;

procedure ConfigureCollegeFacultySpeaker(
  InfoRecord: IInterface;
  ExcludeMirabelle: Boolean
);
var
  CollegeFaction, ArnielShade, Endrast, Mirabelle: IInterface;
begin
  CollegeFaction := RequireSkyrimRecord(
    $0001F259,
    'FACT',
    'CollegeofWinterholdFaction'
  );
  ArnielShade := RequireSkyrimRecord(
    $0006A152,
    'NPC_',
    'MGArnielSummon'
  );
  Endrast := RequireSkyrimRecord(
    $0003B0E4,
    'NPC_',
    'dunAlftandEndrast'
  );

  if Assigned(ElementByPath(InfoRecord, 'ANAM')) then
    RemoveElement(InfoRecord, 'ANAM');
  if Assigned(ElementByPath(InfoRecord, 'Conditions')) then
    RemoveElement(InfoRecord, 'Conditions');

  AddSubjectCondition(
    InfoRecord,
    'GetFactionRank',
    CollegeFaction,
    GreaterThanOrEqualConditionType,
    3.0
  );
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    ArnielShade,
    NotEqualConditionType,
    1.0
  );
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    Endrast,
    NotEqualConditionType,
    1.0
  );

  if ExcludeMirabelle then begin
    Mirabelle := RequireSkyrimRecord(
      $0001C1A0,
      'NPC_',
      'MirabelleErvine'
    );
    AddSubjectCondition(
      InfoRecord,
      'GetIsID',
      Mirabelle,
      NotEqualConditionType,
      1.0
    );
  end;
end;

procedure ConfigureExactSpeaker(
  InfoRecord, SpeakerRecord: IInterface
);
var
  SpeakerElement, ReadBackSpeaker: IInterface;
begin
  if Assigned(ElementByPath(InfoRecord, 'Conditions')) then
    RemoveElement(InfoRecord, 'Conditions');
  SpeakerElement := ElementByPath(InfoRecord, 'ANAM');
  if not Assigned(SpeakerElement) then begin
    Add(InfoRecord, 'ANAM', True);
    SpeakerElement := ElementByPath(InfoRecord, 'ANAM');
  end;
  if not Assigned(SpeakerElement) then
    raise Exception.Create('Could not create exact INFO speaker');
  SetEditValue(SpeakerElement, Name(SpeakerRecord));
  ReadBackSpeaker := LinksTo(SpeakerElement);
  if not Assigned(ReadBackSpeaker) or
    (FormID(ReadBackSpeaker) <> FormID(SpeakerRecord)) then
    raise Exception.Create('Exact INFO speaker did not read back');
  AddSubjectCondition(
    InfoRecord,
    'GetIsID',
    SpeakerRecord,
    EqualConditionType,
    1.0
  );
end;

procedure ConfigureSharedResponse(
  InfoRecord: IInterface;
  const ExpectedEditorID, ResponseText, SharedPluginName: string;
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal
);
var
  SharedPluginFile, SharedInfo, SharedInfoTopic, SharedInfoGroup, CandidateInfo,
    SourceResponses, SharedInfoElement, SharedInfoTarget,
    TargetResponses: IInterface;
  i: Integer;
  DonorIsTopicChild: Boolean;
begin
  SharedPluginFile := FileByPluginName(SharedPluginName);
  if not Assigned(SharedPluginFile) then
    raise Exception.Create(SharedPluginName + ' is not loaded');

  SharedInfo := RecordByPluginLocalFormID(
    SharedPluginFile,
    SharedInfoFormID
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

  SharedInfoTopic := RecordByPluginLocalFormID(
    SharedPluginFile,
    SharedInfoTopicFormID
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
        (FormID(CandidateInfo) = FormID(SharedInfo)) then begin
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

  AddMasterIfMissing(TargetFile, SharedPluginName);

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
    (FormID(SharedInfoTarget) <> FormID(SharedInfo)) then
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

procedure SetFragmentDestinationID(
  InfoRecord: IInterface;
  const ExpectedEditorID, DestinationID: string
);
var
  TargetVMAD, Scripts, ScriptEntry, Properties, PropertyEntry: IInterface;
  i: Integer;
begin
  TargetVMAD := ElementByPath(InfoRecord, 'VMAD');
  if not Assigned(TargetVMAD) then
    raise Exception.Create(ExpectedEditorID + ' has no VMAD');
  Scripts := ElementByPath(TargetVMAD, 'Scripts');
  if not Assigned(Scripts) or (ElementCount(Scripts) <> 1) then
    raise Exception.Create(
      ExpectedEditorID + ' VMAD does not have exactly one script'
    );
  ScriptEntry := ElementByIndex(Scripts, 0);
  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    raise Exception.Create(ExpectedEditorID + ' has no fragment properties');

  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyEntry := ElementByIndex(Properties, i);
    if GetElementEditValues(PropertyEntry, 'propertyName') =
      'DestinationId' then begin
      SetElementEditValues(PropertyEntry, 'String', DestinationID);
      if GetElementEditValues(PropertyEntry, 'String') <> DestinationID then
        raise Exception.Create(
          ExpectedEditorID + ' DestinationId did not read back'
        );
      Exit;
    end;
  end;
  raise Exception.Create(ExpectedEditorID + ' DestinationId is missing');
end;

procedure ConfigureServiceObjectProperty(
  const PropertyNameValue: string;
  ObjectFormID: Cardinal;
  const ExpectedSignature, ObjectEditorID: string
);
var
  ServiceQuest, TargetVMAD, Scripts, ScriptEntry, Properties, PropertyEntry,
    ObjectRecord, PropertyObject, ReadBackObject: IInterface;
  PropertyName: string;
  i: Integer;
begin
  ServiceQuest := DefinedRecordByObjectID(TargetFile, $000800);
  if not Assigned(ServiceQuest) or (Signature(ServiceQuest) <> 'QUST') or
    (GetElementEditValues(ServiceQuest, 'EDID') <>
      'DNT_WizardTravelQuest') then
    raise Exception.Create('Could not resolve DNT_WizardTravelQuest');
  ObjectRecord := RequireSkyrimRecord(
    ObjectFormID,
    ExpectedSignature,
    ObjectEditorID
  );

  TargetVMAD := ElementByPath(ServiceQuest, 'VMAD');
  Scripts := ElementByPath(TargetVMAD, 'Scripts');
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
    raise Exception.Create('DNT_WizardTravelService is not bound to its quest');

  Properties := ElementByPath(ScriptEntry, 'Properties');
  if not Assigned(Properties) then
    raise Exception.Create('Wizard travel service has no properties');
  PropertyEntry := nil;
  for i := 0 to Pred(ElementCount(Properties)) do begin
    PropertyName := GetElementEditValues(
      ElementByIndex(Properties, i),
      'propertyName'
    );
    if PropertyName = PropertyNameValue then begin
      PropertyEntry := ElementByIndex(Properties, i);
      Break;
    end;
  end;
  if not Assigned(PropertyEntry) then begin
    PropertyEntry := ElementAssign(Properties, HighInteger, nil, False);
    if not Assigned(PropertyEntry) then
      raise Exception.Create(
        'Could not create ' + PropertyNameValue + ' property'
      );
    SetElementEditValues(PropertyEntry, 'propertyName', PropertyNameValue);
    SetElementEditValues(PropertyEntry, 'Type', 'Object');
  end;

  SetElementEditValues(PropertyEntry, 'Type', 'Object');
  PropertyObject := ElementByPath(
    PropertyEntry,
    'Value\Object Union\Object v2\FormID'
  );
  if not Assigned(PropertyObject) then
    raise Exception.Create(PropertyNameValue + ' has no object value');
  SetEditValue(PropertyObject, Name(ObjectRecord));
  ReadBackObject := LinksTo(PropertyObject);
  if not Assigned(ReadBackObject) or
    (FormID(ReadBackObject) <> FormID(ObjectRecord)) then
    raise Exception.Create(PropertyNameValue + ' did not read back');

  AddMessage(
    '[DNT] DNT_WizardTravelService ' + PropertyNameValue + ' -> ' +
    ObjectEditorID + ' [' + ExpectedSignature + ':' +
    IntToHex(ObjectFormID, 8) + ']'
  );
end;

procedure ConfigureDirectRoute(
  RootObjectID: Cardinal;
  const RootEditorID: string;
  DestinationObjectID: Cardinal;
  const DestinationEditorID, PromptText, ResponseText, DestinationID,
    SharedPluginName: string;
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
    SharedPluginName,
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
  SetFragmentDestinationID(RootInfo, RootEditorID, DestinationID);
  ValidateFragmentProperties(
    RootInfo,
    RootEditorID,
    DestinationID
  );
  AddPlayerGoldCondition(RootInfo, True);

  AddMessage(
    '[DNT] ' + RootEditorID + ' -> ' + DestinationID +
    '; voiced shared response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureTravelInfo(
  InfoObjectID: Cardinal;
  const InfoEditorID, PromptText, ResponseText, DestinationID,
    SharedPluginName: string;
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
    SharedPluginName,
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
  SetFragmentDestinationID(InfoRecord, InfoEditorID, DestinationID);
  ValidateFragmentProperties(
    InfoRecord,
    InfoEditorID,
    DestinationID
  );
  ConfigureCollegeFacultySpeaker(InfoRecord, True);
  AddPlayerGoldCondition(InfoRecord, True);

  AddMessage(
    '[DNT] ' + InfoEditorID + ' -> ' + DestinationID +
    '; voiced faculty response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureMirabelleTravelInfo(
  TemplateObjectID: Cardinal;
  const TemplateEditorID: string;
  InfoObjectID: Cardinal;
  const InfoEditorID, PromptText, DestinationID: string
);
const
  ResponseText = 'Of course.';
var
  TemplateInfo, InfoRecord, Mirabelle, Links: IInterface;
  ReadBackFlags: Cardinal;
begin
  InfoRecord := DefinedRecordByObjectID(TargetFile, InfoObjectID);
  if not Assigned(InfoRecord) then begin
    TemplateInfo := RequireInfo(TemplateObjectID, TemplateEditorID);
    InfoRecord := wbCopyElementToFile(
      TemplateInfo,
      TargetFile,
      True,
      True
    );
    if not Assigned(InfoRecord) then
      raise Exception.Create(
        'Could not create Mirabelle INFO ' + InfoEditorID
      );
    if (FormID(InfoRecord) and $00FFFFFF) <> InfoObjectID then
      raise Exception.Create(
        InfoEditorID + ' received object ID ' +
        IntToHex(FormID(InfoRecord) and $00FFFFFF, 6) +
        ', expected ' + IntToHex(InfoObjectID, 6)
      );
    SetElementEditValues(InfoRecord, 'EDID', InfoEditorID);
  end;

  if Signature(InfoRecord) <> 'INFO' then
    raise Exception.Create(InfoEditorID + ' is not an INFO');
  if GetElementEditValues(InfoRecord, 'EDID') <> InfoEditorID then
    raise Exception.Create(
      IntToHex(InfoObjectID, 6) + ' is not ' + InfoEditorID
    );

  SetElementEditValues(InfoRecord, 'RNAM', PromptText);
  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) then
    RemoveElement(InfoRecord, 'Link To');
  ConfigureOwnedResponse(
    InfoRecord,
    InfoEditorID,
    ResponseText,
    $000C819B
  );
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    SilentDirectResponseFlagsMask
  );
  ReadBackFlags := GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> SilentDirectResponseFlagsMask then
    raise Exception.Create(
      InfoEditorID + ' response flags did not read back'
    );

  Mirabelle := RequireSkyrimRecord(
    $0001C1A0,
    'NPC_',
    'MirabelleErvine'
  );
  ConfigureExactSpeaker(InfoRecord, Mirabelle);
  AddPlayerGoldCondition(InfoRecord, True);
  SetFragmentDestinationID(InfoRecord, InfoEditorID, DestinationID);
  ValidateFragmentProperties(
    InfoRecord,
    InfoEditorID,
    DestinationID
  );

  AddMessage(
    '[DNT] ' + InfoEditorID + ' -> ' + DestinationID +
    '; Mirabelle subtitle response; OnBegin fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureDirectDenial(
  InfoObjectID: Cardinal;
  const InfoEditorID, PromptText, ResponseText, DestinationID,
    SharedPluginName: string;
  SharedInfoFormID, SharedInfoTopicFormID: Cardinal;
  SpeakerRecord: IInterface;
  UseOwnedResponse: Boolean
);
var
  InfoRecord, Links: IInterface;
  ReadBackFlags, ExpectedFlags: Cardinal;
begin
  InfoRecord := RequireInfo(InfoObjectID, InfoEditorID);
  SetElementEditValues(InfoRecord, 'RNAM', PromptText);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(InfoEditorID + ' denial prompt did not read back');

  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) then
    RemoveElement(InfoRecord, 'Link To');
  ConfigureExactSpeaker(InfoRecord, SpeakerRecord);
  if UseOwnedResponse then begin
    ConfigureOwnedResponse(
      InfoRecord,
      InfoEditorID,
      ResponseText,
      $000C819B
    );
    ExpectedFlags := SilentDirectResponseFlagsMask;
  end else begin
    ConfigureSharedResponse(
      InfoRecord,
      InfoEditorID,
      ResponseText,
      SharedPluginName,
      SharedInfoFormID,
      SharedInfoTopicFormID
    );
    ExpectedFlags := DirectResponseFlagsMask;
  end;
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    ExpectedFlags
  );
  ReadBackFlags := GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> ExpectedFlags then
    raise Exception.Create(InfoEditorID + ' denial flags did not read back');

  SetElementNativeValues(
    ElementByPath(InfoRecord, 'VMAD'),
    'Script Fragments\Flags',
    OnBeginFragmentMask
  );
  SetFragmentDestinationID(InfoRecord, InfoEditorID, DestinationID);
  ValidateFragmentProperties(InfoRecord, InfoEditorID, DestinationID);
  AddPlayerGoldCondition(InfoRecord, False);

  AddMessage(
    '[DNT] ' + InfoEditorID + ' insufficient-funds response; ' +
    'authoritative service denial fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure ConfigureFacultyDenial(
  InfoObjectID: Cardinal;
  const InfoEditorID, PromptText, DestinationID: string
);
const
  DenialResponse = 'I''m sorry, but you can''t afford that right now.';
var
  InfoRecord, Links: IInterface;
  ReadBackFlags: Cardinal;
begin
  InfoRecord := RequireInfo(InfoObjectID, InfoEditorID);
  SetElementEditValues(InfoRecord, 'RNAM', PromptText);
  if GetElementEditValues(InfoRecord, 'RNAM') <> PromptText then
    raise Exception.Create(InfoEditorID + ' denial prompt did not read back');
  Links := ElementByPath(InfoRecord, 'Link To');
  if Assigned(Links) then
    RemoveElement(InfoRecord, 'Link To');
  ConfigureOwnedResponse(
    InfoRecord,
    InfoEditorID,
    DenialResponse,
    $000C819B
  );
  SetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags',
    SilentDirectResponseFlagsMask
  );
  ReadBackFlags := GetElementNativeValues(
    InfoRecord,
    'ENAM\Response Flags'
  );
  if ReadBackFlags <> SilentDirectResponseFlagsMask then
    raise Exception.Create(InfoEditorID + ' denial flags did not read back');

  SetElementNativeValues(
    ElementByPath(InfoRecord, 'VMAD'),
    'Script Fragments\Flags',
    OnBeginFragmentMask
  );
  SetFragmentDestinationID(InfoRecord, InfoEditorID, DestinationID);
  ValidateFragmentProperties(InfoRecord, InfoEditorID, DestinationID);
  ConfigureCollegeFacultySpeaker(InfoRecord, False);
  AddPlayerGoldCondition(InfoRecord, False);

  AddMessage(
    '[DNT] ' + InfoEditorID + ' faculty insufficient-funds subtitle; ' +
    'authoritative service denial fragment; flags=0x' +
    IntToHex(ReadBackFlags, 4)
  );
end;

procedure UpdateDestinationTopicCount(
  TopicObjectID: Cardinal;
  const TopicEditorID: string
);
var
  TopicRecord, InfoGroup: IInterface;
begin
  TopicRecord := RequireTopic(TopicObjectID, TopicEditorID);
  InfoGroup := ChildGroup(TopicRecord);
  if not Assigned(InfoGroup) or (ElementCount(InfoGroup) <> 3) then
    raise Exception.Create(
      TopicEditorID + ' must contain exactly three terminal INFO records'
    );
  SetElementNativeValues(TopicRecord, 'TIFC', ElementCount(InfoGroup));
  if GetElementNativeValues(TopicRecord, 'TIFC') <> 3 then
    raise Exception.Create(TopicEditorID + ' TIFC did not read back as 3');
end;

procedure ConfigureHubMenu;
const
  HubPrompt = 'Can you teleport me somewhere? (250 gold per trip)';
  HubResponse = 'Where do you need to go?';
var
  HubInfo, WhiterunTopic, RiftenTopic, SolitudeTopic, WindhelmTopic,
    MarkarthTopic, DawnstarTopic, MorthalTopic, TargetLinks, FirstLink,
    SecondLink, ThirdLink, FourthLink, FifthLink, SixthLink,
    SeventhLink: IInterface;
  ReadBackFlags: Cardinal;
begin
  HubInfo := RequireInfo($000808, 'DNT_WG_Request_Phinis');
  WhiterunTopic := RequireTopic($000803, 'DNT_WG_ToWhiterun');
  RiftenTopic := RequireTopic($000804, 'DNT_WG_ToRiften');
  SolitudeTopic := RequireTopic($00080F, 'DNT_WG_ToSolitude');
  WindhelmTopic := RequireTopic($000813, 'DNT_WG_ToWindhelm');
  MarkarthTopic := RequireTopic($000817, 'DNT_WG_ToMarkarth');
  DawnstarTopic := RequireTopic($000825, 'DNT_WG_ToDawnstar');
  MorthalTopic := RequireTopic($000828, 'DNT_WG_ToMorthal');

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
  ConfigureCollegeFacultySpeaker(HubInfo, False);

  TargetLinks := ElementByPath(HubInfo, 'Link To');
  if not Assigned(TargetLinks) or (ElementCount(TargetLinks) < 1) then
    raise Exception.Create('Phinis hub has no reusable Link To entry');
  while ElementCount(TargetLinks) > 7 do
    RemoveElement(TargetLinks, Pred(ElementCount(TargetLinks)));
  while ElementCount(TargetLinks) < 7 do begin
    SeventhLink := ElementAssign(
      TargetLinks,
      HighInteger,
      ElementByIndex(TargetLinks, 0),
      False
    );
    if not Assigned(SeventhLink) then
      raise Exception.Create('Could not extend Phinis hub links');
  end;

  FirstLink := ElementByIndex(TargetLinks, 0);
  SecondLink := ElementByIndex(TargetLinks, 1);
  ThirdLink := ElementByIndex(TargetLinks, 2);
  FourthLink := ElementByIndex(TargetLinks, 3);
  FifthLink := ElementByIndex(TargetLinks, 4);
  SixthLink := ElementByIndex(TargetLinks, 5);
  SeventhLink := ElementByIndex(TargetLinks, 6);

  SetEditValue(FirstLink, Name(WhiterunTopic));
  SetEditValue(SecondLink, Name(RiftenTopic));
  SetEditValue(ThirdLink, Name(SolitudeTopic));
  SetEditValue(FourthLink, Name(WindhelmTopic));
  SetEditValue(FifthLink, Name(MarkarthTopic));
  SetEditValue(SixthLink, Name(DawnstarTopic));
  SetEditValue(SeventhLink, Name(MorthalTopic));

  TargetLinks := ElementByPath(HubInfo, 'Link To');
  if not Assigned(TargetLinks) or (ElementCount(TargetLinks) <> 7) then
    raise Exception.Create(
      'Phinis hub does not have exactly seven Link To entries'
    );
  FirstLink := LinksTo(ElementByIndex(TargetLinks, 0));
  SecondLink := LinksTo(ElementByIndex(TargetLinks, 1));
  ThirdLink := LinksTo(ElementByIndex(TargetLinks, 2));
  FourthLink := LinksTo(ElementByIndex(TargetLinks, 3));
  FifthLink := LinksTo(ElementByIndex(TargetLinks, 4));
  SixthLink := LinksTo(ElementByIndex(TargetLinks, 5));
  SeventhLink := LinksTo(ElementByIndex(TargetLinks, 6));
  if not Assigned(FirstLink) or
    (FormID(FirstLink) <> FormID(WhiterunTopic)) then
    raise Exception.Create('Phinis first hub link is not Whiterun');
  if not Assigned(SecondLink) or
    (FormID(SecondLink) <> FormID(RiftenTopic)) then
    raise Exception.Create('Phinis second hub link is not Riften');
  if not Assigned(ThirdLink) or
    (FormID(ThirdLink) <> FormID(SolitudeTopic)) then
    raise Exception.Create('Phinis third hub link is not Solitude');
  if not Assigned(FourthLink) or
    (FormID(FourthLink) <> FormID(WindhelmTopic)) then
    raise Exception.Create('Phinis fourth hub link is not Windhelm');
  if not Assigned(FifthLink) or
    (FormID(FifthLink) <> FormID(MarkarthTopic)) then
    raise Exception.Create('Phinis fifth hub link is not Markarth');
  if not Assigned(SixthLink) or
    (FormID(SixthLink) <> FormID(DawnstarTopic)) then
    raise Exception.Create('Phinis sixth hub link is not Dawnstar');
  if not Assigned(SeventhLink) or
    (FormID(SeventhLink) <> FormID(MorthalTopic)) then
    raise Exception.Create('Phinis seventh hub link is not Morthal');

  AddMessage(
    '[DNT] DNT_WG_Request_Phinis faculty hub -> ' +
    'whiterun,riften,solitude,windhelm,markarth,dawnstar,morthal; ' +
    'owned unvoiced response; rank>=3; flags=0x' +
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
var
  FarengarRoot, WylandriahRoot, SybilleRoot, WuunferthRoot, CalcelmoRoot,
    MadenaRoot, FalionRoot, Farengar, Wylandriah, Sybille, Wuunferth,
    Calcelmo, Madena, Falion: IInterface;
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

    EnsureDestinationTopic(
      $00080F,
      'DNT_WG_ToSolitude',
      'Solitude',
      $000810,
      'DNT_WG_Solitude_FromPhinis',
      $000811,
      'DNT_WG_Solitude_FromMirabelle'
    );
    SybilleRoot := EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $000812,
      'DNT_WG_Request_Sybille'
    );
    EnsureDestinationTopic(
      $000813,
      'DNT_WG_ToWindhelm',
      'Windhelm',
      $000814,
      'DNT_WG_Windhelm_FromPhinis',
      $000815,
      'DNT_WG_Windhelm_FromMirabelle'
    );
    WuunferthRoot := EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $000816,
      'DNT_WG_Request_Wuunferth'
    );
    EnsureDestinationTopic(
      $000817,
      'DNT_WG_ToMarkarth',
      'Markarth',
      $000818,
      'DNT_WG_Markarth_FromPhinis',
      $000819,
      'DNT_WG_Markarth_FromMirabelle'
    );
    CalcelmoRoot := EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00081A,
      'DNT_WG_Request_Calcelmo'
    );
    EnsureDestinationTopic(
      $000825,
      'DNT_WG_ToDawnstar',
      'Dawnstar',
      $000826,
      'DNT_WG_Dawnstar_FromPhinis',
      $000827,
      'DNT_WG_Dawnstar_FromMirabelle'
    );
    EnsureDestinationTopic(
      $000828,
      'DNT_WG_ToMorthal',
      'Morthal',
      $000829,
      'DNT_WG_Morthal_FromPhinis',
      $00082A,
      'DNT_WG_Morthal_FromMirabelle'
    );
    MadenaRoot := EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00082B,
      'DNT_WG_Request_Madena'
    );
    FalionRoot := EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00082C,
      'DNT_WG_Request_Falion'
    );
    EnsureClonedInfo(
      $000806,
      'DNT_WG_Request_Farengar',
      $00081B,
      'DNT_WG_Request_Farengar_NoGold'
    );
    EnsureClonedInfo(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00081C,
      'DNT_WG_Request_Wylandriah_NoGold'
    );
    EnsureClonedInfo(
      $000812,
      'DNT_WG_Request_Sybille',
      $00081D,
      'DNT_WG_Request_Sybille_NoGold'
    );
    EnsureClonedInfo(
      $000816,
      'DNT_WG_Request_Wuunferth',
      $00081E,
      'DNT_WG_Request_Wuunferth_NoGold'
    );
    EnsureClonedInfo(
      $00081A,
      'DNT_WG_Request_Calcelmo',
      $00081F,
      'DNT_WG_Request_Calcelmo_NoGold'
    );
    EnsureClonedInfo(
      $00082B,
      'DNT_WG_Request_Madena',
      $00082D,
      'DNT_WG_Request_Madena_NoGold'
    );
    EnsureClonedInfo(
      $00082C,
      'DNT_WG_Request_Falion',
      $00082E,
      'DNT_WG_Request_Falion_NoGold'
    );
    EnsureClonedInfo(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      $000820,
      'DNT_WG_Whiterun_NoGold'
    );
    EnsureClonedInfo(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      $000821,
      'DNT_WG_Riften_NoGold'
    );
    EnsureClonedInfo(
      $000810,
      'DNT_WG_Solitude_FromPhinis',
      $000822,
      'DNT_WG_Solitude_NoGold'
    );
    EnsureClonedInfo(
      $000814,
      'DNT_WG_Windhelm_FromPhinis',
      $000823,
      'DNT_WG_Windhelm_NoGold'
    );
    EnsureClonedInfo(
      $000818,
      'DNT_WG_Markarth_FromPhinis',
      $000824,
      'DNT_WG_Markarth_NoGold'
    );
    EnsureClonedInfo(
      $000826,
      'DNT_WG_Dawnstar_FromPhinis',
      $00082F,
      'DNT_WG_Dawnstar_NoGold'
    );
    EnsureClonedInfo(
      $000829,
      'DNT_WG_Morthal_FromPhinis',
      $000830,
      'DNT_WG_Morthal_NoGold'
    );
    ConfigureServiceObjectProperty(
      'FarePaymentSound',
      $000334AB,
      'SOUN',
      'ITMGoldDown'
    );
    ConfigureServiceObjectProperty(
      'CollegeMarker',
      $00046BDF,
      'REFR',
      'WinterholdCollegeMapMarkerRef'
    );
    ConfigureServiceObjectProperty(
      'SolitudeMarker',
      $0002C194,
      'REFR',
      'BluePalaceAudienceMarker'
    );
    ConfigureServiceObjectProperty(
      'WindhelmMarker',
      $000A3F1C,
      'REFR',
      'WindhelmWuunferthLabMarker'
    );
    ConfigureServiceObjectProperty(
      'MarkarthMarker',
      $0003692A,
      'REFR',
      'MarkarthCastleWizardVendorMarkerREF'
    );
    ConfigureServiceObjectProperty(
      'DawnstarMarker',
      $000877B4,
      'REFR',
      'MadenaServiceMarkerREF'
    );
    ConfigureServiceObjectProperty(
      'MorthalMarker',
      $000EB7CC,
      'REFR',
      'MorthalCarriageEastDestinationMarker'
    );
    ConfigureHubMenu;
    FarengarRoot := RequireInfo($000806, 'DNT_WG_Request_Farengar');
    Farengar := RequireSkyrimRecord(
      $00013BBB,
      'NPC_',
      'FarengarSecretFire'
    );
    ConfigureExactSpeaker(FarengarRoot, Farengar);
    ConfigureDirectRoute(
      $000806,
      'DNT_WG_Request_Farengar',
      $000809,
      'DNT_WG_College_FromFarengar',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Yes.',
      'college',
      'Skyrim.esm',
      $000730FA,
      $00035B52
    );
    WylandriahRoot := RequireInfo($000807, 'DNT_WG_Request_Wylandriah');
    Wylandriah := RequireSkyrimRecord(
      $00019DEF,
      'NPC_',
      'Wylandriah'
    );
    ConfigureExactSpeaker(WylandriahRoot, Wylandriah);
    ConfigureDirectRoute(
      $000807,
      'DNT_WG_Request_Wylandriah',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    Sybille := RequireSkyrimRecord(
      $000132AA,
      'NPC_',
      'SybilleStentor'
    );
    ConfigureExactSpeaker(SybilleRoot, Sybille);
    ConfigureDirectRoute(
      $000812,
      'DNT_WG_Request_Sybille',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    Wuunferth := RequireSkyrimRecord(
      $00014146,
      'NPC_',
      'Wuunferth'
    );
    ConfigureExactSpeaker(WuunferthRoot, Wuunferth);
    ConfigureDirectRoute(
      $000816,
      'DNT_WG_Request_Wuunferth',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    Calcelmo := RequireSkyrimRecord(
      $0001338E,
      'NPC_',
      'Calcelmo'
    );
    ConfigureExactSpeaker(CalcelmoRoot, Calcelmo);
    ConfigureDirectRoute(
      $00081A,
      'DNT_WG_Request_Calcelmo',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    Madena := RequireSkyrimRecord(
      $0001361D,
      'NPC_',
      'Madena'
    );
    ConfigureExactSpeaker(MadenaRoot, Madena);
    ConfigureDirectRoute(
      $00082B,
      'DNT_WG_Request_Madena',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    Falion := RequireSkyrimRecord(
      $000135E9,
      'NPC_',
      'Falion'
    );
    ConfigureExactSpeaker(FalionRoot, Falion);
    ConfigureDirectRoute(
      $00082C,
      'DNT_WG_Request_Falion',
      $00080A,
      'DNT_WG_College_FromWylandriah',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'Of course.',
      'college',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureDirectDenial(
      $00081B,
      'DNT_WG_Request_Farengar_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you don''t seem to have enough gold to pay for that.',
      'college',
      'Skyrim.esm',
      $000C6E2D,
      $000C6E04,
      Farengar,
      False
    );
    ConfigureDirectDenial(
      $00081C,
      'DNT_WG_Request_Wylandriah_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you don''t seem to have enough gold to pay for that.',
      'college',
      'Skyrim.esm',
      $000C6E2D,
      $000C6E04,
      Wylandriah,
      False
    );
    ConfigureDirectDenial(
      $00081D,
      'DNT_WG_Request_Sybille_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you can''t afford that right now.',
      'college',
      'HearthFires.esm',
      $0000B0B2,
      $00007016,
      Sybille,
      False
    );
    ConfigureDirectDenial(
      $00081E,
      'DNT_WG_Request_Wuunferth_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you can''t afford that right now.',
      'college',
      'Skyrim.esm',
      $00000000,
      $00000000,
      Wuunferth,
      True
    );
    ConfigureDirectDenial(
      $00081F,
      'DNT_WG_Request_Calcelmo_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you don''t seem to have enough gold to pay for that.',
      'college',
      'Skyrim.esm',
      $000C6E2D,
      $000C6E04,
      Calcelmo,
      False
    );
    ConfigureDirectDenial(
      $00082D,
      'DNT_WG_Request_Madena_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'I''m sorry, but you don''t seem to have enough gold to pay for that.',
      'college',
      'Skyrim.esm',
      $000C6E2D,
      $000C6E04,
      Madena,
      False
    );
    ConfigureDirectDenial(
      $00082E,
      'DNT_WG_Request_Falion_NoGold',
      'Can you teleport me to the College of Winterhold? (250 gold)',
      'It can''t be helped.',
      'college',
      'Skyrim.esm',
      $000DBA24,
      $0001F319,
      Falion,
      False
    );
    ConfigureTravelInfo(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      'Send me to Whiterun. (250 gold)',
      'Of course.',
      'whiterun',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureTravelInfo(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      'Send me to Riften. (250 gold)',
      'Of course.',
      'riften',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $00080B,
      'DNT_WG_Whiterun_FromPhinis',
      $00080D,
      'DNT_WG_Whiterun_FromMirabelle',
      'Send me to Whiterun. (250 gold)',
      'whiterun'
    );
    ConfigureMirabelleTravelInfo(
      $00080C,
      'DNT_WG_Riften_FromPhinis',
      $00080E,
      'DNT_WG_Riften_FromMirabelle',
      'Send me to Riften. (250 gold)',
      'riften'
    );
    ConfigureTravelInfo(
      $000810,
      'DNT_WG_Solitude_FromPhinis',
      'Send me to Solitude. (250 gold)',
      'Of course.',
      'solitude',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $000810,
      'DNT_WG_Solitude_FromPhinis',
      $000811,
      'DNT_WG_Solitude_FromMirabelle',
      'Send me to Solitude. (250 gold)',
      'solitude'
    );
    ConfigureTravelInfo(
      $000814,
      'DNT_WG_Windhelm_FromPhinis',
      'Send me to Windhelm. (250 gold)',
      'Of course.',
      'windhelm',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $000814,
      'DNT_WG_Windhelm_FromPhinis',
      $000815,
      'DNT_WG_Windhelm_FromMirabelle',
      'Send me to Windhelm. (250 gold)',
      'windhelm'
    );
    ConfigureTravelInfo(
      $000818,
      'DNT_WG_Markarth_FromPhinis',
      'Send me to Markarth. (250 gold)',
      'Of course.',
      'markarth',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $000818,
      'DNT_WG_Markarth_FromPhinis',
      $000819,
      'DNT_WG_Markarth_FromMirabelle',
      'Send me to Markarth. (250 gold)',
      'markarth'
    );
    ConfigureTravelInfo(
      $000826,
      'DNT_WG_Dawnstar_FromPhinis',
      'Send me to Dawnstar. (250 gold)',
      'Of course.',
      'dawnstar',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $000826,
      'DNT_WG_Dawnstar_FromPhinis',
      $000827,
      'DNT_WG_Dawnstar_FromMirabelle',
      'Send me to Dawnstar. (250 gold)',
      'dawnstar'
    );
    ConfigureTravelInfo(
      $000829,
      'DNT_WG_Morthal_FromPhinis',
      'Send me to Morthal. (250 gold)',
      'Of course.',
      'morthal',
      'Skyrim.esm',
      $000DBA22,
      $0001F319
    );
    ConfigureMirabelleTravelInfo(
      $000829,
      'DNT_WG_Morthal_FromPhinis',
      $00082A,
      'DNT_WG_Morthal_FromMirabelle',
      'Send me to Morthal. (250 gold)',
      'morthal'
    );
    ConfigureFacultyDenial(
      $000820,
      'DNT_WG_Whiterun_NoGold',
      'Send me to Whiterun. (250 gold)',
      'whiterun'
    );
    ConfigureFacultyDenial(
      $000821,
      'DNT_WG_Riften_NoGold',
      'Send me to Riften. (250 gold)',
      'riften'
    );
    ConfigureFacultyDenial(
      $000822,
      'DNT_WG_Solitude_NoGold',
      'Send me to Solitude. (250 gold)',
      'solitude'
    );
    ConfigureFacultyDenial(
      $000823,
      'DNT_WG_Windhelm_NoGold',
      'Send me to Windhelm. (250 gold)',
      'windhelm'
    );
    ConfigureFacultyDenial(
      $000824,
      'DNT_WG_Markarth_NoGold',
      'Send me to Markarth. (250 gold)',
      'markarth'
    );
    ConfigureFacultyDenial(
      $00082F,
      'DNT_WG_Dawnstar_NoGold',
      'Send me to Dawnstar. (250 gold)',
      'dawnstar'
    );
    ConfigureFacultyDenial(
      $000830,
      'DNT_WG_Morthal_NoGold',
      'Send me to Morthal. (250 gold)',
      'morthal'
    );
    UpdateDestinationTopicCount($000803, 'DNT_WG_ToWhiterun');
    UpdateDestinationTopicCount($000804, 'DNT_WG_ToRiften');
    UpdateDestinationTopicCount($00080F, 'DNT_WG_ToSolitude');
    UpdateDestinationTopicCount($000813, 'DNT_WG_ToWindhelm');
    UpdateDestinationTopicCount($000817, 'DNT_WG_ToMarkarth');
    UpdateDestinationTopicCount($000825, 'DNT_WG_ToDawnstar');
    UpdateDestinationTopicCount($000828, 'DNT_WG_ToMorthal');

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
