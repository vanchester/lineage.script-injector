program ScriptInjector;

{$APPTYPE CONSOLE}

uses
  ActiveX,
  Windows,
  SysUtils,
  StringListUnicodeSupport,
  Encoding,
  VBScript_RegExp_55_TLB,
  IniFiles,
  StrUtils;


function InArray(value: string; arr: array of string; var index: integer): boolean;
var
  i: integer;
begin
  Result := false;
  Index := -1;
  for i:=0 to Length(arr)-1 do
    if (arr[i] = value) then
    begin
      Index := i;
      Result := true;
      break;
    end
end;

function FullDirectoryCopy(SourceDir, TargetDir: string; StopIfNotAllCopied,
  OverWriteFiles, BackupExistsFiles: Boolean): Boolean;
var
  SR: TSearchRec;
  I: Integer;
begin
  Result := False;
  SourceDir := IncludeTrailingBackslash(SourceDir);
  TargetDir := IncludeTrailingBackslash(TargetDir);
  if not DirectoryExists(SourceDir) then
    Exit;
  if not ForceDirectories(TargetDir) then
    Exit;
  I := FindFirst(SourceDir + '*', faAnyFile, SR);
  try
    while I = 0 do
    begin
      if (SR.Name <> '') and (SR.Name <> '.') and (SR.Name <> '..') then
      begin
        if SR.Attr = faDirectory then
          Result := FullDirectoryCopy(SourceDir + SR.Name, TargetDir + SR.NAME,
            StopIfNotAllCopied, OverWriteFiles, BackupExistsFiles)
        else if not(FileExists(TargetDir + SR.Name)) OR (OverWriteFiles) then
        begin
          if (FileExists(TargetDir + ExtractFileName(SR.Name) + '.bak.htm') AND BackupExistsFiles) then
            DeleteFile(TargetDir + ExtractFileName(SR.Name) + '.bak.htm');
          if (BackupExistsFiles) then
            CopyFile(Pchar(TargetDir + ExtractFileName(SR.Name)), PChar(TargetDir + ChangeFileExt(SR.Name, '.bak.htm')), false);
          Result := CopyFile(Pchar(SourceDir + ExtractFileName(SR.Name)), Pchar(TargetDir + SR.Name), false);
        end
        else
          Result := True;
        if not Result and StopIfNotAllCopied then
          exit;
      end;
      I := FindNext(SR);
    end;
  finally
    SysUtils.FindClose(SR);
  end;
end;

var
  S, List : TStringList;
  Settings, eventdata_work, eventdata_new: TIniFile;
  workPath, newPath, param : string;
  FileList : Array of string;
  NonLinearFiles : Array [0..11] of string;
  sRec: TSearchRec;
  i, j, ii, jj, k, n : integer;
  inData, outData: TextFile;
  Line : string;
  workType, commentType, linePosition, BackupExistsFiles : integer;
  R: TRegExp;
  mc: MatchCollection;
  m: Match;
  sm: SubMatches;
  cp: TEncoding;
  LineText, LineId, LineName, LineLevel,
  LineType, LineCommentType, LineComment,
  LineOrig, LinePos, ClassName, LineParentName,
  LineChildName, LineNameType : array of AnsiString;
  //
  ParamNameOrig, ParamValueOrig, ParamNameNew,
  ParamValueNew, LinePosOrig : array of string;
  //
  LineDomainName, LineDomainText, LineDomainComment, LineDomainCommentType,
  LineDomainPos, LineDomainWorkType,
  LineTerritoryName, LineTerritoryText, LineTerritoryComment,
  LineTerritoryCommentType, LineTerritoryPos, LineTerritoryWorkType,
  LineNpcMakerName, LineNpcMakerTerritory, LineNpcMakerText,
  LineNpcMakerType, LineNpcMakerComment, LineNpcMakerCommentType,
  LineNpcMakerPos, LineNpcMakerWorkType : array of string;
  //
  LineNpcName, LineNpcText, LineNpcComment, LineNpcPos : array of array of string;
  //
  Id, Name, Value, ParentName, SkillName, Level, Comment : string;
  OutText, AddedText : TStringList;
  flag : boolean;
  //
  ClassSkill, ClassSkillName, ClassSkillComment,
  MsParamName, MsParamValue : array of array of string;
  MsLine, MsLineComment : array of array of string;

