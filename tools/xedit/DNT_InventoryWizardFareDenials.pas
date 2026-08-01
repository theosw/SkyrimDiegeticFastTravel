{
  Read-only inventory of vanilla Skyrim dialogue that sounds like a payment
  refusal. Genuine SharedInfo records are reported separately from ordinary
  quest dialogue so xEdit-compatible but runtime-invalid donors are never
  mistaken for reusable response data.
}
unit DNT_InventoryWizardFareDenials;

const
  MiscDialogueCategory = 7;

var
  StatusPath, ErrorPath, ReportPath: string;
  ReportLines: TStringList;
  SharedFareCount, SharedGenericCount, OrdinaryCount: Integer;

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

function ContainsAnyMoneyWord(const Candidate: string): Boolean;
begin
  Result :=
    (Pos('gold', Candidate) > 0) or
    (Pos('coin', Candidate) > 0) or
    (Pos('afford', Candidate) > 0) or
    (Pos('money', Candidate) > 0) or
    (Pos('funds', Candidate) > 0) or
    (Pos('septim', Candidate) > 0) or
    (Pos('payment', Candidate) > 0) or
    (Pos('price', Candidate) > 0) or
    (Pos('pay ', Candidate) > 0) or
    (Pos('pay.', Candidate) > 0) or
    (Pos('pay?', Candidate) > 0);
end;

function ContainsAnyDenialWord(const Candidate: string): Boolean;
begin
  Result :=
    (Pos('not enough', Candidate) > 0) or
    (Pos('no enough', Candidate) > 0) or
    (Pos('do not have', Candidate) > 0) or
    (Pos('don''t have', Candidate) > 0) or
    (Pos('don''t seem to have', Candidate) > 0) or
    (Pos('doesn''t have', Candidate) > 0) or
    (Pos('cannot', Candidate) > 0) or
    (Pos('can''t', Candidate) > 0) or
    (Pos('come back', Candidate) > 0) or
    (Pos('refuse', Candidate) > 0) or
    (Pos('won''t', Candidate) > 0) or
    (Pos('will not', Candidate) > 0) or
    (Pos('without', Candidate) > 0) or
    (Pos('short', Candidate) > 0) or
    (Pos('need more', Candidate) > 0) or
    (Pos('must pay', Candidate) > 0) or
    (Pos('have to pay', Candidate) > 0);
end;

function LooksLikeFareDenial(const TextValue: string): Boolean;
var
  Candidate: string;
begin
  Candidate := LowerCase(Trim(TextValue));
  Result :=
    (Length(Candidate) > 0) and
    (Length(Candidate) <= 180) and
    ContainsAnyMoneyWord(Candidate) and
    ContainsAnyDenialWord(Candidate);
end;

function LooksLikeGenericDenial(const TextValue: string): Boolean;
var
  Candidate: string;
begin
  Candidate := LowerCase(Trim(TextValue));
  Result :=
    (Length(Candidate) > 0) and
    (Length(Candidate) <= 96) and
    (
      (Candidate = 'no') or
      (Candidate = 'no.') or
      (Pos('no, ', Candidate) = 1) or
      (Pos('no. ', Candidate) = 1) or
      (Pos('sorry', Candidate) = 1) or
      (Pos('i''m sorry', Candidate) = 1) or
      (Pos('i am sorry', Candidate) = 1) or
      (Pos('i''m afraid', Candidate) = 1) or
      (Pos('i am afraid', Candidate) = 1) or
      (Pos('i can''t', Candidate) = 1) or
      (Pos('i cannot', Candidate) = 1) or
      (Pos('i won''t', Candidate) = 1) or
      (Pos('i will not', Candidate) = 1) or
      (Pos('i don''t think so', Candidate) = 1) or
      (Pos('absolutely not', Candidate) = 1) or
      (Pos('certainly not', Candidate) = 1) or
      (Pos('of course not', Candidate) = 1) or
      (Pos('not a chance', Candidate) = 1) or
      (Pos('no chance', Candidate) = 1) or
      (Pos('forget it', Candidate) = 1) or
      (Pos('that won''t', Candidate) = 1) or
      (Pos('that will not', Candidate) = 1) or
      (Pos('not now', Candidate) = 1) or
      (Pos('not right now', Candidate) = 1) or
      (Pos('maybe later', Candidate) = 1) or
      (Pos('another time', Candidate) = 1) or
      (Candidate = 'never') or
      (Candidate = 'never.') or
      (Pos('not possible', Candidate) > 0) or
      (Pos('out of the question', Candidate) > 0) or
      (Pos('come back later', Candidate) > 0) or
      (Pos('perhaps another time', Candidate) > 0) or
      (Pos('perhaps later', Candidate) > 0)
    );
