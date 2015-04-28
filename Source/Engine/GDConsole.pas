{*******************************************************************************
*                            Genesis Device Engine                             *
*                   Copyright © 2007-2015 Luuk van Venrooij                    *
*                        http://www.luukvanvenrooij.nl                         *
*                         luukvanvenrooij84@gmail.com                          *
********************************************************************************
*                                                                              *
*  This file is part of the Genesis Device Engine.                             *
*                                                                              *
*  The Genesis Device Engine is free software: you can redistribute            *
*  it and/or modify it under the terms of the GNU Lesser General Public        *
*  License as published by the Free Software Foundation, either version 3      *
*  of the License, or any later version.                                       *
*                                                                              *
*  The Genesis Device Engine is distributed in the hope that                   *
*  it will be useful, but WITHOUT ANY WARRANTY; without even the               *
*  implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.    *
*  See the GNU Lesser General Public License for more details.                 *
*                                                                              *
*  You should have received a copy of the GNU General Public License           *
*  along with Genesis Device.  If not, see <http://www.gnu.org/licenses/>.     *
*                                                                              *
*******************************************************************************}   
unit GDConsole;

{$MODE Delphi}

{******************************************************************************}
{* Holds the console class for logging commands                               *}
{******************************************************************************}

interface

uses
  FGL,
  SysUtils,
  Classes,
  LCLIntf,
  LCLType,
  MMSystem,
  dglOpenGL,
  GDFont,
  GDConstants,
  GDStringParsing;

type

{******************************************************************************}
{* Console class                                                              *}
{******************************************************************************}

  TGDCommandType = (CT_BOOLEAN, CT_INTEGER, CT_FLOAT, CT_FUNCTION);

  PBoolean  = ^Boolean;
  PInteger  = ^Integer;
  PFloat    = ^Single;
  PFunction = procedure();

  TGDCommand = record
    Command     : String;
    Help        : String;
    CommandType : TGDCommandType;
    Bool        : PBoolean;
    Int         : PInteger;
    Float       : PFloat;
    Func        : PFunction;
  end;

  TGDCommandMap<TKey, TGDCommand> = class(TFPGMap<TKey, TGDCommand>)
  end;

{******************************************************************************}
{* Console class                                                              *}
{******************************************************************************}

  TGDConsole = class
  private
    FShow         : Boolean;
    FUse          : Boolean;
    FRow          : integer;
    FCursorUpdate : boolean;
    FUpdateTimer  : Integer;
    FLogFile      : String;
    FLogText      : TStringList;
    FCommand      : String;
  public
    CommandMap : TGDCommandMap<String, TGDCommand>;
    property Use  : Boolean read FUse write FUse;
    property Show : Boolean read FShow write FShow;
    property Command : String read FCommand write FCommand;


    constructor Create(aLogFile : String);
    destructor  Destroy(); override;

    procedure InitConsole();
    procedure Clear();

    procedure Render();
    procedure MoveUp();
    procedure MoveDown();
    procedure AddChar( aChar : Char );
    procedure RemoveChar();
    procedure Update();

    procedure Write(aString : String; aNewLine : boolean = true);
    procedure WriteOkFail(aResult : boolean; aError : String; aIncludeFailed : boolean = true);

    procedure AddCommand(const aCommand, aHelp : String; const aType : TGDCommandType; const aPointer : Pointer );
    procedure ExecuteCommand();
  end;

var
  Console : TGDConsole;

  procedure UpdateConsoleCallBack(TimerID, Msg: Uint; dwUser, dw1, dw2: DWORD); pascal;

implementation

uses
  GDRenderer;

{******************************************************************************}
{* Show help                                                                  *}
{******************************************************************************}

procedure Help();
var
  iStr : String;
  iI, iJ, iK : Integer;
  iCommand : TGDCommand;
  iList : TStringList;
begin
  Console.Write('');
  for ik := 0 to Console.CommandMap.Count - 1 do
  begin
    iCommand := Console.CommandMap.Data[ik];
    Console.Write(iCommand.Command + ' - ' + iCommand.Help);
  end;
  Console.Write('');
end;

{******************************************************************************}
{* Create the console class                                                   *}
{******************************************************************************}

constructor TGDConsole.Create(aLogFile : String);
begin
  Write('Log started at ' + DateToStr(Date()) + ', ' + TimeToStr(Time()));
  Write('Build: ' + ENGINE_INFO);
  FUse          := True;
  FShow         := False;
  FLogText      := TStringList.Create();
  FLogFile      := aLogFile;
  CommandMap    := TGDCommandMap<String, TGDCommand>.Create();
  FCursorUpdate := False;
  AddCommand('Help', 'Show help', CT_FUNCTION, @Help);
  FUpdateTimer  := TimeSetEvent(C_CURSOR_TIME, 0, @UpdateConsoleCallBack, 0, TIME_PERIODIC);
