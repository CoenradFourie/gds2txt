program gds2txt;

{*******************************************************************************
*                                                                              *
* Author    :  Coenrad Fourie                                                  *
* Version   :  0.01.01                                                         *
* Date      :  September 2018                                                  *
* Copyright (c) 2018 Coenrad Fourie                                            *
*                                                                              *
* GDS2 binary file to text converter                                           *
*                                                                              *
* Last modification: 12 September 2018                                         *
*      First implementation                                                    *
*                                                                              *
* Permission is hereby granted, free of charge, to any person obtaining a copy *
* of this software and associated documentation files (the "Software"), to     *
* deal in the Software without restriction, including without limitation the   *
* rights to use, copy, modify, merge, publish, distribute, sublicense, and/or  *
* sell copies of the Software, and to permit persons to whom the Software is   *
* furnished to do so, subject to the following conditions:                     *
*                                                                              *
* The above copyright notice and this permission notice shall be included in   *
* all copies or substantial portions of the Software.                          *
*                                                                              *
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR   *
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,     *
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE  *
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER       *
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      *
* FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS *
* IN THE SOFTWARE.                                                             *
********************************************************************************}

{$IFDEF MSWINDOWS}
{$DEFINE Windows}
{$APPTYPE CONSOLE}
{$ENDIF MSWINDOWS}

{$R *.res}

uses
  {$IFDEF MSWINDOWS}
  System.SysUtils,
  {$ELSE}
  SysUtils,
  {$ENDIF}
  StringLib in 'StringLib.pas';

const
  VERSIONNUMBER = '0.01.01';
  COPYRIGHTNOTICE = 'Copyright 2018 Coenrad Fourie, Stellenbosch University.';
  BUILDDATE = '13 September 2018';
  INDENT = '    ';

var
  gdsFile : TByteFile;
  outFile : TextFile;
  verboseMode, compactMode : boolean;
  i : integer;


{ ----------------------------- CloseGDS2Text -------------------------------- }
procedure CloseGDS2Text(cText : string; cHaltCode : integer);
// Graceful exit
begin
  Writeln(outFile,'-----------------');
  Writeln(outFile,'Premature close - error: '+cText);
  CloseFile(outFile);
  CloseFile(gdsFile);
  WriteLn;
  ExitWithHaltCode(cText,cHaltCode);
end;
{ ------------------------------ ReadDateTime -------------------------------- }
function ReadDateTime : string;

var
  rYear, rMonth, rDay, rHour, rMin, rSec : word;
  rTime, rDate : TDateTime;

begin
  rYear := Word(Read2Bytes(gdsFile));
  rMonth := Word(Read2Bytes(gdsFile));
  rDay := Word(Read2Bytes(gdsFile));
  rHour :=Word(Read2Bytes(gdsFile));
  rMin := Word(Read2Bytes(gdsFile));
  rSec := Word(Read2Bytes(gdsFile));
  rDate := EncodeDate(rYear, rMonth, rDay);
  rTime := EncodeTime(rHour, rMin, rSec, 0);
  ReadDateTime := DateToStr(rDate) + ' ' + TimeToStr(rTime);
end;
{ ----------------------------- WriteToOutFile ------------------------------- }
procedure WriteToOutFile(wStr0, wStr1, wStr2 : string);

begin
  if compactMode then
    WriteLn(OutFile,wStr0+wStr1+' '+wStr2)
  else
  begin
    WriteLn(OutFile,wStr0+wStr1);
    WriteLn(OutFile,wStr0+INDENT+wStr2);
    WriteLn(OutFile);
  end;
end; // WriteToOutFile
{ ----------------------------- ReadGDSRecords ------------------------------- }
procedure ReadGDSRecords(rStr : string);

var
  rgi : integer;
  pRecLength : integer;
  pRecType : integer;
  pStr, rVerboseStr : string;
  rFinished : boolean;