end;

function IsGenuineSharedTopic(TopicRecord: IInterface): Boolean;
begin
  Result :=
    Assigned(TopicRecord) and
    (Signature(TopicRecord) = 'DIAL') and
    (GetElementNativeValues(TopicRecord, 'DATA\Category') =
      MiscDialogueCategory) and
    (GetElementEditValues(TopicRecord, 'SNAM') = 'SharedInfo');
end;

procedure ReportInfo(
  TopicRecord, InfoRecord: IInterface;
  const PluginName: string;
  IsShared: Boolean
);
var
  Responses, ResponseEntry: IInterface;
  TextValue, KindValue, InfoEditorID, TopicEditorID: string;
  FareLike, GenericLike: Boolean;
  i: Integer;
begin
  Responses := ElementByPath(InfoRecord, 'Responses');
  if not Assigned(Responses) then
    Exit;
  for i := 0 to Pred(ElementCount(Responses)) do begin
    ResponseEntry := ElementByIndex(Responses, i);
    TextValue := GetElementEditValues(ResponseEntry, 'NAM1');
    FareLike := LooksLikeFareDenial(TextValue);
    GenericLike := LooksLikeGenericDenial(TextValue);

    InfoEditorID := GetElementEditValues(InfoRecord, 'EDID');
    TopicEditorID := GetElementEditValues(TopicRecord, 'EDID');
    if IsShared and (Trim(InfoEditorID) <> '') and FareLike then begin
      KindValue := 'SHARED_FARE';
      Inc(SharedFareCount);
    end else if IsShared and (Trim(InfoEditorID) <> '') and GenericLike then begin
      KindValue := 'SHARED_GENERIC';
      Inc(SharedGenericCount);
    end else if FareLike then begin
      KindValue := 'ORDINARY';
      Inc(OrdinaryCount);
    end else begin
      Continue;
    end;

    ReportLines.Add(
      KindValue +
      ' | plugin=' + PluginName +
      ' | info=' + IntToHex(FormID(InfoRecord), 8) +
      ' | response=' + IntToStr(Succ(i)) +
      ' | responseCount=' + IntToStr(ElementCount(Responses)) +
      ' | infoEdid=' + InfoEditorID +
      ' | topic=' + IntToHex(FormID(TopicRecord), 8) +
      ' | topicEdid=' + TopicEditorID +
      ' | category=' + GetElementEditValues(TopicRecord, 'DATA\Category') +
      ' | subtype=' + GetElementEditValues(TopicRecord, 'SNAM') +
      ' | text=' + TextValue
    );
  end;
end;

procedure ScanDialogue(DataFile: IInterface);
var
  DialGroup, TopicRecord, InfoGroup, InfoRecord: IInterface;
  i, j: Integer;
  IsShared: Boolean;
  PluginName: string;
begin
  PluginName := GetFileName(DataFile);
  DialGroup := GroupBySignature(DataFile, 'DIAL');
  if not Assigned(DialGroup) then
    Exit;

  for i := 0 to Pred(ElementCount(DialGroup)) do begin
    TopicRecord := ElementByIndex(DialGroup, i);
    if Signature(TopicRecord) <> 'DIAL' then
      Continue;
    InfoGroup := ChildGroup(TopicRecord);
    if not Assigned(InfoGroup) then
      Continue;
    IsShared := IsGenuineSharedTopic(TopicRecord);
    for j := 0 to Pred(ElementCount(InfoGroup)) do begin
      InfoRecord := ElementByIndex(InfoGroup, j);
      if Signature(InfoRecord) = 'INFO' then
        ReportInfo(TopicRecord, InfoRecord, PluginName, IsShared);
    end;
  end;
end;

function Initialize: Integer;
var
  i: Integer;
begin
  Result := 1;
  StatusPath := ScriptsPath +
    '..\..\build\wizard-fare-denial-inventory.status';
  ErrorPath := ScriptsPath +
    '..\..\build\wizard-fare-denial-inventory.error';
  ReportPath := ScriptsPath +
    '..\..\build\wizard-fare-denial-inventory.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;
  SharedFareCount := 0;
  SharedGenericCount := 0;
  OrdinaryCount := 0;

  try
    for i := 0 to Pred(FileCount) do
      ScanDialogue(FileByIndex(i));
    ReportLines.Insert(
      0,
      'MATCH_COUNTS sharedFare=' + IntToStr(SharedFareCount) +
      ' sharedGeneric=' + IntToStr(SharedGenericCount) +
      ' ordinary=' + IntToStr(OrdinaryCount)
    );
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