end;

{******************************************************************************}
{* Destroy the console class                                                  *}
{******************************************************************************}

destructor  TGDConsole.Destroy();
begin
  Write('Log ended at ' + DateToStr(Date()) + ', ' + TimeToStr(Time()));
  TimeKillEvent(FUpdateTimer);
  FreeAndNil(CommandMap);
  FreeAndNil(FLogText);
end;

{******************************************************************************}
{* Init the console                                                           *}
{******************************************************************************}

procedure TGDConsole.InitConsole();
begin
  Clear();
  FRow := FLogText.Count-1;
  FShow := false;
  FCommand := '';
end;

{******************************************************************************}
{* Clear the console                                                          *}
{******************************************************************************}

procedure TGDConsole.Clear();
begin
end;

{******************************************************************************}
{* Render the console                                                         *}
{******************************************************************************}

procedure TGDConsole.Render();
var
  iI,iJ : Integer;
begin
  If Not(FShow) then
  begin
    FRow := FLogText.Count-1;
    exit;
  end;

  Renderer.RenderState( RS_COLOR );
  glColor4f(0.4,0.4,0.4,0.7);
  glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
  glEnable(GL_BLEND);
  glBegin(GL_QUADS);
    glVertex2f(0, (R_HUDHEIGHT/2)-7);
    glVertex2f(R_HUDWIDTH, (R_HUDHEIGHT/2)-7);
    glVertex2f(R_HUDWIDTH, R_HUDHEIGHT);
    glVertex2f(0, R_HUDHEIGHT);
  glEnd;
  glDisable(GL_BLEND);
  glColor4f(1,1,1,1);
  glBegin(GL_LINES);
    glVertex2f(0,          (R_HUDHEIGHT/2)-7);
    glVertex2f(R_HUDWIDTH, (R_HUDHEIGHT/2)-7);
    glVertex2f(0,          (R_HUDHEIGHT/2)+25);
    glVertex2f(R_HUDWIDTH, (R_HUDHEIGHT/2)+25);
  glEnd;

  Renderer.RenderState(RS_TEXTS);
  iJ := 0;
  For iI := FRow downto FRow-C_MAX_LINES do
  begin
    If  ((iI) >= 0) then
    begin
      If copy(Uppercase(FLogText.Strings[iI]), 0, 5) = 'ERROR' then
        Font.Color.Red
      else
       Font.Color.White;
      Font.Render(0, (R_HUDHEIGHT/2)+28+(iJ*25), 0.40, FLogText.Strings[iI] );
      iJ := iJ + 1;
    end
  end;

  Font.Color.White;
  if FCursorUpdate then
     Font.Render(0, (R_HUDHEIGHT/2)-3, 0.40, FCommand + '_' )
  else
     Font.Render(0, (R_HUDHEIGHT/2)-3, 0.40, FCommand );

  glDisable(GL_BLEND);
end;

{******************************************************************************}
{* Move the shown text up                                                     *}
{******************************************************************************}

procedure TGDConsole.MoveUp();
begin
  If Not(FShow) then Exit;
  If FLogText.Count = 0 then exit;
  FRow := FRow - 1;
  If FRow < 0 then FRow := 0;
end;

{******************************************************************************}
{* Move the shown text down                                                   *}
{******************************************************************************}

procedure TGDConsole.MoveDown();
begin
  If Not(FShow) then Exit;
  If FLogText.Count = 0 then exit;
  FRow := FRow + 1;
  If FRow > FLogText.Count-1 then FRow := FLogText.Count-1;
end;

{******************************************************************************}
{* Add a character to the console command input                               *}
{******************************************************************************}

procedure TGDConsole.AddChar( aChar : Char );
begin
  If Not(FShow) then Exit;
  If Not(((Ord(aChar) >= 32) and (Ord(aChar) <= 126))) then Exit;
  If aChar = '`' then Exit;
  FCommand := FCommand + aChar;
end;

{******************************************************************************}
{* Remove a character to the console command input                            *}
{******************************************************************************}

procedure TGDConsole.RemoveChar();
begin
   If Not(FShow) then Exit;
   SetLength(FCommand, Length(FCommand)-1);
end;