begin
  rFinished := false;
  repeat
    pRecLength := Read2Bytes(gdsFile) - 4; //  when 4 bytes of header are read (2 bytes length; 2 bytes type, 4 less bytes left to do...
    if pRecLength < 0 then
      CloseGds2Text('Invalid record length in GDSII file.',2);
    pRecType := Read2Bytes(gdsFile);  // This is the record type
    rVerboseStr := '';
    if verboseMode then
      rVerboseStr := '  ('+IntToStr(pRecLength)+' bytes)';
    case pRecType of
      $0002 : begin  // Header
                WriteToOutfile(rStr,'HEADER'+rVerboseStr,'VERSION '+IntToStr(Read2Bytes(gdsFile)));
              end;
      $0102 : begin
                pStr := '[LAST MODIFICATION '+ReadDateTime+', LAST ACCESS ';
                pStr := pStr+ReadDateTime+']';
                WriteToOutfile(rStr,'BGNLIB'+rVerboseStr,pStr);
              end;
      $0206 : begin  // LIBNAME
                WriteToOutfile(rStr,'LIBNAME'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $0305 : begin  // UNITS
                WriteToOutfile(rStr,'UNITS'+rVerboseStr,FloatToStrF(Read8Real(gdsFile),ffGeneral,4,2)+' '+FloatToStrF(Read8Real(gdsFile),ffGeneral,4,2));
              end;
      $0400 : begin  // ENDLIB
                WriteLn(OutFile,rStr+'ENDLIB'+rVerboseStr);
                if not compactMode then
                  WriteLn(OutFile);
              end;
      $0502 : begin  // BGNSTR
                pStr := '['+ReadDateTime+', ';
                pStr := pStr+ReadDateTime+']';
                WriteToOutFile(rStr,'BGNSTR'+rVerboseStr,pStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0606 : begin  // STRNAME
                WriteToOutFile(rStr,'STRNAME'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $0700 : begin  // ENDSTR
                WriteLn(OutFile,'ENDSTR'+rVerboseStr);
                rFinished := true;
                if not compactMode then
                  WriteLn(OutFile);
              end;
      $0800 : begin  // BOUNDARY
                WriteLn(OutFile,rStr+'BOUNDARY'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0900 : begin  // PATH
                WriteLn(OutFile,rStr+'PATH'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0A00 : begin  // SREF
                WriteLn(OutFile,rStr+'SREF'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0B00 : begin  // AREF
                WriteLn(OutFile,rStr+'AREF'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0C00 : begin  // TEXT
                WriteLn(OutFile,rStr+'TEXT'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $0D02 : begin  // LAYER
                WriteToOutFile(rStr,'LAYER'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $0E02 : begin  // DATATYPE
                WriteToOutFile(rStr,'DATATYPE'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $0F03 : begin  // WIDTH
                WriteToOutFile(rStr,'WIDTH'+rVerboseStr,IntToStr(Read4Int(gdsFile)));
              end;
      $1003 : begin  // XY
                WriteLn(OutFile,rStr+'XY'+rVerboseStr+' '+IntToStr(pRecLength div 8));
                for rgi := 1 to (pRecLength div 8) do
                begin
                  pStr := IntToStr(Read4Int(gdsFile));
                  pStr := pStr + ', '+IntToStr(Read4Int(gdsFile));
                  WriteLn(OutFile,rStr+INDENT+pStr);
                end;
              end;
      $1100 : begin  // ENDEL
                WriteLn(OutFile,Copy(rStr,1,Length(rStr)-Length(INDENT))+'ENDEL'+rVerboseStr);
                if not compactMode then
                  WriteLn(OutFile);
                rFinished := true;
              end;
      $1206 : begin  // SNAME
                WriteToOutFile(rStr,'SNAME'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $1302 : begin  // COLROW
                WriteLn(OutFile,rStr+'COLROW'+rVerboseStr);
                pStr := IntToStr(Read2Bytes(gdsFile));
                pStr := pStr + ', '+IntToStr(Read2Bytes(gdsFile));
                WriteToOutFile(rStr,'COLROW'+rVerboseStr,pStr);
              end;
      $1500 : begin  // NODE
                WriteLn(OutFile,rStr+'NODE'+rVerboseStr);
                ReadGDSRecords(rStr+'    ');
              end;
      $1602 : begin  // TEXTTYPE
                WriteToOutFile(rStr,'TEXTTYPE'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $1701 : begin  // PRESENTATION
                WriteToOutFile(rStr,'PRESENTATION'+rVerboseStr,'0x'+IntToHex(Read2Bytes(gdsFile),4));
              end;
      $1906 : begin  // STRING
                WriteToOutFile(rStr,'STRING'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $1A01 : begin  // STRANS
                WriteToOutFile(rStr,'STRANS'+rVerboseStr,'0x'+IntToHex(Read2Bytes(gdsFile),4));
              end;
      $1B05 : begin  // MAG
                WriteToOutFile(rStr,'MAG'+rVerboseStr,FloatToStrF(Read8Real(gdsFile),ffGeneral,4,2));
              end;
      $1C05 : begin  // ANGLE
                WriteToOutFile(rStr,'ANGLE'+rVerboseStr,FloatToStrF(Read8Real(gdsFile),ffGeneral,4,2));
              end;
      $1F06 : begin  // REFLIBS
                WriteLn(OutFile,rStr+'REFLIBS'+rVerboseStr+' '+IntToStr(pRecLength div 44));
                for rgi := 1 to (pRecLength div 44) do
                  WriteLn(OutFile,rStr+INDENT+ReadASCIIString(gdsFile,44));
              end;
      $2006 : begin  // FONTS
                WriteLn(OutFile,rStr+'FONTS'+rVerboseStr+' '+IntToStr(pRecLength div 44));
                for rgi := 1 to (pRecLength div 44) do
                  WriteLn(OutFile,rStr+INDENT+ReadASCIIString(gdsFile,44));
              end;
      $2102 : begin  // PATHTYPE
                WriteToOutFile(rStr,'PATHTYPE'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $2202 : begin  // GENERATIONS
                WriteToOutFile(rStr,'GENERATIONS'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $2306 : begin  // ATTRTABLE
                WriteToOutFile(rStr,'ATTRTABLE'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $2601 : begin  // ELFLAGS
                WriteToOutFile(rStr,'ELFLAGS'+rVerboseStr,'0x'+IntToHex(Read2Bytes(gdsFile),4));
              end;
      $2A02 : begin  // NODETYPE
                WriteToOutFile(rStr,'NODETYPE'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $2B02 : begin  // PROPATTR
                WriteToOutFile(rStr,'PROPATTR'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $2C06 : begin  // PROPVALUE
                WriteToOutFile(rStr,'PROPVALUE'+rVerboseStr,ReadASCIIString(gdsFile,pRecLength));
              end;
      $2D00 : begin  // BOX
                WriteLn(OutFile,rStr+'BOX'+rVerboseStr);
                ReadGDSRecords(rStr+INDENT);
              end;
      $2E02 : begin  // BOXTYPE
                WriteToOutFile(rStr,'BOXTYPE'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $2F02 : begin  // PLEX
                WriteToOutFile(rStr,'PLEX'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $3202 : begin  // TAPENUM
                WriteToOutFile(rStr,'TAPENUM'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
      $3302 : begin  // TAPECODE
                pStr := '(';
                for rgi := 1 to 5 do
                  pStr := pStr+IntToStr(Read2Bytes(gdsFile))+',';
                pStr := pStr+IntToStr(Read2Bytes(gdsFile))+')';
                WriteToOutFile(rStr,'TAPECODE'+rVerboseStr,pStr);
              end;
      $3602 : begin  // FORMAT
                WriteToOutFile(rStr,'FORMAT'+rVerboseStr,IntToStr(Read2Bytes(gdsFile)));
              end;
// MASK ($3706) and ENDMASKS ($3800) ignored for now
    else // Record not supported
      SkipRecord(gdsFile,pRecLength); // Read rest of record and discard
    end;
  until (eof(gdsFile) or rFinished);
end; // ReadGDSRecords
{ ----------------------------- ParseGDS2Text -------------------------------- }
procedure ParseGDS2Text;

begin
  // ReadGDSRecords runs recursively (calls itself inside structures, paths, etc.)
  ReadGDSRecords('');
  WriteLn('Conversion successful.');
end; // ParseGDS2Text;
{ -------------------------------- BlurbHelp --------------------------------- }
procedure BlurbHelp;

begin
  Writeln; WriteLn('Gds2txt converts a basic GDS2 binary file to a text representation.');
  WriteLn('The first two parameters MUST be the GDS source file and the text target file.');
  WriteLn;
  WriteLn(' Options: (Case senstive arguments.)');
  WriteLn('  -c              = Compact mode (produces more compact file).');
  WriteLn('  -v              = Verbose mode.');
  WriteLn;
  WriteLn; WriteLn('For user support, e-mail your questions to coenrad@sun.ac.za'); WriteLn;
  Halt(0);
end; // BlurbHelp

{ ================================== MAIN ==================================== }
begin
  try
    verboseMode := false;
    if ParamCount = 1 then
      if (ParamStr(1) = '-h') or (ParamStr(1) = '-?') or (ParamStr(1) = '/h') or (ParamStr(1) =  '/?') or (ParamStr(1) = '-H') or (ParamStr(1) = '/H') then
        BlurbHelp; // BlurbHelp exits
    if ParamCount < 2 then
    begin
      Writeln('Filename required, e.g.');
      Writeln('  gds2txt source.gds target.txt [-c] [-v]');
      Writeln;
      WriteLn('  Type ''gds2txt -h'' or ''gds2txt /?'' or ''gds2txt -?'' for help.');
      Writeln;
      halt(0);
    end;
    WriteLn('gds2txt v' + VERSIONNUMBER + ' ('+BUILDDATE+'). ' + COPYRIGHTNOTICE);
    WriteLn;
    WriteLn('This program comes with ABSOLUTELY NO WARRANTY.');
    WriteLn;
    for i := 1 to ParamCount do
    begin
      if ParamStr(i) = '-v' then
        verboseMode := true;
      if ParamStr(i) = '-c' then
        compactMode := true;
    end;
    if compactMode then
      verboseMode := false;
    AssignFile(gdsFile,ParamStr(1));
    AssignFile(outFile,ParamStr(2));
    {$I-}
    Reset(gdsFile);
    {$I+}
    if IOResult <> 0 then
      ExitWithHaltCode('GDS2 file read error.',1);
    {$I-}
    Rewrite(outFile);
    {$I+}
    if IOResult <> 0 then
      ExitWithHaltCode('Text output file write error.',1);

    ParseGDS2Text;

    CloseFile(gdsFile);
    CloseFile(outFile);
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
