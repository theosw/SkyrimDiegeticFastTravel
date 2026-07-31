unit DNT_InventoryCollegeGuideRoster;

uses SysUtils, Classes;

var
  SkyrimFile: IInterface;
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

function FormHex(RecordElement: IInterface): string;
begin
  Result := IntToHex(GetLoadOrderFormID(RecordElement), 8);
end;

function FindFactionByEditorID(const WantedEditorID: string): IInterface;
var
  Group, FactionRecord: IInterface;
  i: Integer;
begin
  Result := nil;
  Group := GroupBySignature(SkyrimFile, 'FACT');
  if not Assigned(Group) then
    Exit;

  for i := 0 to Pred(ElementCount(Group)) do begin
    FactionRecord := ElementByIndex(Group, i);
    if GetElementEditValues(FactionRecord, 'EDID') = WantedEditorID then begin
      Result := FactionRecord;
      Exit;
    end;
  end;
end;

procedure ReportRelatedFactions;
var
  Group, FactionRecord: IInterface;
  EditorIDValue, DisplayName: string;
  i: Integer;
begin
  ReportLines.Add('RELATED FACTIONS:');
  Group := GroupBySignature(SkyrimFile, 'FACT');
  if not Assigned(Group) then
    raise Exception.Create('Skyrim.esm has no FACT group');

  for i := 0 to Pred(ElementCount(Group)) do begin
    FactionRecord := ElementByIndex(Group, i);
    EditorIDValue := GetElementEditValues(FactionRecord, 'EDID');
    DisplayName := GetElementEditValues(FactionRecord, 'FULL');
    if
      (Pos('college', LowerCase(EditorIDValue)) > 0) or
      (Pos('winterhold', LowerCase(EditorIDValue)) > 0) or
      (Pos('college', LowerCase(DisplayName)) > 0)
    then
      ReportLines.Add(
        FormHex(FactionRecord) + ' | ' + EditorIDValue + ' | ' + DisplayName
      );
  end;
end;

function ActorFactionRank(
  ActorRecord, WantedFaction: IInterface;
  var RankValue: Integer
): Boolean;
var
  Factions, FactionEntry, FactionRecord: IInterface;
  i: Integer;
begin
  Result := False;
  RankValue := -1;
  Factions := ElementByPath(ActorRecord, 'Factions');
  if not Assigned(Factions) then
    Exit;

  for i := 0 to Pred(ElementCount(Factions)) do begin
    FactionEntry := ElementByIndex(Factions, i);
    FactionRecord := LinksTo(ElementByPath(FactionEntry, 'Faction'));
    if
      Assigned(FactionRecord) and
      (GetLoadOrderFormID(FactionRecord) = GetLoadOrderFormID(WantedFaction))
    then begin
      RankValue := GetElementNativeValues(FactionEntry, 'Rank');
      Result := True;
      Exit;
    end;
  end;
end;

function ResolveVoiceType(ActorRecord: IInterface): IInterface;
var
  TemplateRecord: IInterface;
begin
  Result := LinksTo(ElementByPath(ActorRecord, 'VTCK'));
  if Assigned(Result) then
    Exit;

  TemplateRecord := LinksTo(ElementByPath(ActorRecord, 'TPLT'));
  if Assigned(TemplateRecord) and (Signature(TemplateRecord) = 'NPC_') then
    Result := ResolveVoiceType(TemplateRecord);
end;

procedure ReportCollegeMembers(CollegeFaction: IInterface);
var
  Group, ActorRecord, VoiceType, TemplateRecord: IInterface;
  EditorIDValue, DisplayName, VoiceEditorID, TemplateText, FlagsText: string;
  i, RankValue, MemberCount: Integer;
begin
  ReportLines.Add('COLLEGE MEMBERS:');
  Group := GroupBySignature(SkyrimFile, 'NPC_');
  if not Assigned(Group) then
    raise Exception.Create('Skyrim.esm has no NPC_ group');

  MemberCount := 0;
  for i := 0 to Pred(ElementCount(Group)) do begin
    ActorRecord := ElementByIndex(Group, i);
    if not ActorFactionRank(ActorRecord, CollegeFaction, RankValue) then
      Continue;

    Inc(MemberCount);
    EditorIDValue := GetElementEditValues(ActorRecord, 'EDID');
    DisplayName := GetElementEditValues(ActorRecord, 'FULL');
    VoiceType := ResolveVoiceType(ActorRecord);
    if Assigned(VoiceType) then
      VoiceEditorID := GetElementEditValues(VoiceType, 'EDID')
    else
      VoiceEditorID := '<none>';

    TemplateRecord := LinksTo(ElementByPath(ActorRecord, 'TPLT'));
    if Assigned(TemplateRecord) then
      TemplateText := Name(TemplateRecord)
    else
      TemplateText := '<none>';
    FlagsText := GetElementEditValues(ActorRecord, 'ACBS\Flags');

    ReportLines.Add(
      FormHex(ActorRecord) +
      ' | ' + EditorIDValue +
      ' | ' + DisplayName +
      ' | rank=' + IntToStr(RankValue) +
      ' | voice=' + VoiceEditorID +
      ' | template=' + TemplateText +
      ' | flags=' + FlagsText
    );
  end;

  ReportLines.Add('COLLEGE_MEMBER_COUNT=' + IntToStr(MemberCount));
end;

function Initialize: Integer;
var
  CollegeFaction: IInterface;
begin
  Result := 1;
  StatusPath :=
    ScriptsPath + '..\..\build\college-guide-roster.status';
  ErrorPath :=
    ScriptsPath + '..\..\build\college-guide-roster.error';
  ReportPath :=
    ScriptsPath + '..\..\build\college-guide-roster.report.txt';
  WriteTextFile(StatusPath, 'running');
  ReportLines := TStringList.Create;

  try
    SkyrimFile := FileByPluginName('Skyrim.esm');
    if not Assigned(SkyrimFile) then
      raise Exception.Create('Skyrim.esm is not loaded');

    ReportRelatedFactions;
    CollegeFaction := FindFactionByEditorID('CollegeofWinterholdFaction');
    if not Assigned(CollegeFaction) then
      raise Exception.Create('CollegeofWinterholdFaction was not found');

    ReportLines.Add(
      'TARGET FACTION: ' + FormHex(CollegeFaction) + ' | ' +
      GetElementEditValues(CollegeFaction, 'EDID') + ' | ' +
      GetElementEditValues(CollegeFaction, 'FULL')
    );
    ReportCollegeMembers(CollegeFaction);

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