{******************************************************************************}
{* Update the console                                                         *}
{******************************************************************************}

procedure TGDConsole.Update();
begin
  FCursorUpdate := Not( FCursorUpdate );
end;

{******************************************************************************}
{* Update Console Callback                                                    *}
{******************************************************************************}

procedure UpdateConsoleCallBack(TimerID, Msg: Uint; dwUser, dw1, dw2: DWORD); pascal;
begin
  Console.Update();
end;


procedure TGDConsole.Write(aString : String; aNewLine : boolean = true);
begin
  If FUse = False then exit;
  if aNewLine then
    FLogText.Add(aString)
  else
    FLogText.Strings[FLogText.Count-1] := FLogText.Strings[FLogText.Count-1] + aString;
  FLogText.SaveToFile(FLogFile);
end;

{******************************************************************************}
{* Write Ok or fail to the log                                                *}
{******************************************************************************}

procedure TGDConsole.WriteOkFail(aResult : boolean; aError : String; aIncludeFailed : boolean = true);
begin
  If aResult then
  begin
    Write('Ok', false);
  end
  else
  begin
    if aIncludeFailed then Write('Failed', false);
    Write('Error: ' + aError);
  end;
end;

{******************************************************************************}
{* Add a command to the console.                                              *}
{******************************************************************************}

procedure TGDConsole.AddCommand(const aCommand, aHelp : String; const aType : TGDCommandType; const aPointer : Pointer );
var
  iCommand : TGDCommand;
begin
  iCommand.Command      := lowercase(aCommand);
  iCommand.Help         := aHelp;
  iCommand.CommandType  := aType;
  case iCommand.CommandType of
    CT_BOOLEAN        : iCommand.Bool  := aPointer;
    CT_INTEGER        : iCommand.Int   := aPointer;
    CT_FLOAT          : iCommand.Float := aPointer;
    CT_FUNCTION       : iCommand.Func  := aPointer;
  end;
  CommandMap.Add(iCommand.Command,iCommand);
  CommandMap.Sort;
end;

{******************************************************************************}
{* Add a command to the console.                                              *}
{******************************************************************************}

procedure TGDConsole.ExecuteCommand();
var
  iIdx : Integer;
  iCommand : TGDCommand;
  iCommandStr  : String;
  iCommandPara : String;
  iStrPos : Integer;

function GetNextCommand(const aStr : String): String;
var
  iC   : AnsiChar;
begin
  result := '';
  while (iStrPos <= Length(aStr)) do
  begin
    iC := AnsiChar(aStr[iStrPos]);
    if CharacterIsWhiteSpace(iC) then
    begin
      Inc(iStrPos);
      Break;
    end
    else
    begin
      result := result + String(iC);
      Inc(iStrPos);
    end;
  end;
end;

begin
  //no command string so exit
  if FCommand = '' then exit;

  //add command string
  Write(FCommand);

  //get the command parameters
  iStrPos := 1;
  iCommandStr  := lowercase(GetNextCommand(FCommand));
  iCommandPara := lowercase(GetNextCommand(FCommand));

  //execute the commands
  if CommandMap.Find(iCommandStr, iIdx) then
  begin
    iCommand := CommandMap.Data[iIdx];
    if (iCommand.Bool = nil) and (iCommand.Int = nil) and
       (iCommand.Float = nil) and not(assigned(iCommand.Func)) then
      WriteOkFail(false, 'Command pointer nul!', false)
    else
    begin
      case iCommand.CommandType of
        CT_BOOLEAN   : begin
                         if iCommandPara = '0' then
                           iCommand.Bool^ := false
                         else if iCommandPara = '1' then
                           iCommand.Bool^ := true
                         else
                           WriteOkFail(false, 'Unknown Parameter!', false);
                       end;
        CT_INTEGER   : begin
                         try
                           iCommand.Int^ := StrToInt(iCommandPara);
                         except
                           WriteOkFail(false, 'Unknown Parameter!', false);
                         end;
                       end;
        CT_FLOAT     : begin
                         try
                           iCommand.Float^ := StrToFloat(iCommandPara);
                         except
                           WriteOkFail(false, 'Unknown Parameter!', false);
                         end;
                       end;
        CT_FUNCTION  : begin
                         try
                           iCommand.Func();
                         except
                           WriteOkFail(false, 'Unknown Parameter!' ,false);
                         end;
                       end;
      end;
    end;
  end
  else
    WriteOkFail(false, 'Unknown Command!', false);

  //reset some stuff
  FCommand := '';
  FRow := FLogText.Count-1;
end;

end.
