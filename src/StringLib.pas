unit StringLib;

{*******************************************************************************
*    Unit StringLib (for use with gds2txt)                                     *
*    Copyright (c) 2018 Coenrad Fourie                                         *
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

interface

uses
  SysUtils, Math;

type
  TByteFile = file of Byte;

procedure ExitWithHaltCode(EText : string; HCode : integer);

function Read8Real(var r8File : TByteFile) : double;
function Read4Int(var r4File : TByteFile) : integer;
function Read2Bytes(var rrFile : TByteFile) : integer;
function ReadASCIIString(var raFile : TByteFile; raBytes : integer) : string;
procedure SkipRecord(var rrFile : TByteFile; srBytes : integer);

implementation

{ ---------------------------- ExitWithHaltCode ------------------------------ }
procedure ExitWithHaltCode(EText : string; HCode : integer);
// Writes text to screen and halts
begin
  WriteLn('('+IntToStr(HCode)+') '+EText);
  Halt(HCode);
end; // ExitWithHaltCode

// GDS2 Routines //

{ ------------------------------- Read8Real ---------------------------------- }
function Read8Real(var r8File : TByteFile) : double;

type
  TEightByte = array[1..8] of byte;
var
  eightByte : ^TEightByte;
  r8Value : double;
  r8Mantissa : Int64;
  r8Exponent : integer;
  r8i : shortint;
begin
  r8Mantissa := 0;
  r8Value    := 0;
  eightByte  := @r8Value;                // point eightByte to r8Value
  for r8i := 1 to 8 do
    Read(r8File,eightByte^[r8i]);
  r8Exponent := eightByte^[1];
  for r8i := 2 to 8 do
    r8Mantissa := (r8Mantissa shl 8) or eightByte^[r8i];
  if r8Exponent = 0 then  // Special case - zero
    begin
      Read8Real := 0;
      exit;
    end;
  if r8Exponent > 127 then
    begin
      dec(r8Exponent, 128);
      r8Value := -1*(r8Mantissa/IntPower(2,56))*IntPower(16,(r8Exponent-64));
    end
    else
      r8Value := 1.0*(r8Mantissa/IntPower(2,56))*IntPower(16,(r8Exponent-64));
  Read8Real := r8Value;
end; // Read8Real
{ -------------------------------- Read4Int ---------------------------------- }
function Read4Int(var r4File : TByteFile) : integer;

var
  r4Value, r4i : integer;
  r8Byte : byte;

begin
  r4Value := 0;
  for r4i := 1 to 4 do
    begin
      Read(r4File, r8Byte);
      r4Value := (r4Value shl 8) or r8Byte;
    end;
  Read4Int := r4Value;
end; // Read4Int
{ ------------------------------- Read2Bytes --------------------------------- }
function Read2Bytes(var rrFile : TByteFile) : integer;

var
  rrByte : byte;
  rrInt : integer;

begin
  Read(rrFile,rrByte);
  rrInt := rrByte;
  Read(rrFile,rrByte);
  rrInt := (rrInt shl 8) or rrByte;
  Read2Bytes := rrInt;
end; // Read2Bytes
{ ---------------------------- ReadASCIIString ------------------------------- }
function ReadASCIIString(var raFile : TByteFile; raBytes : integer) : string;

var
  raByte : byte;
  rai : integer;
  raStr : string;

begin
  raStr := '';
  for rai := 1 to raBytes do
  begin
    Read(raFile,raByte);
    if raByte <> 0 then // Ignore null character
      raStr := raStr + chr(raByte);
  end;
  ReadASCIIString := '"'+raStr+'"';
end; // ReadASCIIString
{ ------------------------------- SkipRecord --------------------------------- }
procedure SkipRecord(var rrFile : TByteFile; srBytes : integer);

var
  sri : integer;
  srEmptyByte : byte;

begin
  for sri := 1 to srBytes do
    Read(rrFile, srEmptyByte);
end;


end.
