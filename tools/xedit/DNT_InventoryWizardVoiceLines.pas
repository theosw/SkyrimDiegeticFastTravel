{
  Read-only inventory of short vanilla response lines explicitly associated
  with the three wizard-guide actors.  The report is intentionally compact:
  voice type plus plausible acknowledgement/farewell donors that can be used
  through INFO Shared Response Data.
}
unit DNT_InventoryWizardVoiceLines;

var
  SkyrimFile: IInterface;
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

function RecordBySkyrimFormID(FormIDValue: Cardinal): IInterface;
begin
  Result := RecordByFormID(SkyrimFile, FormIDValue, True);
end;

function IsActorReference(
  ElementValue: IInterface;
  ActorFormID: Cardinal
): Boolean;
var
  Target: IInterface;
begin
  Result := False;
  if not Assigned(ElementValue) then
    Exit;
  Target := LinksTo(ElementValue);
  Result := Assigned(Target) and (FormID(Target) = ActorFormID);
end;

function InfoTargetsActor(
  InfoRecord: IInterface;
  ActorFormID: Cardinal
): Boolean;
var
  Conditions, ConditionEntry: IInterface;
  i: Integer;
begin
  Result := IsActorReference(
    ElementByPath(InfoRecord, 'ANAM'),
    ActorFormID
  );
  if Result then
    Exit;

  Conditions := ElementByPath(InfoRecord, 'Conditions');
  if not Assigned(Conditions) then
    Exit;
  for i := 0 to Pred(ElementCount(Conditions)) do begin
    ConditionEntry := ElementByIndex(Conditions, i);
    if IsActorReference(
      ElementByPath(ConditionEntry, 'CTDA\Parameter #1'),
      ActorFormID
    ) then begin
      Result := True;
      Exit;
    end;
  end;
end;

function LooksReusable(const TextValue: string): Boolean;
var
  Candidate: string;
begin
  Candidate := LowerCase(Trim(TextValue));
  Result :=
    (Length(Candidate) > 0) and
    (Length(Candidate) <= 72) and
    (
      (Pos('yes', Candidate) > 0) or
      (Pos('very well', Candidate) > 0) or
      (Pos('very good', Candidate) > 0) or
      (Pos('all right', Candidate) > 0) or
      (Pos('of course', Candidate) > 0) or
      (Pos('certainly', Candidate) > 0) or
      (Pos('farewell', Candidate) > 0) or
      (Pos('goodbye', Candidate) > 0) or
      (Pos('good-bye', Candidate) > 0) or
      (Pos('until next time', Candidate) > 0) or
      (Pos('as you wish', Candidate) > 0) or
      (Pos('what is it', Candidate) > 0) or
      (Pos('what do you need', Candidate) > 0) or
      (Pos('go on', Candidate) > 0) or
      (Candidate = 'no.') or
      (Pos('i''m sorry', Candidate) > 0) or
      (Pos('i am sorry', Candidate) > 0) or
      (Pos('i''m afraid', Candidate) > 0) or
      (Pos('i am afraid', Candidate) > 0) or
      (Pos('can''t', Candidate) > 0) or
      (Pos('cannot', Candidate) > 0) or
      (Pos('don''t have', Candidate) > 0)
    );
end;

procedure ReportInfoResponses(
  InfoRecord: IInterface;
  ActorFormID: Cardinal
);
var
  Responses, ResponseEntry: IInterface;
  TextValue, EditorIDValue: string;
  i: Integer;
begin
  if not InfoTargetsActor(InfoRecord, ActorFormID) then
    Exit;
  Responses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(Responses) then
    Exit;
  for i := 0 to Pred(ElementCount(Responses)) do begin
    ResponseEntry := ElementByIndex(Responses, i);
    TextValue := GetElementEditValues(ResponseEntry, 'NAM1');
    if not LooksReusable(TextValue) then
      Continue;
    EditorIDValue := GetElementEditValues(InfoRecord, 'EDID');
    ReportLines.Add(
      '  ' + IntToHex(FormID(InfoRecord), 8) +
      ' | ' + EditorIDValue + ' | ' + TextValue
    );
  end;
end;

procedure ReportAllReusableResponses(InfoRecord: IInterface);
var
  Responses, ResponseEntry: IInterface;
  TextValue: string;
  i: Integer;
begin
  Responses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(Responses) then
    Exit;
  for i := 0 to Pred(ElementCount(Responses)) do begin
    ResponseEntry := ElementByIndex(Responses, i);
    TextValue := GetElementEditValues(ResponseEntry, 'NAM1');
    if LooksReusable(TextValue) then
      ReportLines.Add(
        'CANDIDATE ' + IntToHex(FormID(InfoRecord), 8) +
        ' | response=' + IntToStr(Succ(i)) + ' | ' + TextValue
      );
  end;
end;

procedure ScanAllDialogue;
var
  DialGroup, DialRecord, InfoGroup, InfoRecord: IInterface;
  i, j: Integer;