begin
  SetConsoleTitle('Script Injector v0.4b');
  WriteLn('');
  WriteLn('Script Injector by Dios v0.4b');
  WriteLn('');
  Settings := TIniFile.Create(ExtractFilePath(ParamStr(0)) + '\scriptinjector.ini');
  workPath := Settings.ReadString('main', 'WorkScriptPath', '');
  if (workPath = '') then
  begin
    WriteLn('Path of work scripts not found in ini-file!');
    exit;
  end;
  
  newPath := Settings.ReadString('main', 'NewScriptPath', ExtractFilePath(ParamStr(0)));
  BackupExistsFiles := Settings.ReadInteger('html', 'BackupExistsFiles', 1);
  if (BackupExistsFiles = 0) then
    flag := false
  else
    flag := true;

  NonLinearFiles[0] := 'setting.txt';
  NonLinearFiles[1] := 'castledata.txt';
  NonLinearFiles[2] := 'categorydata.txt';
  NonLinearFiles[4] := 'cursedweapondata.txt';
  NonLinearFiles[5] := 'eventdata.ini';
  NonLinearFiles[6] := 'multisell.txt';
  NonLinearFiles[7] := 'npcpos.txt';
  NonLinearFiles[8] := 'PC_parameter.txt';
  NonLinearFiles[9] := 'petdata.txt';
  NonLinearFiles[10] := 'skillacquire.txt';
  NonLinearFiles[11] := '';

  if FindFirst(newPath + '\*.*', faAnyFile, sRec) = 0 then
  begin
    repeat
      if (sRec.Name <> '.') AND (sRec.Name <> '..') AND (Copy(LowerCase(sRec.Name), 0, Length('scriptinjector.')) <> 'scriptinjector.')
          AND (LowerCase(sRec.Name) <> 'readme.txt') AND ((sRec.Attr AND faDirectory) <> faDirectory) then
      begin
        SetLength(FileList, Length(FileList)+1);
        FileList[Length(FileList)-1] := sRec.Name;
      end;
    until FindNext(sRec) <> 0;
    FindClose(sRec);
  end;

  if FindFirst(newPath + '\html*.*', faAnyFile, sRec) = 0 then
  begin
    repeat
      if ((sRec.Attr AND faDirectory) = faDirectory) AND (DirectoryExists(ExtractFilePath(workPath) + '\' + sRec.Name)) then
      begin
        WriteLn('HTML-directory ' + sRec.Name + ' found. Copy all files from it to work html-directory');
        FullDirectoryCopy(ExtractFilePath(newPath) + '\' + sRec.Name, ExtractFilePath(workPath) + '\' + sRec.Name, false, true, flag);
      end
    until FindNext(sRec) <> 0;
    FindClose(sRec);
  end;

  if (Length(FileList) = 0) then
  begin
    WriteLn('Data to insert not found');
    exit;
  end
  else
  begin
    WriteLn('Found files:');
    for i:=0 to Length(FileList)-1 do
      WriteLn(FileList[i]);
  end;
  for i:=0 to Length(FileList)-1 do
  begin
    WriteLn('');
    CoInitialize(nil);
    if (InArray(LowerCase(FileList[i]), NonLinearFiles, ii) = false) AND (LowerCase(ExtractFileExt(FileList[i])) <> '.obj') then
    begin
      R := TRegExp.Create(nil);
      if (FileExists(workPath + '\' + FileList[i])) then
      begin
        WriteLn('Work with ' + FileList[i]);
        workType := 0; //simple insert
        commentType := 1; //1 - comment, 0 - delete
        linePosition := 0; //0 - insert in end of file; 1 - insert in currrent position

        //clear arrays
        SetLength(LineText, 0);
        SetLength(LineId, 0);
        SetLength(LineName, 0);
        SetLength(LineLevel, 0);
        SetLength(LineType, 0);
        SetLength(LineComment, 0);
        SetLength(LineCommentType, 0);
        SetLength(LinePos, 0);
        SetLength(ParamNameNew, 0);
        SetLength(ParamValueNew, 0);
        SetLength(ParamNameOrig, 0);
        SetLength(ParamValueOrig, 0);

        S := TStringList.Create();
        cp := TEncoding.Create();
        DeleteFile(workPath + '\' + FileList[i] + '.bak');
        Line := ' Backup exists file... ';
        if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
          Line := Line + 'OK'
        else
          Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
        WriteLn(Line);

        S.LoadFromFile(newPath + '\' + FileList[i]);
        for j := 0 to S.Count-1 do
        begin
            try
              R.Pattern := '\{\$([a-zA-Z]+)[\s]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := True;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                for ii:=0 to mc.Count-1 do
                begin
                  m := mc[ii] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    if (LowerCase(sm.Item[0]) = 'w') then
                      workType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'c') then
                      commentType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'p') then
                      linePosition := StrToInt(sm.Item[1]);
                  end
                end;
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;
            k := Length(LineText);
            SetLength(LineComment, k+1);
            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Pos('_begin', S.Strings[j]) > 0) then
            begin
              SetLength(LineText, k+1);
              SetLength(LineComment, k+1);
              SetLength(LineName, k+1);
              SetLength(LineId, k+1);
              SetLength(LineLevel, k+1);
              SetLength(LineType, k+1);
              SetLength(LineCommentType, k+1);
              SetLength(LinePos, k+1);

              LineText[k] := trim(S.Strings[j]);
              LineType[k] := IntToStr(workType);
              LinePos[k] := IntToStr(linePosition);
              LineCommentType[k] := IntToStr(commentType);

              try
                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                  R.Pattern := 'skill_id[\s]*=[\s]*([\d]+)'
                else if (LowerCase(FileList[i]) = 'dyedata.txt') then
                  R.Pattern := 'dye_id[\s]*=[\s]*([\d]+)'
                else
                  R.Pattern := '[\t]([\d]+)[\t]';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                    LineId[k] := sm.Item[0];
                end;
                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                  R.Pattern := 'skill_name[\s]*=[\s]*(\[[^\]]*\])'
                else
                  R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  SetLength(LineName, k+1);
                  if (sm.Count > 0) then
                    LineName[k] := sm.Item[0];
                end;
                if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('set_begin'))) = 'set_begin') then
                  LineName[k] := '';

                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                begin
                  R.Pattern := 'level[\s]*=[\s]*([\d]+)';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                      LineLevel[k] := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;
            end
            else if (LowerCase(FileList[i]) = 'fstring.txt') OR (Pos('_pch', LowerCase(FileList[i])) > 0) then
            begin
              if (Copy(trim(S.Strings[j]), 0, 2) <> '//') then
              begin
                SetLength(LineText, k+1);
                SetLength(LineComment, k+1);
                SetLength(LineName, k+1);
                SetLength(LineId, k+1);
                SetLength(LineLevel, k+1);
                SetLength(LineType, k+1);
                SetLength(LineCommentType, k+1);
                SetLength(LinePos, k+1);

                LineText[k] := trim(S.Strings[j]);
                LineType[k] := IntToStr(workType);
                LineCommentType[k] := IntToStr(commentType);
                LinePos[k] := IntToStr(linePosition);

                try
                  if (LowerCase(FileList[i]) = 'fstring.txt') then
                    R.Pattern := '([\d]+)'
                  else if (Pos('_pch2', LowerCase(FileList[i])) > 0) then
                    R.Pattern := '^([\d]+)'
                  else
                    R.Pattern := '[\s\t=]+([\d]+)';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                      LineId[k] := sm.Item[0];
                  end;
                  R.Pattern := '(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    SetLength(LineName, k+1);
                    if (sm.Count > 0) then
                      LineName[k] := sm.Item[0];
                  end;
                finally
                  m := nil;
                  sm := nil;
                  mc := nil;
                end;
              end;
            end
            else
            begin
              if (trim(S.Strings[j]) <> '') AND (Copy(trim(S.Strings[j]), 0, 2) <> '//') then
              begin
                R.Pattern := '^[\t\s]*([a-zA-Z0-9_.]+)[\s\t]*=[\s\t]*([a-zA-Z0-9_.]+)$';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                if (mc.Count > 0) then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    ii := Length(ParamNameNew);
                    SetLength(ParamNameNew, ii+1);
                    SetLength(ParamValueNew, ii+1);

                    ParamNameNew[ii] := sm.Item[0];
                    ParamValueNew[ii] := sm.Item[1];
                  end;
                end
                else
                  LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
              end
              else
                LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
            end;
        end;
        for j := 0 to Length(LineId)-1 do
        begin
            WriteLn(' ' + LineId[j] + ' ' + LineName[j] + ' will be added');
        end;

        WriteLn('  loading work file');
        S := TStringList.Create();
        S.LoadFromFile(workPath + '\' + FileList[i]);
        //DeleteFile(workPath + '\' + FileList[i]);
        OutText := TStringList.Create();
        AddedText := TStringList.Create();
        SetLength(LineOrig, 0);
        SetLength(LineOrig, Length(LineText));
        SetLength(LinePosOrig, 0);
        SetLength(LinePosOrig, Length(LineText));
        for j := 0 to S.Count-1 do
        begin
          k := Length(LineText);
          if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (trim(S.Strings[j]) <> '') then
          begin
            if (LowerCase(FileList[i]) <> 'fstring.txt') AND (Pos('_pch', LowerCase(FileList[i])) = 0)
                AND (Pos('_begin', S.Strings[j]) = 0) then
            begin
              R.Pattern := '^[\t\s]*([a-zA-Z0-9_.]+)[\s\t]*=[\s\t]*([a-zA-Z0-9_.]+)$';
              R.IgnoreCase := True;
              R.Global := False;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if (mc.Count > 0) then
              begin
                m := mc[0] as Match;
                sm := m.SubMatches as SubMatches;
                if (sm.Count > 0) then
                begin
                  if (InArray(trim(sm.Item[0]), ParamNameNew, ii)) AND (ParamValueNew[ii] <> trim(sm.Item[1])) then
                    OutText.Add(ParamNameNew[ii] + ' = ' + ParamValueNew[ii])
                  else
                    OutText.Add(S.Strings[j]);
                end;
              end
              else
                OutText.Add(S.Strings[j]);
            end
            else
            begin
              R := TRegExp.Create(nil);
              try
                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                  R.Pattern := 'skill_id[\s]*=[\s]*([\d]+)'
                else if (LowerCase(FileList[i]) = 'dyedata.txt') then
                  R.Pattern := 'dye_id[\s]*=[\s]*([\d]+)'
                else if (LowerCase(FileList[i]) = 'fstring.txt') then
                  R.Pattern := '([\d]+)'
                else if (Pos('_pch2', LowerCase(FileList[i])) > 0) then
                  R.Pattern := '^([\d]+)'
                else if (Pos('_pch', LowerCase(FileList[i])) > 0) then
                  R.Pattern := '[\s\t=]+([\d]+)'
                else
                  R.Pattern := '[\t]([\d]+)[\t]';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                Id := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  SetLength(LineId, k+1);
                  if (sm.Count > 0) then
                    Id := sm.Item[0];
                end;
                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                  R.Pattern := 'skill_name[\s]*=[\s]*(\[[^\]]*\])'
                else
                  R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                Name := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  SetLength(LineName, k+1);
                  if (sm.Count > 0) then
                    Name := sm.Item[0];
                end;

                if (LowerCase(FileList[i]) = 'skilldata.txt') then
                begin
                  R.Pattern := 'level[\s]*=[\s]*([\d]+)';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    SetLength(LineName, k+1);
                    if (sm.Count > 0) then
                      Level := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;

              if (LowerCase(FileList[i]) = 'skilldata.txt') then
              begin
                if (InArray(Name, LineName, ii)) OR ((InArray(Id, LineId, ii)) AND (InArray(Level, LineLevel, ii))) then
                begin
                  k := Pos('_begin', S.Strings[j]) + Length('_begin');
                  if (Copy(LineText[ii], 0, k) = Copy(S.Strings[j], 0, k)) then
                  begin
                    WriteLn(' ' + LineId[ii] + ' ' + LineLevel[ii] + LineName[ii] + ' found in line ' + IntToStr(j+1));
                    if (StrToInt(LineCommentType[ii]) = 1) then
                      OutText.Add('//' + S.Strings[j]);
                    LineOrig[ii] := S.Strings[j];
                    if (StrToInt(LinePos[ii]) > 0) then
                      LinePosOrig[ii] := IntToStr(j);
                  end
                  else
                    OutText.Add(S.Strings[j]);
                end
                else
                  OutText.Add(S.Strings[j]);
              end
              else
              begin
                if (Id = '') AND (Name <> '') then
                begin
                  if (InArray(Name, LineName, ii)) then
                  begin
                    k := Pos('_begin', S.Strings[j]) + Length('_begin');
                    if (Copy(LineText[ii], 0, k) = Copy(S.Strings[j], 0, k)) then
                    begin
                      WriteLn(' ' + LineName[ii] + ' found in line ' + IntToStr(j+1));
                      if (StrToInt(LineCommentType[ii]) = 1) AND (Pos('_pch', LowerCase(FileList[i])) = 0) then
                        OutText.Add('//' + S.Strings[j]);
                      LineOrig[ii] := S.Strings[j];
                      if (StrToInt(LinePos[ii]) > 0) then
                        LinePosOrig[ii] := IntToStr(j);
                    end
                    else
                      OutText.Add(S.Strings[j]);
                  end
                  else
                    OutText.Add(S.Strings[j]);
                end
                else if (Name = '') then
                begin
                  if (InArray(Id, LineId, ii)) then
                  begin
                    k := Pos('_begin', S.Strings[j]) + Length('_begin');
                    if (Copy(LineText[ii], 0, k) = Copy(S.Strings[j], 0, k)) then
                    begin
                      WriteLn(' ' + LineId[ii] + ' found in line ' + IntToStr(j+1));
                      if (StrToInt(LineCommentType[ii]) = 1) AND (Pos('_pch', LowerCase(FileList[i])) = 0) then
                        OutText.Add('//' + S.Strings[j]);
                      LineOrig[ii] := S.Strings[j];
                      if (StrToInt(LinePos[ii]) > 0) then
                        LinePosOrig[ii] := IntToStr(j);
                    end
                    else
                      OutText.Add(S.Strings[j]);
                  end
                  else
                    OutText.Add(S.Strings[j]);
                end
                else
                begin
                  if (InArray(Name, LineName, ii)) OR (InArray(Id, LineId, ii)) then
                  begin
                    if (Pos('_begin', S.Strings[j]) > 0) then
                    begin
                      k := Pos('_begin', S.Strings[j]) + Length('_begin');
                      if (Copy(LineText[ii], 0, k) = Copy(S.Strings[j], 0, k)) then
                      begin
                        if (StrToInt(LineCommentType[ii]) = 1) then
                          OutText.Add('//' + S.Strings[j]);
                        LineOrig[ii] := S.Strings[j];
                        WriteLn(' ' + IntToStr(ii) + '. ' + LineId[ii] + ' ' + LineName[ii] + ' found in line ' + IntToStr(j+1));
                        if (StrToInt(LinePos[ii]) > 0) then
                          LinePosOrig[ii] := IntToStr(j);
                      end
                      else
                        OutText.Add(S.Strings[j]);
                    end
                    else
                    begin
                      WriteLn(' ' + LineId[ii] + ' ' + LineName[ii] + ' found in line ' + IntToStr(j+1));
                      LineOrig[ii] := S.Strings[j];
                      if (StrToInt(LinePos[ii]) > 0) then
                        LinePosOrig[ii] := IntToStr(j);
                    end
                  end
                  else
                    OutText.Add(S.Strings[j]);
                end
              end;
            end;
          end
          else
            OutText.Add(S.Strings[j]);
        end;

        //insert new lines
        WriteLn('  parsing work file');
        if  (Length(LineText) > 0) AND
            (Pos('_pch', LowerCase(FileList[i])) = 0) AND
            (LowerCase(FileList[i]) <> 'fstring.txt') then
          OutText.Add('');
        for j := 0 to Length(LineText)-1 do
        begin
          if (LineComment[j] <> '') AND (StrToInt(LineType[j]) <> 2) then
          begin
            if (StrToInt(LinePos[j]) = 0) OR (LinePosOrig[j] = '') then
              OutText.Add(trim(LineComment[j]))
            else
            begin
              OutText.Insert(StrToInt(LinePosOrig[j]), trim(LineComment[j]));
              for jj := j to Length(LinePosOrig)-1 do
              begin
                if (LinePosOrig[jj] <> '') then
                  LinePosOrig[jj] := IntToStr(StrToInt(LinePosOrig[jj])+1);
              end;
            end;
          end;
          if (StrToInt(LineType[j]) = 0) then
          begin
            if (StrToInt(LinePos[j]) = 0) OR (LinePosOrig[j] = '') then
              OutText.Add(trim(LineText[j]))
            else
            begin
              OutText.Insert(StrToInt(LinePosOrig[j]), trim(LineText[j]));
              if (StrToInt(LineCommentType[j]) = 1) then
                for jj := j to Length(LinePos)-1 do
                begin
                  if (LinePosOrig[jj] <> '') then
                    LinePosOrig[jj] := IntToStr(StrToInt(LinePosOrig[jj])+1);
                end;
            end;
          end
          else if (StrToInt(LineType[j]) = 1) OR (StrToInt(LineType[j]) = 2) then
          begin
            R := TRegExp.Create(nil);
            try
                R.Pattern := '[\t]+([^=\t]*)=([^\s\t]*)';
                R.IgnoreCase := True;
                R.Global := True;
                mc := R.Execute(LineOrig[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  SetLength(ParamNameOrig, 0);
                  SetLength(ParamValueOrig, 0);
                  k := 0;
                  for ii := 0 to mc.Count - 1 do
                  begin
                    m := mc[ii] as Match;
                    sm := m.SubMatches as SubMatches;
                    jj := 0;
                    while jj < sm.Count do
                    begin
                      SetLength(ParamNameOrig, k+1);
                      SetLength(ParamValueOrig, k+1);
                      ParamNameOrig[k] := trim(sm.Item[jj]);
                      ParamValueOrig[k] := trim(sm.Item[jj+1]);
                      k := k + 1;
                      jj := jj + 2;
                    end;
                  end;
                end;
                mc := R.Execute(LineText[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  k := 0;
                  SetLength(ParamNameNew, 0);
                  SetLength(ParamValueNew, 0);
                  for ii := 0 to mc.Count - 1 do
                  begin
                    m := mc[ii] as Match;
                    sm := m.SubMatches as SubMatches;
                    jj := 0;
                    while jj < sm.Count do
                    begin
                      SetLength(ParamNameNew, k+1);
                      SetLength(ParamValueNew, k+1);
                      ParamNameNew[k] := trim(sm.Item[jj]);
                      ParamValueNew[k] := trim(sm.Item[jj+1]);
                      k := k + 1;
                      jj := jj + 2;
                    end;
                  end;
                end;
            finally
                m := nil;
                sm := nil;
                mc := nil;
            end;
            Line := '';
            if    (Copy(LineOrig[j], Length(LineOrig[j]) - Length('_end') + 1, Length('_end')) = '_end')
                AND (Copy(LineText[j], Length(LineText[j]) - Length('_end') + 1, Length('_end')) = '_end') then
            begin
                Line := ReverseString(Copy(ReverseString(LineOrig[j]), 1, Pos(#9, ReverseString(LineOrig[j]))));
                LineText[j] := Copy(trim(LineText[j]), 0, Pos(Line, trim(LineText[j]))-1);     //delete 'item_end', 'skill_end' etc.
            end;
            for k := 0 to Length(ParamNameOrig)-1 do
            begin
              if (InArray(ParamNameOrig[k], ParamNameNew, ii) = false) then
              begin
                LineText[j] := LineText[j] + ^I + ParamNameOrig[k] + '=' + ParamValueOrig[k];
              end;
            end;
            if (StrToInt(LinePos[j]) = 0) then
              if (StrToInt(LineType[j]) <> 2) then
                OutText.Add(trim(LineText[j]) + Line)
            else
            begin
              if (StrToInt(LineType[j]) <> 2) then
              begin
                OutText.Insert(StrToInt(LinePosOrig[j])+1, trim(LineText[j]) + Line);
                if (StrToInt(LineCommentType[j]) = 1) then
                  for jj := j to Length(LinePos)-1 do
                  begin
                    if (LinePosOrig[jj] <> '') then
                      LinePosOrig[jj] := IntToStr(StrToInt(LinePosOrig[jj])+1);
                  end;
              end;
            end;
          end
        end;
        OutText.SaveToFile(workPath + '\' + FileList[i], cp.Unicode);
      end
      else
      begin
        Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
        if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
          Line := Line + 'OK'
        else
          Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
        WriteLn(Line);
      end;
    end
    else if (LowerCase(ExtractFileExt(FileList[i])) <> '.obj') then
    begin
      if (LowerCase(FileList[i]) = 'skillacquire.txt') then
      begin
        if (FileExists(workPath + '\' + FileList[i])) then
        begin
          workType := 1; //0 - simple insert, 1 - paste
          commentType := 1; //1 - comment, 0 - delete
          linePosition := 1; //0 - insert in end of section; 1 - insert in currrent position

          S := TStringList.Create();
          cp := TEncoding.Create();
          DeleteFile(workPath + '\' + FileList[i] + '.bak');
          Line := ' Backup exists file... ';
          if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);

          //clear data
          SetLength(ClassSkill, 0);
          SetLength(ClassName, 0);
          SetLength(LineComment, 0);
          SetLength(LineCommentType, 0);
          SetLength(LineType, 0);
          SetLength(LinePos, 0);

          //load data for insert
          S.LoadFromFile(newPath + '\' + FileList[i]);
          j := 0;
          while j < S.Count-1 do
          begin
            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$W[\s]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := False;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                m := mc[0] as Match;
                sm := m.SubMatches as SubMatches;
                if (sm.Count > 0) then
                  workType := StrToInt(sm.Item[0]);
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;
            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$C[\s]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := False;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                m := mc[0] as Match;
                sm := m.SubMatches as SubMatches;
                if (sm.Count > 0) then
                  commentType := StrToInt(sm.Item[0]);
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;
            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$P[\s]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := False;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                m := mc[0] as Match;
                sm := m.SubMatches as SubMatches;
                if (sm.Count > 0) then
                  linePosition := StrToInt(sm.Item[0]);
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;
            k := Length(ClassName);
            SetLength(ClassSkill, k+1);
            SetLength(ClassSkill[k], 0);
            SetLength(ClassSkillName, k+1);
            SetLength(ClassSkillName[k], 0);
            SetLength(ClassSkillComment, k+1);
            SetLength(ClassSkillComment[k], 0);
            SetLength(LineType, k+1);
            SetLength(LinePos, k+1);
            SetLength(LineComment, k+1);
            SetLength(LineCommentType, k+1);

            LineType[k] := IntToStr(workType);
            LinePos[k] := IntToStr(linePosition);
            LineCommentType[k] := IntToStr(commentType);
            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Pos('_begin', S.Strings[j]) > 0) then
            begin
              SetLength(ClassName, k+1);
              ClassName[k] := trim(Copy(S.Strings[j], 0, Pos('_begin', S.Strings[j])-1));
              WriteLn(' found skills of class ' + ClassName[k]);
              j := j + 1;
              while (j < S.Count) AND (trim(S.Strings[j]) <> ClassName[k] + '_end') do //read skills in class
              begin
                n := Length(ClassSkill[k]);
                SetLength(ClassSkillComment[k], n+1);
                if (Copy(trim(S.Strings[j]), 0, 2) = '//') then
                begin
                  SetLength(ClassSkillComment[k], n + 1);
                  ClassSkillComment[k][n] := ClassSkillComment[k][n] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
                end
                else
                begin
                  SetLength(ClassSkill[k], n+1);
                  SetLength(ClassSkillName[k], n+1);
                  ClassSkill[k][n] := S.Strings[j];
                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := '(\[[^\]]*\])';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then
                    begin
                      m := mc[0] as Match;
                      sm := m.SubMatches as SubMatches;
                      SetLength(LineName, k+1);
                      if (sm.Count > 0) then
                        ClassSkillName[k][n] := sm.Item[0];
                    end;
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                  end;
                end;
                j := j + 1;
              end;
            end
            else
            begin
              if (trim(S.Strings[j]) <> '') then
                LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
            end;
            j := j + 1;
          end;

          //load work data
          WriteLn('  loading and parsing work file');
          S := TStringList.Create();
          S.LoadFromFile(workPath + '\' + FileList[i]);
          OutText := TStringList.Create();
          j := 0;
          while j < S.Count-1 do
          begin
            Name := '';

            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Pos('_begin', S.Strings[j]) > 0) then
            begin
              Name := trim(Copy(S.Strings[j], 0, Pos('_begin', S.Strings[j])-1));
              if (Name <> '') AND (InArray(Name, ClassName, k)) then
              begin
                //if (LineComment[k] <> '') then
                  //OutText.Add(LineComment[k]);
                while (LowerCase(Copy(trim(S.Strings[j]), 0, Length('skill_begin'))) <> 'skill_begin') do
                begin
                  OutText.Add(S.Strings[j]);
                  j := j + 1;
                end;

                if (StrToInt(LinePos[k]) = 1) AND (StrToInt(LineType[k]) <> 2) then
                begin
                  for jj := 0 to Length(ClassSkill[k])-1 do
                    if (ClassSkill[k][jj] <> '') then
                      OutText.Add(ClassSkill[k][jj]);
                end;

                while (j < S.Count) AND (trim(S.Strings[j]) <> ClassName[k] + '_end') do //read skills in class
                begin
                  if (StrToInt(LineType[k]) <> 0) then
                  begin
                    if (Copy(trim(S.Strings[j]), 0, 2) = '//') then
                    begin
                      OutText.Add(S.Strings[j]);
                    end
                    else
                    begin
                      R := TRegExp.Create(nil);
                      try
                        R.Pattern := '(\[[^\]]*\])';
                        R.IgnoreCase := True;
                        R.Global := False;
                        mc := R.Execute(S.Strings[j]) as MatchCollection;
                        SkillName := '';
                        if mc.Count > 0 then
                        begin
                          m := mc[0] as Match;
                          sm := m.SubMatches as SubMatches;
                          SetLength(LineName, k+1);
                          if (sm.Count > 0) then
                            SkillName := sm.Item[0];
                        end;
                      finally
                        m := nil;
                        sm := nil;
                        mc := nil;
                      end;

                      if (SkillName <> '') AND (InArray(SkillName, ClassSkillName[k], ii)) then
                      begin
                        WriteLn('  skill ' + SkillName + ' found in line ' + IntToStr(j + 1));
                        if (StrToInt(LineCommentType[k]) > 0) then
                          OutText.Add('//' + S.Strings[j]);
                        if (ii < Length(ClassSkillComment[k])) AND (ClassSkillComment[k][ii] <> '') AND (StrToInt(LineType[k]) <> 2) then
                          OutText.Add(ClassSkillComment[k][ii]);
                        if (StrToInt(LinePos[k]) = 0) then
                        begin
                          if (StrToInt(LineType[k]) <> 2) then
                            OutText.Add(ClassSkill[k][ii]);
                          ClassSkill[k][ii] := '';
                        end;
                      end
                      else
                        OutText.Add(S.Strings[j]);
                    end;
                  end;
                  j := j + 1;
                end;
                ClassName[k] := '';
                if (StrToInt(LinePos[k]) = 0) AND (StrToInt(LineType[k]) <> 2) then
                begin
                  for jj := 0 to Length(ClassSkill[k])-1 do
                    if (ClassSkill[k][jj] <> '') AND (StrToInt(LineType[k]) <> 2) then
                      OutText.Add(ClassSkill[k][jj]);
                end;
                //if (j < S.Count) then
                  //OutText.Add(S.Strings[j]);
              end
              else
              begin
                if (j < S.Count) then
                  OutText.Add(S.Strings[j]);
                j := j + 1;
              end;
            end
            else
            begin
              if (j < S.Count) then
                OutText.Add(S.Strings[j]);
              j := j + 1;
            end;
          end;
          if (j < S.Count) then
            OutText.Add(S.Strings[j]);
          for ii:=0 to Length(ClassName)-1 do     //add group which not found in work file
          begin
            if (ClassName[ii] <> '') AND (StrToInt(LineType[ii]) <> 2) then
            begin
              OutText.Add(ClassName[ii] + '_begin');
              for jj:=0 to Length(ClassSkill[ii])-1 do
              begin
                if (ClassSkillComment[ii][jj] <> '') then
                  OutText.Add(ClassSkillComment[ii][jj]);
                OutText.Add(ClassSkill[ii][jj]);
              end;
              OutText.Add(ClassName[ii] + '_end');
            end;
          end;
          OutText.SaveToFile(workPath + '\' + FileList[i], cp.Unicode);
        end
        else
        begin
          Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
          if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);
        end;
      end // end skillacquire
      else if (LowerCase(FileList[i]) = 'multisell.txt') then
      begin
        if (FileExists(workPath + '\' + FileList[i])) then
        begin
          workType := 1; //0 - simple insert, 1 - paste
          commentType := 1; //1 - comment, 0 - delete
          linePosition := 1; //0 - insert in end of section; 1 - insert in currrent position

          S := TStringList.Create();
          cp := TEncoding.Create();
          DeleteFile(workPath + '\' + FileList[i] + '.bak');
          Line := ' Backup exists file... ';
          if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);

          SetLength(LineId, 0);
          SetLength(LineName, 0);
          SetLength(LineType, 0);
          SetLength(LinePos, 0);
          SetLength(LineComment, 0);
          SetLength(LineCommentType, 0);

          S.LoadFromFile(newPath + '\' + FileList[i]);
          j := 0;
          while j < S.Count-1 do
          begin
            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$([a-zA-Z]+)[\s]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := True;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                for ii:=0 to mc.Count-1 do
                begin
                  m := mc[ii] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    if (LowerCase(sm.Item[0]) = 'w') then
                      workType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'c') then
                      commentType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'p') then
                      linePosition := StrToInt(sm.Item[1]);
                  end
                end;
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;

            k := Length(LineId);
            SetLength(LineComment, k+1);

            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Copy(trim(LowerCase(S.Strings[j])), 0, Length('multisell_begin')) = 'multisell_begin') then
            begin
              SetLength(LineId, k+1);
              SetLength(LineName, k+1);
              SetLength(LineType, k+1);
              SetLength(LineCommentType, k+1);
              SetLength(LinePos, k+1);

              SetLength(MsLine, k+1);
              SetLength(MsLineComment, k+1);
              SetLength(MsParamName, k+1);
              SetLength(MsParamValue, k+1);
              SetLength(MsLineComment, k+1);

              LineType[k] := IntToStr(workType);
              LinePos[k] := IntToStr(linePosition);
              LineCommentType[k] := IntToStr(commentType);

              R := TRegExp.Create(nil);
              try
                R.Pattern := 'multisell_begin[\s\t]+(\[[^\]]*\])[\t\s]+([\d]*)';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(LowerCase(S.Strings[j])) as MatchCollection;
                LineId[k] := '';
                LineName[k] := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    LineId[k] := sm.Item[1];
                    LineName[k] := sm.Item[0];
                    WriteLn(LineId[k] + ' ' + LineName[k] + ' will be added');
                  end
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;

              if (LineId[k] <> '') then
              begin
                j := j + 1;
                while (j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> 'multisell_end') do
                begin
                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := '([a-zA-Z0-9_]*)[\s\t]*=[\s\t]*([\d]+)';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then      //if it is parameter
                    begin
                      m := mc[0] as Match;
                      sm := m.SubMatches as SubMatches;
                      if (sm.Count > 1) then
                      begin
                        n := Length(MsParamName[k]);
                        SetLength(MsParamName[k], n + 1);
                        SetLength(MsParamValue[k], n + 1);
                        MsParamName[k][n] := trim(sm.Item[0]);
                        MsParamValue[k][n] := trim(sm.Item[1]);
                      end;
                    end
                    else
                    begin
                      R.Pattern := '[\{]+(\[[^\]]*\])';
                      R.IgnoreCase := True;
                      R.Global := True;
                      mc := R.Execute(S.Strings[j]) as MatchCollection;
                      if mc.Count > 1 then      //if it is parameter
                      begin
                        n := Length(MsLine[k]);
                        SetLength(MsLine[k], n+1);
                        MsLine[k][n] := trim(S.Strings[j]);
                      end
                      else
                      begin
                        n := Length(MsLine[k]);
                        SetLength(MsLineComment[k], n+1);
                        if (Copy(trim(S.Strings[j]), 0, 2) = '//') then
                          if (MsLineComment[k][n] <> '') then
                            MsLineComment[k][n] := MsLineComment[k][n] + CHAR(13) + CHAR(10) + trim(S.Strings[j])
                          else
                            MsLineComment[k][n] := trim(S.Strings[j]);
                      end;
                    end
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                  end;
                  j := j + 1;
                end;
              end
              else
                if (trim(S.Strings[j]) <> '') then
                  LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
            end //end if copy
            else
              if (trim(S.Strings[j]) <> '') then
                LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
            j := j + 1;
          end; // while

          //load work data
          WriteLn('  loading and parsing work file');
          S := TStringList.Create();
          S.LoadFromFile(workPath + '\' + FileList[i]);
          OutText := TStringList.Create();
          j := 0;
          while j < S.Count-1 do
          begin
            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Copy(trim(LowerCase(S.Strings[j])), 0, Length('multisell_begin')) = 'multisell_begin') then
            begin
               R := TRegExp.Create(nil);
              try
                R.Pattern := 'multisell_begin[\s\t]+\[[^\]]*\][\t\s]+([\d]*)';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(LowerCase(S.Strings[j])) as MatchCollection;
                Id := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                    Id := sm.Item[0];
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;

              if (Id <> '') AND (InArray(Id, LineId, k)) then
              begin
                WriteLn(' found position of multisell ' + LineId[k] + ' in line ' + IntToStr(j + 1));
                OutText.Add(S.Strings[j]);
                j := j + 1;
                while (j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> 'multisell_end') do
                begin
                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := '([a-zA-Z0-9_]*)[\s\t]*=[\s\t]*([\d]+)';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then      //if it is parameter
                    begin
                      m := mc[0] as Match;
                      sm := m.SubMatches as SubMatches;
                      if (sm.Count > 1) then
                      begin
                        if (InArray(sm.Item[0], MsParamName[k], n)) then
                        begin
                          OutText.Add(sm.Item[0] + ' = ' + MsParamValue[k][n]);
                          MsParamName[k][n] := '';
                        end
                        else
                          OutText.Add(S.Strings[j])
                      end;
                    end
                    else
                    begin
                      R.Pattern := '[\{]+(\[[^\]]*\])';
                      R.IgnoreCase := True;
                      R.Global := True;
                      mc := R.Execute(S.Strings[j]) as MatchCollection;
                      if mc.Count > 1 then
                      begin
                        if (StrToInt(LineType[k]) <> 2) then
                        begin
                          if (StrToInt(LinePos[k]) = 1) OR (StrToInt(LineType[k]) = 0)  then
                          begin
                            for ii:=0 to Length(MsLine[k])-1 do
                            begin
                              if (Copy(MsLine[k][ii], Length(MsLine[k][ii]), 1) <> ';') AND
                                  (j + 1 < S.Count-1) AND (trim(S.Strings[j + 1]) <> '}') then
                                MsLine[k][ii] := MsLine[k][ii]+';';
                              if (MsLineComment[k][ii] <> '') then
                                OutText.Add(MsLineComment[k][ii]);
                              OutText.Add(MsLine[k][ii]);
                            end;
                          end;
                        end;
                        while (j < S.Count) AND ((trim(S.Strings[j]) <> '}') AND (LowerCase(trim(S.Strings[j])) <> 'multisell_end')) do
                        begin
                          if (StrToInt(LineType[k]) = 1) OR (StrToInt(LineType[k]) = 3) then
                          begin
                            if (StrToInt(LinePos[k]) = 0) AND
                                (Copy(S.Strings[j], Length(S.Strings[j]), 1) <> ';') then
                                S.Strings[j] := S.Strings[j] + ';';
                            if (InArray(S.Strings[j], MsLine[k], n)) then
                            begin
                              if (StrToInt(LineCommentType[k]) = 1) then
                                OutText.Add('//' + S.Strings[j]);
                            end
                            else
                              OutText.Add(S.Strings[j]);
                          end;
                          j := j + 1;
                        end;
                        if (StrToInt(LinePos[k]) = 0) AND (StrToInt(LineType[k]) = 1) then
                        begin
                          for ii:=0 to Length(MsLine[k])-1 do
                          begin
                            if (MsLineComment[k][ii] <> '') then
                                OutText.Add(MsLineComment[k][ii]);
                            if (ii < Length(MsLine[k])-1) then
                            begin
                              if (Copy(MsLine[k][ii], Length(MsLine[k][ii]), 1) <> ';') then
                                MsLine[k][ii] := MsLine[k][ii] + ';'
                            end
                            else
                              if (Copy(MsLine[k][ii], Length(MsLine[k][ii]), 1) = ';') then
                                MsLine[k][ii] := Copy(MsLine[k][ii], 0, Length(MsLine[k][ii])-1);
                            OutText.Add(MsLine[k][ii]);
                            end;
                        end;
                        if (trim(S.Strings[j]) = '}') then
                          if (Copy(OutText.Strings[OutText.Count-1], Length(OutText.Strings[OutText.Count-1]), 1) = ';') then
                            OutText.Strings[OutText.Count-1] := Copy(OutText.Strings[OutText.Count-1], 0, Length(OutText.Strings[OutText.Count-1])-1);
                        OutText.Add(S.Strings[j]);
                      end
                      else
                        OutText.Add(S.Strings[j]);
                    end;
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                  end;
                  j := j + 1;
                end; //end while multisell_end
                OutText.Add(S.Strings[j]);
                LineId[k] := '';
              end
              else
                OutText.Add(S.Strings[j]);
            end
            else
              OutText.Add(S.Strings[j]);
            j := j + 1;
          end; //end while j < S.Count (loading work data)
          OutText.Add(S.Strings[j]);

          //add not found multisells
          for j := 0 to Length(LineId)-1 do
            if (LineId[j] <> '') then
            begin
              OutText.Add('');
              OutText.Add('MultiSell_begin' + ^I + LineName[j] + ^I + LineId[j]);
              for k := 0 to Length(MsParamName[j])-1 do
                OutText.Add(MsParamName[j][k] + ' = ' + MsParamValue[j][k]);
              OutText.Add('selllist={');
              for k := 0 to Length(MsLine[j])-1 do
              begin
                if (MsLineComment[j][k] <> '') then
                  OutText.Add(MsLineComment[j][k]);
                if (k < Length(MsLine[j])-1) then
                begin
                  if (Copy(MsLine[j][k], Length(MsLine[j][k]), 1) <> ';') then
                    OutText.Add(MsLine[j][k] + ';')
                  else
                    OutText.Add(MsLine[j][k])
                end
                else
                  if (Copy(MsLine[j][k], Length(MsLine[j][k])-1, 1) = ';') then
                    OutText.Add(Copy(MsLine[j][k], 0, Length(MsLine[j][k])-1))
                  else
                    OutText.Add(MsLine[j][k]);
              end;
              OutText.Add('}');
              OutText.Add('MultiSell_end');
            end;
          OutText.SaveToFile(workPath + '\' + FileList[i], cp.Unicode);
        end  //end file exists
        else
        begin
          Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
          if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);
        end;
      end
      else if (LowerCase(FileList[i]) = 'setting.txt') OR (LowerCase(FileList[i]) = 'cursedweapondata.txt') then
      begin
        if (FileExists(workPath + '\' + FileList[i])) then
        begin
          workType := 1; //0 - simple insert, 1 - paste
          commentType := 1; //1 - comment, 0 - delete
          linePosition := 1; //0 - insert in end of section; 1 - insert in currrent position

          S := TStringList.Create();
          cp := TEncoding.Create();
          DeleteFile(workPath + '\' + FileList[i] + '.bak');
          Line := ' Backup exists file... ';
          if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);

          //clear data
          SetLength(MsParamName, 0);
          SetLength(MsParamValue, 0);
          SetLength(ClassName, 0);
          SetLength(LineComment, 0);
          SetLength(MsLineComment, 0);
          SetLength(LineCommentType, 0);
          SetLength(LineType, 0);
          SetLength(LinePos, 0);

          //load data for insert
          S.LoadFromFile(newPath + '\' + FileList[i]);
          j := 0;
          while j < S.Count-1 do
          begin
            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$([a-zA-Z])+[\s\t]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := True;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                for ii:=0 to mc.Count-1 do
                begin
                  m := mc[ii] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    if (LowerCase(sm.Item[0]) = 'w') then
                      workType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'c') then
                      commentType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'p') then
                      linePosition := StrToInt(sm.Item[1]);
                  end;
                end;
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;
            k := Length(ClassName);
            SetLength(ClassName, k+1);
            SetLength(MsParamName, k+1);
            SetLength(MsParamName[k], 0);
            SetLength(MsParamValue, k+1);
            SetLength(MsParamValue[k], 0);
            SetLength(MsLineComment, k+1);
            SetLength(MsLineComment[k], 0);
            SetLength(LineType, k+1);
            SetLength(LinePos, k+1);
            SetLength(LineComment, k+1);
            SetLength(LineCommentType, k+1);

            LineType[k] := IntToStr(workType);
            LinePos[k] := IntToStr(linePosition);
            LineCommentType[k] := IntToStr(commentType);

            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Pos('_begin', S.Strings[j]) > 0) then
            begin
              SetLength(ClassName, k+1);
              ClassName[k] := trim(Copy(S.Strings[j], 0, Pos('_begin', S.Strings[j])-1));
              WriteLn(' found params of section ' + ClassName[k]);
              j := j + 1;
              while (j < S.Count) AND (trim(S.Strings[j]) <> ClassName[k] + '_end') do //read params in class
              begin
                n := Length(MsParamName[k]);
                SetLength(MsLineComment[k], n+1);
                if (Copy(trim(S.Strings[j]), 0, 2) = '//') then
                begin
                  SetLength(MsLineComment[k], n + 1);
                  MsLineComment[k][n] := MsLineComment[k][n] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
                end
                else
                begin
                  SetLength(MsParamName[k], n+1);
                  SetLength(MsParamValue[k], n+1);
                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := '([^=]*)[\s\t]*=[\s\t]*([^=]*)';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then
                    begin
                      m := mc[0] as Match;
                      sm := m.SubMatches as SubMatches;
                      SetLength(LineName, k+1);
                      if (sm.Count > 0) then
                        MsParamName[k][n] := trim(sm.Item[0]);
                        MsParamValue[k][n] := trim(sm.Item[1]);
                    end;
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                  end;
                end;
                j := j + 1;
              end;
            end
            else
            begin
              if (trim(S.Strings[j]) <> '') then
                LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + trim(S.Strings[j]);
            end;
            j := j + 1;
          end;

          //load work data
          WriteLn('  loading and parsing work file');
          S := TStringList.Create();
          S.LoadFromFile(workPath + '\' + FileList[i]);
          OutText := TStringList.Create();
          j := 0;
          while j < S.Count-1 do
          begin
            Name := '';
            if (Copy(trim(S.Strings[j]), 0, 2) <> '//') AND (Pos('_begin', S.Strings[j]) > 0) then
            begin
              Name := trim(Copy(S.Strings[j], 0, Pos('_begin', S.Strings[j])-1));
              if (Name <> '') AND (InArray(Name, ClassName, k)) then
              begin
                if (LineComment[k] <> '') then
                  OutText.Add(LineComment[k]);
                OutText.Add(S.Strings[j]);

                if (StrToInt(LinePos[k]) = 1) AND (StrToInt(LineType[k]) <> 2) then
                begin
                  for jj := 0 to Length(MsParamName[k])-1 do
                    OutText.Add(^I + MsParamName[k][jj] + ' = ' + MsParamValue[k][jj]);
                end;
                j := j + 1;
                while (j < S.Count) AND (trim(S.Strings[j]) <> ClassName[k] + '_end') do //read skills in class
                begin
                  if (StrToInt(LineType[k]) <> 0) then
                  begin
                    if (Copy(trim(S.Strings[j]), 0, 2) = '//') then
                    begin
                      OutText.Add(S.Strings[j]);
                    end
                    else
                    begin
                      R := TRegExp.Create(nil);
                      try
                        R.Pattern := '([^=]*)[\s\t]*=[\s\t]*([^=]*)';
                        R.IgnoreCase := True;
                        R.Global := False;
                        mc := R.Execute(S.Strings[j]) as MatchCollection;
                        Name := '';
                        Value := '';
                        if mc.Count > 0 then
                        begin
                          m := mc[0] as Match;
                          sm := m.SubMatches as SubMatches;
                          SetLength(LineName, k+1);
                          if (sm.Count > 0) then
                          begin
                            Name := trim(sm.Item[0]);
                            Value := trim(sm.Item[1]);
                          end;
                        end;
                      finally
                        m := nil;
                        sm := nil;
                        mc := nil;
                      end;

                      if (Name <> '') AND (InArray(Name, MsParamName[k], ii)) then
                      begin
                        WriteLn('  param ' + Name + ' found in line ' + IntToStr(j + 1));
                        if (StrToInt(LineCommentType[k]) > 0) then
                          OutText.Add('//' + S.Strings[j]);
                        if (ii < Length(MsLineComment[k])) AND (MsLineComment[k][ii] <> '') AND (StrToInt(LineType[k]) <> 2) then
                          OutText.Add(MsLineComment[k][ii]);
                        if (StrToInt(LinePos[k]) = 0) then
                        begin
                          if (StrToInt(LineType[k]) <> 2) then
                            OutText.Add(^I + MsParamName[k][ii] + ' = ' + MsParamValue[k][ii]);
                          MsParamName[k][ii] := '';
                        end;
                      end
                      else
                        OutText.Add(S.Strings[j]);
                    end;
                  end;
                  j := j + 1;
                end;
                ClassName[k] := '';
                if (StrToInt(LinePos[k]) = 0) AND (StrToInt(LineType[k]) <> 2) then
                begin
                  for jj := 0 to Length(MsParamName[k])-1 do
                    if (MsParamName[k][jj] <> '') AND (StrToInt(LineType[k]) <> 2) then
                      OutText.Add(^I + MsParamName[k][jj] + ' = ' + MsParamValue[k][jj]);
                end;
                //if (j < S.Count) then
                  //OutText.Add(S.Strings[j]);
              end
              else
              begin
                if (j < S.Count) then
                  OutText.Add(S.Strings[j]);
                j := j + 1;
              end;
            end
            else
            begin
              if (j < S.Count) then
                OutText.Add(S.Strings[j]);
              j := j + 1;
            end;
          end;
          if (j < S.Count) then
            OutText.Add(S.Strings[j]);
          for ii:=0 to Length(ClassName)-1 do     //add group which not found in work file
          begin
            if (ClassName[ii] <> '') AND (StrToInt(LineType[ii]) <> 2) then
            begin
              OutText.Add('');
              OutText.Add(ClassName[ii] + '_begin');
              for jj:=0 to Length(MsParamName[ii])-1 do
              begin
                if (MsLineComment[ii][jj] <> '') then
                  OutText.Add(MsLineComment[ii][jj]);
                OutText.Add(^I + MsParamName[ii][jj] + ' = ' + MsParamValue[ii][jj]);
              end;
              OutText.Add(ClassName[ii] + '_end');
            end;
          end;
          OutText.SaveToFile(workPath + '\' + FileList[i], cp.Unicode);
        end
        else
        begin
          Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
          if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);
        end;
      end // end settings.txt
      else if (LowerCase(FileList[i]) = 'npcpos.txt') then
      begin
        if (FileExists(workPath + '\' + FileList[i])) then
        begin
          workType := 1; //0 - simple insert, 1 - paste
          commentType := 1; //1 - comment, 0 - delete
          linePosition := 1; //0 - insert in end of section; 1 - insert in currrent position

          S := TStringList.Create();
          cp := TEncoding.Create();
          DeleteFile(workPath + '\' + FileList[i] + '.bak');
          Line := ' Backup exists file... ';
          if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);

          //load data for insert
          S.LoadFromFile(newPath + '\' + FileList[i]);
          j := 0;
          while j < S.Count do
          begin
            k := Length(LineTerritoryName);

            R := TRegExp.Create(nil);
            try
              R.Pattern := '\{\$([a-zA-Z]+)[\s\t]+([\d]+)\}';
              R.IgnoreCase := True;
              R.Global := True;
              mc := R.Execute(S.Strings[j]) as MatchCollection;
              if mc.Count > 0 then
              begin
                for ii:=0 to mc.Count-1 do
                begin
                  m := mc[ii] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    if (LowerCase(sm.Item[0]) = 'w') then
                      workType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'c') then
                      commentType := StrToInt(sm.Item[1])
                    else if (LowerCase(sm.Item[0]) = 'p') then
                      linePosition := StrToInt(sm.Item[1]);
                  end;
                end;
              end;
            finally
              m := nil;
              sm := nil;
              mc := nil;
            end;

            if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('domain_begin'))) = 'domain_begin') then
            begin
              n := Length(LineDomainName);
              SetLength(LineDomainName, n+1);
              SetLength(LineDomainText, n+1);
              SetLength(LineDomainComment, n+1);

              SetLength(LineDomainWorkType, n+1);
              SetLength(LineDomainPos, n+1);
              SetLength(LineDomainCommentType, n+1);
              LineDomainWorkType[n] := IntToStr(workType);
              LineDomainPos[n] := IntToStr(linePosition);
              LineDomainCommentType[n] := IntToStr(commentType);

              LineDomainComment[n] := Comment;
              Comment := '';

              R := TRegExp.Create(nil);
              try
                R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    LineDomainName[n] := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;
              LineDomainText[n] := S.Strings[j];
              WriteLn(' domain ' + LineDomainName[n] + ' will be added');
            end // end domain
            else if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('territory_begin'))) = 'territory_begin') then
            begin
              n := Length(LineTerritoryName);
              SetLength(LineTerritoryName, n+1);
              SetLength(LineTerritoryText, n+1);
              SetLength(LineTerritoryComment, n+1);

              SetLength(LineTerritoryWorkType, n+1);
              SetLength(LineTerritoryPos, n+1);
              SetLength(LineTerritoryCommentType, n+1);
              LineTerritoryWorkType[n] := IntToStr(workType);
              LineTerritoryPos[n] := IntToStr(linePosition);
              LineTerritoryCommentType[n] := IntToStr(commentType);

              LineTerritoryComment[n] := Comment;
              Comment := '';

              R := TRegExp.Create(nil);
              try
                R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    LineTerritoryName[n] := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
              end;
              LineTerritoryText[n] := S.Strings[j];
              WriteLn(' territory ' + LineTerritoryName[n] + ' will be added');
            end //end territory
            else if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_begin'))) = 'npcmaker_begin') OR
                    (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_ex_begin'))) = 'npcmaker_ex_begin') then
            begin
              if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_begin'))) = 'npcmaker_begin') then
              begin
                n := Length(LineNpcMakerName);
                SetLength(LineNpcMakerName, n+1);
                SetLength(LineNpcMakerText, n+1);
                SetLength(LineNpcMakerType, n+1);
                SetLength(LineNpcMakerTerritory, n+1);
                SetLength(LineNpcMakerComment, n+1);

                SetLength(LineNpcMakerWorkType, n+1);
                SetLength(LineNpcMakerPos, n+1);
                SetLength(LineNpcMakerCommentType, n+1);
                LineNpcMakerWorkType[n] := IntToStr(workType);
                LineNpcMakerPos[n] := IntToStr(linePosition);
                LineNpcMakerCommentType[n] := IntToStr(commentType);

                LineNpcMakerType[n] := '0';
                LineNpcMakerText[n] := S.Strings[j];

                LineNpcMakerComment[n] := Comment;
                Comment := '';
                R := TRegExp.Create(nil);
                try
                  R.Pattern := '(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      LineNpcMakerTerritory[n] := sm.Item[0];
                    end;
                  end;
                finally
                  m := nil;
                  sm := nil;
                  mc := nil;
                end;
              end //end npcmaker
              else
              begin
                n := Length(LineNpcMakerName);
                SetLength(LineNpcMakerName, n+1);
                SetLength(LineNpcMakerText, n+1);
                SetLength(LineNpcMakerType, n+1);
                SetLength(LineNpcMakerTerritory, n+1);
                SetLength(LineNpcMakerComment, n+1);

                SetLength(LineNpcMakerWorkType, n+1);
                SetLength(LineNpcMakerPos, n+1);
                SetLength(LineNpcMakerCommentType, n+1);
                LineNpcMakerWorkType[n] := IntToStr(workType);
                LineNpcMakerPos[n] := IntToStr(linePosition);
                LineNpcMakerCommentType[n] := IntToStr(commentType);

                LineNpcMakerType[n] := '1';
                LineNpcMakerText[n] := S.Strings[j];

                LineNpcMakerComment[n] := Comment;
                Comment := '';
                R := TRegExp.Create(nil);
                try
                  R.Pattern := '(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      LineNpcMakerTerritory[n] := sm.Item[0];
                    end;
                  end;
                  R.Pattern := 'name[\s]*=[\s]*(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      LineNpcMakerName[n] := sm.Item[0];
                    end;
                  end;
                finally
                  m := nil;
                  sm := nil;
                  mc := nil;
                  R.Free;
                end;
              end; // end npcmaker_ex

              WriteLn(' maker ' + LineNpcMakerTerritory[n] + ' ' + LineNpcMakerName[n] + ' will be added');
              SetLength(LineNpcName, n+1);
              SetLength(LineNpcPos, n+1);
              SetLength(LineNpcText, n+1);
              SetLength(LineNpcComment, n+1);

              j := j + 1;
              if (LineNpcMakerType[n] = '0') then
                Name := 'npcmaker_end'
              else
                Name := 'npcmaker_ex_end';
              while (j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> Name) do
              begin
                if (LineNpcMakerType[n] = '0') then
                  Level := 'npc_begin'
                else
                  Level := 'npc_ex_begin';

                if (LowerCase(Copy(trim(S.Strings[j]),0,Length(Level))) = Level) then
                begin
                  ii := Length(LineNpcName[n]);
                  SetLength(LineNpcName[n], ii+1);
                  SetLength(LineNpcPos[n], ii+1);
                  SetLength(LineNpcComment[n], ii+1);
                  SetLength(LineNpcText[n], ii+1);
                  LineNpcText[n][ii] := S.Strings[j];
                  LineNpcComment[n][ii] := Comment;
                  Comment := '';

                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := '(\[[^\]]*\])';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then
                    begin
                      m := mc[0] as Match;
                      sm := m.SubMatches as SubMatches;
                      if (sm.Count > 0) then
                      begin
                        LineNpcName[n][ii] := sm.Item[0];
                      end;
                    end;
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                    R.Free;
                  end;

                  R := TRegExp.Create(nil);
                  try
                    R.Pattern := 'pos[\s]*=[\s]*([^\s\t]*)';
                    R.IgnoreCase := True;
                    R.Global := False;
                    mc := R.Execute(S.Strings[j]) as MatchCollection;
                    if mc.Count > 0 then
                    begin
                        m := mc[0] as Match;
                        sm := m.SubMatches as SubMatches;
                        if (sm.Count > 0) then
                        begin
                          LineNpcPos[n][ii] := sm.Item[0];
                        end;
                    end;
                  finally
                    m := nil;
                    sm := nil;
                    mc := nil;
                    R.Free;
                  end;
                end
                else
                begin
                  if (Comment = '') then
                    Comment := S.Strings[j]
                  else
                    Comment := Comment + CHAR(13) + CHAR(10) + S.Strings[j];
                end;
                j := j + 1;
              end; //end while s.Strings[j] <> npcmaker_(ex_)end
            end // and maker
            else
            begin
              if (Comment = '') then
                Comment := S.Strings[j]
              else
                Comment := Comment + CHAR(13) + CHAR(10) + S.Strings[j];
            end;
            j := j + 1;
          end; // end while j < S.Count

          //parsing work file
          WriteLn('  loading and parsing work file');
          S := TStringList.Create();
          S.LoadFromFile(workPath + '\' + FileList[i]);
          OutText := TStringList.Create();
          j := 0;
          SetLength(LineOrig, 0);
          SetLength(LineOrig, Length(LineNpcMakerName));
          while j < S.Count do
          begin
            if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('domain_begin'))) = 'domain_begin') then
            begin
              R := TRegExp.Create(nil);
              try
                R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                Name := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    Name := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
                R.Free;
              end;

              if (Name <> '') AND (InArray(Name, LineDomainName, n)) then
              begin
                WriteLn(' domain ' + LineDomainName[n] + ' found in line ' + IntToStr(j + 1));
                If (LineDomainCommentType[n] = '1') then
                  OutText.Add('//' + S.Strings[j]);
                if (LineDomainComment[n] <> '') AND (LineDomainPos[n] = '1') then
                  OutText.Add(LineDomainComment[n]);
                if (LineDomainPos[n] = '1') then
                begin
                  OutText.Add(LineDomainText[n]);
                  LineDomainName[n] := '';
                end
              end
              else
                OutText.Add(S.Strings[j]);
            end // end domain
            else if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('territory_begin'))) = 'territory_begin') then
            begin
             R := TRegExp.Create(nil);
              try
                R.Pattern := '(\[[^\]]*\])';
                R.IgnoreCase := True;
                R.Global := False;
                mc := R.Execute(S.Strings[j]) as MatchCollection;
                Name := '';
                if mc.Count > 0 then
                begin
                  m := mc[0] as Match;
                  sm := m.SubMatches as SubMatches;
                  if (sm.Count > 0) then
                  begin
                    Name := sm.Item[0];
                  end;
                end;
              finally
                m := nil;
                sm := nil;
                mc := nil;
                R.Free;
              end;

              if (Name <> '') AND (InArray(Name, LineTerritoryName, n)) then
              begin
                WriteLn(' territory ' + LineTerritoryName[n] + ' found in line ' + IntToStr(j + 1));
                If (LineTerritoryCommentType[n] = '1') then
                  OutText.Add('//' + S.Strings[j]);
                if (LineTerritoryComment[n] <> '') AND (LineTerritoryPos[n] = '1') then
                  OutText.Add(LineTerritoryComment[n]);
                if (LineTerritoryPos[n] = '1') then
                begin
                  OutText.Add(LineTerritoryText[n]);
                  LineTerritoryText[n] := '';
                end
              end
              else
                OutText.Add(S.Strings[j]);
            end //end territory
            else if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_begin'))) = 'npcmaker_begin') OR
                    (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_ex_begin'))) = 'npcmaker_ex_begin') then
            begin
              Level := '';
              Name := '';
              if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker_begin'))) = 'npcmaker_begin') then
              begin
                R := TRegExp.Create(nil);
                try
                  R.Pattern := '(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      Level := sm.Item[0];
                    end;
                  end;
                finally
                  m := nil;
                  sm := nil;
                  mc := nil;
                  R.Free;
                end;
              end //end npcmaker
              else
              begin
                R := TRegExp.Create(nil);
                try
                  R.Pattern := '(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      Level := sm.Item[0];
                    end;
                  end;
                  R.Pattern := 'name[\s]*=[\s]*(\[[^\]]*\])';
                  R.IgnoreCase := True;
                  R.Global := False;
                  mc := R.Execute(S.Strings[j]) as MatchCollection;
                  if mc.Count > 0 then
                  begin
                    m := mc[0] as Match;
                    sm := m.SubMatches as SubMatches;
                    if (sm.Count > 0) then
                    begin
                      Name := sm.Item[0];
                    end;
                  end;
                finally
                  m := nil;
                  sm := nil;
                  mc := nil;
                  R.Free;
                end;
              end; // end npcmaker_ex

              if (Level <> '') AND InArray(Level, LineNpcMakerTerritory, n) AND (LineNpcMakerName[n] = Name) then
              begin
                WriteLn(' maker ' + Level + ' ' + Name + ' found in line ' + IntToStr(j + 1));
                if (LineNpcMakerPos[n] = '1') then
                begin
                  OutText.Add(LineNpcMakerText[n]);
                  LineNpcMakerTerritory[n] := '';
                  for k:=0 to Length(LineNpcText[n])-1 do
                  begin
                      if (LineNpcComment[n][k] <> '') then
                        OutText.Add(LineNpcComment[n][k]);
                      OutText.Add(LineNpcText[n][k]);
                  end
                end;
                if (LineNpcMakerType[n] = '0') then
                  Name := 'npcmaker_end'
                else
                  Name := 'npcmaker_ex_end';
                while (j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> Name) do
                begin
                  if (LineNpcMakerWorkType[n] = '1') then
                  begin
                    if (LineNpcMakerPos[n] = '0') then
                    begin
                      if (LowerCase(Copy(trim(S.Strings[j]), 0, Length('npcmaker'))) = 'npcmaker') then
                      else if (LineOrig[n] <> '') then
                        LineOrig[n] := LineOrig[n] + CHAR(13) + CHAR(10) + S.Strings[j]
                      else
                        LineOrig[n] := S.Strings[j];
                    end
                    else
                      OutText.Add(S.Strings[j]);
                  end;
                  j := j + 1;
                end; //end while s.Strings[j] <> npcmaker_(ex_)end
                if (LineNpcMakerPos[n] = '1') then
                  OutText.Add(S.Strings[j]);
              end
              else
                OutText.Add(S.Strings[j])
            end // and maker
            else
            begin
              OutText.Add(S.Strings[j]);
            end;
            j := j + 1;
          end; //end while j < S.Count

          //add non-exists data
          OutText.Add('');
          for j:=0 to Length(LineDomainName)-1 do
            if (LineDomainName[j] <> '') then
            begin
              if (LineDomainComment[j] <> '') then
                OutText.Add(LineDomainComment[j]);
              OutText.Add(LineDomainText[j]);
            end;

          for j:=0 to Length(LineTerritoryName)-1 do
          begin
            if (LineTerritoryName[j] <> '') AND (LineTerritoryText[j] <> '') then
            begin
              if (LineTerritoryComment[j] <> '') then
                OutText.Add(LineTerritoryComment[j]);
              OutText.Add(LineTerritoryText[j]);
            end;
            for k:=0 to Length(LineNpcMakerTerritory)-1 do
            begin
              if (LineTerritoryName[j] <> '') AND (LineNpcMakerTerritory[k] = LineTerritoryName[j]) then
              begin
                OutText.Add(LineNpcMakerText[k]);
                for ii:=0 to Length(LineNpcText[k])-1 do
                begin
                  if (LineNpcComment[k][ii] <> '') then
                    OutText.Add(LineNpcComment[k][ii]);
                  OutText.Add(LineNpcText[k][ii]);
                end;
                if (LineNpcMakerWorkType[k] = '1') AND (LineOrig[k] <> '') then
                  OutText.Add(LineOrig[k]);
                OutText.Add(Copy(trim(LineNpcMakerText[k]), 0, Pos('_begin', LineNpcMakerText[k])-1) + '_end');
                LineNpcMakerTerritory[k] := '';
              end;
            end;
          end;

          //add npcmakers without territory
          for k:=0 to Length(LineNpcMakerTerritory)-1 do
          begin
              if (LineNpcMakerTerritory[k] <> '') then
              begin
                OutText.Add(LineNpcMakerText[k]);
                for ii:=0 to Length(LineNpcText[k])-1 do
                begin
                  if (LineNpcComment[k][ii] <> '') then
                    OutText.Add(LineNpcComment[k][ii]);
                  OutText.Add(LineNpcText[k][ii]);
                end;
                if (LineNpcMakerWorkType[k] = '1') AND (LineOrig[k] <> '') then
                  OutText.Add(LineOrig[k]);
                OutText.Add(Copy(trim(LineNpcMakerText[k]), 0, Pos('_begin', LineNpcMakerText[k])) + 'end');
                LineNpcMakerName[k] := '';
              end;
          end;
          OutText.SaveToFile(workPath + '\' + FileList[i], cp.Unicode);
        end
        else
        begin
          Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
          if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);
        end;
      end
      else if (LowerCase(FileList[i]) = 'eventdata.ini') then
      begin
        if (FileExists(workPath + '\' + FileList[i])) then
        begin
          DeleteFile(workPath + '\' + FileList[i] + '.bak');
          Line := ' Backup exists file... ';
          if (CopyFile(PChar(workPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i] + '.bak'), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);

          S := TStringList.Create();
          List := TStringList.Create();
          cp := TEncoding.Create();
          
          eventdata_new := TiniFile.Create(newPath + '\' + FileList[i]);
          eventdata_new.ReadSections(S);
          eventdata_work := TIniFile.Create(workPath + '\' + FileList[i]);

          for j:=0 to S.Count-1 do
          begin
            eventdata_work.EraseSection(S.Strings[j]);
            eventdata_new.ReadSection(S.Strings[j], List);
            for k:=0 to List.Count-1 do
            begin
              eventdata_work.WriteString(S.Strings[j], List.Strings[k], eventdata_new.ReadString(S.Strings[j], List.Strings[k], ''));
            end
          end;
          S.LoadFromFile(workPath + '\' + FileList[i]);
          S.SaveToFile(workPath + '\' + FileList[i], cp.ASCII);
        end
        else
        begin
          Line := ' File '+FileList[i]+' not found in destination directory. Copy it... ';
          if (CopyFile(PChar(newPath + '\' + FileList[i]), PChar(workPath + '\' + FileList[i]), true)) then
            Line := Line + 'OK'
          else
            Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\' + FileList[i] + ']';
          WriteLn(Line);
        end
      end
      else
        WriteLn('This version of program can''t work with file ' + FileList[i]);
    end
  end;

  //work with obj files
  SetLength(FileList, 0);
  if FindFirst(newPath + '\*.obj', faAnyFile, sRec) = 0 then
  begin
    repeat
      if (Copy(LowerCase(sRec.Name), 0, Length('scriptinjector.')) <> 'scriptinjector.')
          AND ((sRec.Attr AND faDirectory) <> faDirectory) then
      begin
        SetLength(FileList, Length(FileList)+1);
        FileList[Length(FileList)-1] := sRec.Name;
      end;
    until FindNext(sRec) <> 0;
    FindClose(sRec);
  end;

  if (Length(FileList) = 0) then
    exit;
  SetLength(LineName, 0);
  SetLength(LineParentName, 0);
  SetLength(LineNameType, 0);
  SetLength(LineType, 0);
  SetLength(LinePos, 0);
  SetLength(LineText, 0);
  SetLength(LineComment, 0);
  SetLength(LineCommentType, 0);

  for i:=0 to Length(FileList)-1 do
  begin
    workType := 1; //0 - simple insert, 1 - paste
    commentType := 1; //1 - comment, 0 - delete
    linePosition := 1; //0 - insert in end of section; 1 - insert in currrent position

    WriteLn('Work with file ' + FileList[i]);

    //read new data
    S := TStringList.Create();
    S.LoadFromFile(newPath + '\' + FileList[i]);
    j := 0;

    while j < S.Count do
    begin
      k := Length(LineName);
      SetLength(LineComment, k+1);
      R := TRegExp.Create(nil);
      try
        R.Pattern := '\{\$([a-zA-Z]+)[\s\t]+([\d]+)\}';
        R.IgnoreCase := True;
        R.Global := True;
        mc := R.Execute(S.Strings[j]) as MatchCollection;
        if mc.Count > 0 then
        begin
          for ii:=0 to mc.Count-1 do
          begin
            m := mc[ii] as Match;
            sm := m.SubMatches as SubMatches;
            if (sm.Count > 0) then
            begin
              if (LowerCase(sm.Item[0]) = 'w') then
                workType := StrToInt(sm.Item[1])
              else if (LowerCase(sm.Item[0]) = 'c') then
                commentType := StrToInt(sm.Item[1])
              else if (LowerCase(sm.Item[0]) = 'p') then
                linePosition := StrToInt(sm.Item[1])
            end;
          end;
        end;
      finally
        m := nil;
        sm := nil;
        mc := nil;
        R.Free;
      end;

      SetLength(LineType, k+1);
      SetLength(LinePos, k+1);
      SetLength(LineCommentType, k+1);
      LineType[k] := IntToStr(workType);
      LineCommentType[k] := IntToStr(commentType);
      LinePos[k] := IntToStr(linePosition);

      R := TRegExp.Create(nil);
      try
        R.Pattern := 'class[\t\s]+([\d]+)[\s\t]+([a-zA-Z0-9_]+)[\t\s]*:[\s\t]*([a-zA-Z0-9_()]+)';
        R.IgnoreCase := True;
        R.Global := False;
        mc := R.Execute(S.Strings[j]) as MatchCollection;
        if mc.Count > 0 then
        begin
          m := mc[0] as Match;
          sm := m.SubMatches as SubMatches;
          if (sm.Count > 0) then
          begin
            SetLength(LineName, k+1);
            SetLength(LineParentName, k+1);
            SetLength(LineNameType, k+1);
            SetLength(LineText, k+1);
            LineName[k] := sm.Item[1];
            LineNameType[k] := sm.Item[0];
            LineParentName[k] := sm.Item[2];
          end;
        end;
      finally
        m := nil;
        sm := nil;
        mc := nil;
        R.Free;
      end;

      if (k < Length(LineName)) AND (LineName[k] <> '') then
      begin
        j := j + 1;
        WriteLn(' ' + ' class ' + LineName[k] + ' will be added');
        while(j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> 'class_end') do
        begin
          if (LineText[k] <> '') then
            LineText[k] := LineText[k] + CHAR(13) + CHAR(10) + S.Strings[j]
          else
            LineText[k] := S.Strings[j];
          j := j + 1;
        end
      end  //end if name <> ''
      else
      begin
        if (LineComment[k] <> '') then
          LineComment[k] := LineComment[k] + CHAR(13) + CHAR(10) + S.Strings[j]
        else
          LineComment[k] := S.Strings[j];
      end;
      j := j + 1;
    end; //end while j

  end; //end for i

  DeleteFile(workPath + '\' + 'ai.obj.bak');
  Line := ' Backup exists file... ';
  if (CopyFile(PChar(workPath + '\ai.obj'), PChar(workPath + '\ai.obj.bak'), true)) then
    Line := Line + 'OK'
  else
    Line := Line + 'Error #' + IntToStr(GetLastError) + ' [' + workPath + '\ai.obj]';
  WriteLn(Line);
  
  //read work data and parsing scripts
  WriteLn(' parsing ai.obj');
  if (FileExists(workPath + '\ai.obj') = false) then
  begin
    WriteLn('File ' + workPath + '\ai.obj not found!');
    exit;
  end;
  S := TStringList.Create();
  S.LoadFromFile(workPath + '\ai.obj');
  OutText := TStringList.Create();
  j := 0;
  SetLength(LinePosOrig, 0);
  SetLength(LinePosOrig, Length(LineName));
  SetLength(LineChildName, 0);
  SetLength(LineChildName, Length(LineName));
  SetLength(ParamValueOrig, 0);
  SetLength(ParamValueOrig, Length(LineName));
  while (j < S.Count) do
  begin
    if (trim(S.Strings[j]) <> 'class_end') AND (trim(Copy(S.Strings[j], 0, Length('class'))) = 'class') then
    begin
      R := TRegExp.Create(nil);
      try
        R.Pattern := 'class[\t\s]+([\d]+)[\s\t]+([a-zA-Z0-9_]+)[\t\s]*:[\s\t]*([a-zA-Z0-9_()]+)';
        R.IgnoreCase := True;
        R.Global := False;
        Name := '';
        mc := R.Execute(S.Strings[j]) as MatchCollection;
        if mc.Count > 0 then
        begin
          m := mc[0] as Match;
          sm := m.SubMatches as SubMatches;
          if (sm.Count > 0) then
          begin
            Name := sm.Item[1];
            ParentName := sm.Item[2];
          end;
        end;
      finally
        m := nil;
        sm := nil;
        mc := nil;
        R.Free;
      end;

      if (Name <> '') AND (InArray(Name, LineName, k)) then
      begin
        WriteLn(' class ' + Name + ' found in line ' + IntToStr(j + 1));
        LinePosOrig[k] := IntToStr(j);
        if (LineComment[k] <> '') AND ((StrToInt(LinePos[k]) = 1)) then
          OutText.Add(LineComment[k]);
        if (StrToInt(LinePos[k]) = 1) then
          OutText.Add('class ' + LineNameType[k] + ' ' + Name + ' : ' + LineParentName[k]);
        while (j < S.Count) AND (LowerCase(trim(S.Strings[j])) <> 'class_end') do
        begin
          j := j + 1;
          if (LowerCase(trim(S.Strings[j])) = 'parameter_define_begin') AND (StrToInt(LinePos[k]) = 0) then
          repeat
            if (ParamValueOrig[k] <> '') then
              ParamValueOrig[k] := ParamValueOrig[k] + CHAR(13) + CHAR(10) + S.Strings[j]
            else
              ParamValueOrig[k] := S.Strings[j];
            j := j + 1;
          until (j >= S.Count-1) OR (LowerCase(trim(S.Strings[j])) = 'parameter_define_end');
        end;
        if (LineText[k] <> '') AND (StrToInt(LinePos[k]) = 1) then
            OutText.Add(LineText[k]);
        if (StrToInt(LinePos[k]) = 1) then
          OutText.Add(S.Strings[j]);
      end
      else if (Name <> '')
              AND (LowerCase(ParentName) <> '(null)')
              AND (InArray(ParentName, LineName, k)) then
      begin
        if (StrToInt(LinePos[k]) = 0) AND (LineChildName[k] = '') then
        begin
          WriteLn('  The dependence of the added class ' + ParentName + ' with child ' + Name);
          LineChildName[k] := Name;
        end;
        OutText.Add(S.Strings[j]);
      end
      else
        OutText.Add(S.Strings[j]);
    end
    else
      OutText.Add(S.Strings[j]);
    j := j + 1;
  end; //while j < S.Count

  //insert clear class with childs
  for j:=0 to Length(LineName)-1 do
    if (LineChildName[j] <> '') then
    begin
      if (LinePosOrig[j] <> '') then
      begin
        OutText.Insert(StrToInt(LinePosOrig[j]), 'class_end');
        OutText.Insert(StrToInt(LinePosOrig[j]), 'class ' + LineNameType[j] + ' ' + LineName[j] + ' : ' + LineParentName[j]);
        ii := 0;
        Line := '';
        Line := (Copy(LineText[j], Pos('parameter_define_begin',LineText[j]), Pos('parameter_define_end', Linetext[j]) + Length('parameter_define_end')));
        if (Line <> '') then
        begin
            OutText.Insert(StrToInt(LinePosOrig[j])+1, Line);
            ii := 1;
        end;
        for k:=j to Length(LineName)-1 do
          if (LinePosOrig[k] <> '') then
            LinePosOrig[k] := IntToStr(StrToInt(LinePosOrig[k]) + 3 + ii);
      end;
    end;

  //add not-found classes
  for j:=0 to Length(LineName)-1 do
    if ((LinePosOrig[j] = '') OR (StrToInt(LinePos[j]) = 0)) AND (StrToInt(LineType[j]) <> 2) then
    begin
      if (StrToInt(LinePos[j]) <> 2) then
      begin
        OutText.Add('');
        if (LineComment[j] <> '') then
          OutText.Add(LineComment[j]);
        OutText.Add('class ' + LineNameType[j] + ' ' + LineName[j] + ' : ' + LineParentName[j]);
        OutText.Add(LineText[j]);
        OutText.Add('class_end');
      end;
    end;

  //add comments in end of file
  for j := Length(LineComment)-1 to Length(LineName)-1 do
    if (LineComment[j] <> '') then
      OutText.Add(LineComment[j]);

  cp := TEncoding.Create();
  OutText.SaveToFile(workPath + '\ai.obj', cp.Unicode);
end.
