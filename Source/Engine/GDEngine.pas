{*******************************************************************************
*                            Genesis Device Engine                             *
*                   Copyright © 2007-2015 Luuk van Venrooij                    *
*                        http://www.luukvanvenrooij.nl                         *
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
unit GDEngine;

{$MODE Delphi}

{******************************************************************************}
{* This is the main unit of the engine. It holds the main variables,          *}
{* callbacks and loops controling the engine. This unit will later be extended*}
{* with multible threads for the different systems                            *}
{******************************************************************************}

interface

uses
  LCLIntf,
  LCLType,
  SysUtils,
  dglOpenGL,
  GDRenderer,
  GDConsole,
  GDTiming,
  GDConstants,
  GDInput,
  GDGUI,
  GDMap,
  GDResources,
  GDSound,
  GDModes,
  GDCamera,
  GDSettings,
  GDStatistics;

type

{******************************************************************************}
{* Engine class                                                               *}
{******************************************************************************}

  TGDEngine  = Class
  private
    FTiming     : TGDTiming;
    FConsole    : TGDConsole;
    FSettings   : TGDSettings;

    FInput      : TGDInput;
    FSound      : TGDSound;
    FRenderer   : TGDRenderer;

    FStatistics : TGDStatistics;
    FModes      : TGDModes;
    FResources  : TGDResources;
    FCamera     : TGDCamera;
    FMap        : TGDMap;
    FGUI        : TGDGUI;

    function GetVersion(): String;

    constructor Create();
    destructor  Destroy(); override;

    function  InitSystems(): boolean;
    procedure ClearSystems();
  public
    property Version    : String read GetVersion;
    property Timing     : TGDTiming read FTiming;
    property Console    : TGDConsole read FConsole;
    property Settings   : TGDSettings read FSettings;

    property Input      : TGDInput read FInput;
    property Sound      : TGDSound read FSound;
    property Renderer   : TGDRenderer read FRenderer;

    property Statistics : TGDStatistics read FStatistics;
    property Modes      : TGDModes read FModes;
    property Resources  : TGDResources read FResources;
    property Camera     : TGDCamera read FCamera;
    property Map        : TGDMap read FMap;
    property GUI        : TGDGUI read FGUI;

    procedure Reset();

    procedure Loop(aCallback : TGDCallback);
  end;

var
  Engine : TGDEngine;

implementation

{******************************************************************************}
{* Get engine version                                                         *}
{******************************************************************************}

function TGDEngine.GetVersion(): String;
begin
  result := ENGINE_INFO;
end;

{******************************************************************************}
{* Create engine class                                                        *}
{******************************************************************************}

constructor TGDEngine.Create();
begin
  DefaultFormatSettings.DecimalSeparator := '.';
end;

{******************************************************************************}
{* Destroy main class                                                         *}
{******************************************************************************}

destructor TGDEngine.Destroy();
begin
  inherited;
end;

{******************************************************************************}
{* Init engine Systems                                                        *}
{******************************************************************************}

function TGDEngine.InitSystems(): boolean;
begin
  FTiming     := TGDTiming.Create();
  FConsole    := TGDConsole.Create();
  FSettings   := TGDSettings.Create();

  FInput      := TGDInput.Create();
  FSound      := TGDSound.Create();
  FRenderer   := TGDRenderer.Create();
  result      := FSound.Initialized and FInput.Initialized and FRenderer.Initialized;

  FStatistics := TGDStatistics.Create();
  FModes      := TGDModes.Create();
  FResources  := TGDResources.Create();
  FCamera     := TGDCamera.Create();
  FMap        := TGDMap.Create();
  FGUI        := TGDGUI.Create();
end;

{******************************************************************************}
{* Clear engine Systems                                                       *}
{******************************************************************************}

procedure TGDEngine.ClearSystems();
begin
  FreeAndNil(FStatistics);
  FreeAndNil(FModes);

  FreeAndNil(FInput);
  FreeAndNil(FSound);
  FreeAndNil(FRenderer);

  FreeAndNil(FTiming);
  FreeAndNil(FConsole);
  FreeAndNil(FSettings);
  FreeAndNil(FCamera);
  FreeAndNil(FGUI);
  FreeAndNil(FMap);
  FreeAndNil(FResources);
end;

{******************************************************************************}
{* Clear the base resources                                                   *}
{******************************************************************************}

procedure TGDEngine.Reset();
begin
  Console.Reset();
  Modes.Reset();
  Input.Clear();
  Map.Clear();
  Resources.Clear();
end;

{******************************************************************************}
{* Main loop of the engine                                                    *}
{******************************************************************************}

procedure TGDEngine.Loop(aCallback : TGDCallback);
begin
  //start timing
  Statistics.FrameStart();
  Timing.CalculateFrameTime();

  Input.Update();
  Sound.Update();
  Map.Update();
  if assigned(aCallback) then aCallback();
  Renderer.Render();

  //end timing
  Statistics.FrameStop();
  Statistics.Update();
end;

initialization
  Engine   := TGDEngine.Create();
  If not(Engine.InitSystems()) then
  begin
    MessageBox(0, 'Error starting engine! See log for details.', 'Error', MB_OK);
    halt;
  end;
finalization
  Engine.ClearSystems();
  FreeAndNil(Engine);
end.