begin
  DialGroup := GroupBySignature(SkyrimFile, 'DIAL');
  if not Assigned(DialGroup) then
    raise Exception.Create('Skyrim.esm has no DIAL group');
  for i := 0 to Pred(ElementCount(DialGroup)) do begin
    DialRecord := ElementByIndex(DialGroup, i);
    if Signature(DialRecord) <> 'DIAL' then
      Continue;
    InfoGroup := ChildGroup(DialRecord);
    if not Assigned(InfoGroup) then
      Continue;
    for j := 0 to Pred(ElementCount(InfoGroup)) do begin
      InfoRecord := ElementByIndex(InfoGroup, j);
      if Signature(InfoRecord) = 'INFO' then
        ReportAllReusableResponses(InfoRecord);
    end;
  end;
end;

procedure ReportVanillaLinkedSharedInfoUsage;
var
  DialGroup, DialRecord, InfoGroup, InfoRecord, Links, LinkEntry,
    LinkedTopic, SharedInfo: IInterface;
  LinkedTopicIDs: TStringList;
  i, j, k, SharedInfoCount, ExampleCount: Integer;
  TopicID: string;
begin
  DialGroup := GroupBySignature(SkyrimFile, 'DIAL');
  if not Assigned(DialGroup) then
    raise Exception.Create('Skyrim.esm has no DIAL group');

  LinkedTopicIDs := TStringList.Create;
  try
    LinkedTopicIDs.Sorted := True;
    LinkedTopicIDs.Duplicates := dupIgnore;

    for i := 0 to Pred(ElementCount(DialGroup)) do begin
      DialRecord := ElementByIndex(DialGroup, i);
      if Signature(DialRecord) <> 'DIAL' then
        Continue;
      InfoGroup := ChildGroup(DialRecord);
      if not Assigned(InfoGroup) then
        Continue;
      for j := 0 to Pred(ElementCount(InfoGroup)) do begin
        InfoRecord := ElementByIndex(InfoGroup, j);
        if Signature(InfoRecord) <> 'INFO' then
          Continue;
        Links := ElementByPath(InfoRecord, 'Link To');
        if not Assigned(Links) then
          Continue;
        for k := 0 to Pred(ElementCount(Links)) do begin
          LinkEntry := ElementByIndex(Links, k);
          LinkedTopic := LinksTo(LinkEntry);
          if Assigned(LinkedTopic) then
            LinkedTopicIDs.Add(IntToHex(FormID(LinkedTopic), 8));
        end;
      end;
    end;

    SharedInfoCount := 0;
    ExampleCount := 0;
    ReportLines.Add('VANILLA LINKED TOPICS USING SHARED RESPONSE DATA:');
    for i := 0 to Pred(ElementCount(DialGroup)) do begin
      DialRecord := ElementByIndex(DialGroup, i);
      if Signature(DialRecord) <> 'DIAL' then
        Continue;
      TopicID := IntToHex(FormID(DialRecord), 8);
      if LinkedTopicIDs.IndexOf(TopicID) < 0 then
        Continue;
      InfoGroup := ChildGroup(DialRecord);
      if not Assigned(InfoGroup) then
        Continue;
      for j := 0 to Pred(ElementCount(InfoGroup)) do begin
        InfoRecord := ElementByIndex(InfoGroup, j);
        if Signature(InfoRecord) <> 'INFO' then
          Continue;
        SharedInfo := LinksTo(ElementByPath(InfoRecord, 'DNAM'));
        if not Assigned(SharedInfo) then
          Continue;
        Inc(SharedInfoCount);
        if ExampleCount < 12 then begin
          ReportLines.Add(
            'LINKED_SHARED topic=' + Name(DialRecord) +
            ' | info=' + Name(InfoRecord) +
            ' | donor=' + Name(SharedInfo)
          );
          Inc(ExampleCount);
        end;
      end;
    end;
    ReportLines.Add(
      'VANILLA_LINKED_SHARED_COUNT=' + IntToStr(SharedInfoCount)
    );
  finally
    LinkedTopicIDs.Free;
  end;
end;

procedure ScanActorDialogue(ActorFormID: Cardinal);
var
  DialGroup, DialRecord, InfoGroup, InfoRecord: IInterface;
  i, j: Integer;
begin
  DialGroup := GroupBySignature(SkyrimFile, 'DIAL');
  if not Assigned(DialGroup) then
    raise Exception.Create('Skyrim.esm has no DIAL group');
  for i := 0 to Pred(ElementCount(DialGroup)) do begin
    DialRecord := ElementByIndex(DialGroup, i);
    if Signature(DialRecord) <> 'DIAL' then
      Continue;
    InfoGroup := ChildGroup(DialRecord);
    if not Assigned(InfoGroup) then
      Continue;
    for j := 0 to Pred(ElementCount(InfoGroup)) do begin
      InfoRecord := ElementByIndex(InfoGroup, j);
      if Signature(InfoRecord) = 'INFO' then
        ReportInfoResponses(InfoRecord, ActorFormID);
    end;
  end;
end;

procedure ReportActor(
  ActorFormID: Cardinal;
  const ExpectedEditorID: string
);
var
  ActorRecord, VoiceType: IInterface;
begin
  ActorRecord := RecordBySkyrimFormID(ActorFormID);
  if not Assigned(ActorRecord) or (Signature(ActorRecord) <> 'NPC_') then
    raise Exception.Create(
      'Could not resolve actor ' + IntToHex(ActorFormID, 8)
    );
  if GetElementEditValues(ActorRecord, 'EDID') <> ExpectedEditorID then
    raise Exception.Create(
      IntToHex(ActorFormID, 8) + ' is not ' + ExpectedEditorID
    );
  VoiceType := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  if not Assigned(VoiceType) then
    raise Exception.Create(ExpectedEditorID + ' has no voice type');

  ReportLines.Add(
    ExpectedEditorID + ' | voice=' +
    GetElementEditValues(VoiceType, 'EDID') + ' | candidates:'
  );
  ScanActorDialogue(ActorFormID);
end;

procedure ReportDonorDetails(
  DonorFormID: Cardinal;
  const LabelText: string
);
var
  Donor, ResponseRecord: IInterface;
begin
  Donor := RecordBySkyrimFormID(DonorFormID);
  if not Assigned(Donor) or (Signature(Donor) <> 'INFO') then
    raise Exception.Create(
      'Could not resolve donor ' + IntToHex(DonorFormID, 8)
    );
  ResponseRecord := ElementByPath(Donor, 'Responses\Response');
  if not Assigned(ResponseRecord) then
    raise Exception.Create(
      'Donor has no response: ' + IntToHex(DonorFormID, 8)
    );
  ReportLines.Add(
    'DONOR ' + LabelText +
    ' | ' + IntToHex(DonorFormID, 8) +
    ' | record=' + Name(Donor) +
    ' | text=' + GetElementEditValues(ResponseRecord, 'NAM1') +
    ' | infoFlags=' + IntToStr(
      GetElementNativeValues(Donor, 'ENAM\Response Flags')
    ) +
    ' | emotion=' + GetElementEditValues(
      ResponseRecord,
      'TRDT\Emotion'
    ) +
    ' | emotionValue=' + IntToStr(
      GetElementNativeValues(ResponseRecord, 'TRDT\Emotion Value')
    ) +
    ' | responseNumber=' + IntToStr(
      GetElementNativeValues(ResponseRecord, 'TRDT\Response number')
    ) +
    ' | sound=' + GetElementEditValues(ResponseRecord, 'TRDT\Sound') +
    ' | snam=' + GetElementEditValues(ResponseRecord, 'SNAM') +
    ' | lnam=' + GetElementEditValues(ResponseRecord, 'LNAM')
  );
end;

function Initialize: Integer;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\wizard-voice-inventory.status';
  ErrorPath :=
    ScriptsPath + '..\..\build\wizard-voice-inventory.error';
  ReportPath :=
    ScriptsPath + '..\..\build\wizard-voice-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    ReportActor($00013BBB, 'FarengarSecretFire');
    ReportActor($0001C199, 'PhinisGestor');
    ReportActor($00019DEF, 'Wylandriah');
    ReportActor($000135E9, 'Falion');
    ReportLines.Add('SELECTED DONOR DETAILS:');
    ReportDonorDetails($000730FA, 'Farengar Yes');
    ReportDonorDetails($000DBA22, 'Generic Of course');
    ReportDonorDetails($000DBA24, 'Generic It cannot be helped');
    ReportDonorDetails($00087940, 'Generic Yes');
    ReportDonorDetails($00079AD7, 'Favor Very well');
    ReportDonorDetails($000CD8F3, 'Goodbye Very well');
    ReportDonorDetails($000854CD, 'Generic All right then');
    ReportDonorDetails($00023C2D, 'No candidate 23C2D');
    ReportDonorDetails($00026E28, 'No candidate 26E28');
    ReportDonorDetails($0003857E, 'No candidate 3857E');
    ReportDonorDetails($00046AC8, 'No candidate 46AC8');
    ReportDonorDetails($00082A29, 'No candidate 82A29');
    ReportDonorDetails($000D669D, 'No candidate D669D');
    ReportDonorDetails($0006F435, 'Mirabelle generic unique 6F435');
    ReportDonorDetails($0006F436, 'Mirabelle generic unique 6F436');
    ReportDonorDetails($0006F437, 'Mirabelle generic unique 6F437');
    ReportDonorDetails($0006F438, 'Mirabelle generic unique 6F438');
    ReportDonorDetails($0006F44C, 'Mirabelle generic unique 6F44C');
    ReportDonorDetails($0006F44D, 'Mirabelle generic unique 6F44D');
    ReportDonorDetails($0006F44E, 'Mirabelle generic unique 6F44E');
    ReportDonorDetails($000A6802, 'Mirabelle generic unique A6802');
    ReportDonorDetails($000A6804, 'Mirabelle generic unique A6804');
    ReportDonorDetails($000A6806, 'Mirabelle generic unique A6806');
    ReportDonorDetails($000D67D1, 'Mirabelle Very good');
    ReportVanillaLinkedSharedInfoUsage;
    ReportLines.Add('ALL REUSABLE TEXT CANDIDATES:');
    ScanAllDialogue;

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
