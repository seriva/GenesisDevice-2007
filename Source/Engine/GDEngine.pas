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
  SysUtils,
  sdl2,
  dglOpenGL,
  GDRenderer,
  GDConsole,
  GDTiming,
  GDConstants,
  GDInput,
  GDGUI,
  GDMap,
  GDWindow,
  GDResources,
  GDSound,
  GDModes,
  GDPhysics,
  GDCamera,
  GDSettings,
  GDStatistics;

type

{******************************************************************************}
{* Engine class                                                               *}
{******************************************************************************}

  TGDEngine = Class
  private
    FDone 			: boolean;
    FTiming     : TGDTiming;
    FConsole    : TGDConsole;
    FSettings   : TGDSettings;

    FWindow			: TGDWindow;
    FInput      : TGDInput;
    FSound      : TGDSound;
    FPhysics    : TGDPhysics;
    FRenderer   : TGDRenderer;

    FStatistics : TGDStatistics;
    FModes      : TGDModes;
    FResources  : TGDResources;
    FCamera     : TGDCamera;
    FMap        : TGDMap;
    FGUI        : TGDGUI;


    function  InitSDL(): Boolean;
    function  InitSystems(): boolean;
    procedure ClearSystems();
  public
    property Done       : Boolean read FDone write FDone;

    property Timing     : TGDTiming read FTiming;
    property Console    : TGDConsole read FConsole;
    property Settings   : TGDSettings read FSettings;

    property Window			: TGDWindow read FWindow;
    property Input      : TGDInput read FInput;
    property Sound      : TGDSound read FSound;
    property Physics    : TGDPhysics read FPhysics;
    property Renderer   : TGDRenderer read FRenderer;

    property Statistics : TGDStatistics read FStatistics;
    property Modes      : TGDModes read FModes;
    property Resources  : TGDResources read FResources;
    property Camera     : TGDCamera read FCamera;
    property Map        : TGDMap read FMap;
    property GUI        : TGDGUI read FGUI;

    constructor Create();
    destructor  Destroy(); override;

    procedure Reset();

    procedure Init(aInit : TGDCallback);
		procedure Clear(aClear : TGDCallback);
    procedure Loop(aLoop : TGDCallback);
  end;

var
  Engine : TGDEngine;

implementation

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
{* Init SDL                                                                   *}
{******************************************************************************}

function  TGDEngine.InitSDL(): Boolean;
var
  iVersion : TSDL_Version;
  iV1, iV2 : String;
begin
  Inherited;
  Console.Write('.....Initializing SDL');
  try
    result := not(SDL_Init(SDL_INIT_VIDEO or SDL_INIT_TIMER) < 0);
    if result then
    begin
      SDL_GetVersion(@iVersion);
      iV1 :=  IntToStr(iVersion.major) + '.' + IntToStr(iVersion.minor) + '.' + IntToStr(iVersion.patch);
      iV2 :=  IntToStr(MRS_SDL_MAJOR_VERSION) + '.' + IntToStr(MRS_SDL_MINOR_VERSION) + '.' + IntToStr(MRS_SDL_PATCH_VERSION);
      Console.Write('  Version: ' + iV1);
      if (iV1 <> iV2) then
        Raise Exception.Create('SDL version ' + iV2 + ' required.');
    end
    else
    	Raise Exception.Create(SDL_GetError());
    Console.Write('.....Done initializing SDL');
  except
    on E: Exception do
    begin
      result := false;
      Console.Write('Failed to initialize SDL: ' + E.Message);
    end;
  end;
end;

{******************************************************************************}
{* Init engine Systems                                                        *}
{******************************************************************************}

function TGDEngine.InitSystems(): boolean;
var
  iSDLInit : boolean;
begin
  FConsole    := TGDConsole.Create();
  FSettings   := TGDSettings.Create();
  iSDLInit    := InitSDL();
  FTiming     := TGDTiming.Create();
  FWindow     := TGDWindow.Create();
  FInput      := TGDInput.Create();
  FRenderer   := TGDRenderer.Create();
  FSound      := TGDSound.Create();
  FPhysics    := TGDPhysics.Create();
  result      := FInput.Initialized and FRenderer.Initialized and FWindow.Initialized and FPhysics.Initialized and iSDLInit ;
  FStatistics := TGDStatistics.Create();
  FModes      := TGDModes.Create();
  FResources  := TGDResources.Create();
  FResources.Sorted := True;
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
  FreeAndNil(FPhysics);
  FreeAndNil(FRenderer);
  FreeAndNil(FGUI);
  FreeAndNil(FMap);
  FreeAndNil(FWindow);

  SDL_Quit();
  Engine.Console.Write('Shutting down SDL...Ok');

  FreeAndNil(FTiming);
  FreeAndNil(FConsole);
  FreeAndNil(FSettings);
  FreeAndNil(FCamera);

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
  FGUI.ClearScreens();
  Resources.Clear();
end;

{******************************************************************************}
{* Init                                                                       *}
{******************************************************************************}

procedure TGDEngine.Init(aInit : TGDCallback);
begin
  Window.Show();
  Renderer.InitViewPort();
  Renderer.ResizeViewPort(Settings.Width, Settings.Height);
  SDL_ShowCursor(0);
  Engine.Done := false;
  if assigned(aInit) then aInit();
end;

{******************************************************************************}
{* Clear                                                                      *}
{******************************************************************************}

procedure TGDEngine.Clear(aClear : TGDCallback);
begin
  Window.Hide();
  if assigned(aClear) then aClear();
  Renderer.ClearViewPort();
  Reset();
  SDL_ShowCursor(1);
end;

{******************************************************************************}
{* Loop                                                                       *}
{******************************************************************************}

procedure TGDEngine.Loop(aLoop : TGDCallback);
begin
  //start timing
  Statistics.FrameStart();
  Timing.CalculateFrameTime();

  //Update all systems
  Window.Update();
  Input.Update();
  Sound.Update();
  Map.Update();
  if assigned(aLoop) then aLoop();

  //Render the scene
  Renderer.Render();
  Window.Swap();

  //end timing
  Statistics.FrameStop();
  Statistics.Update();
end;

initialization
  Engine := TGDEngine.Create();
  If not(Engine.InitSystems()) then
  begin
    halt;
  end;
finalization
  Engine.ClearSystems();
  FreeAndNil(Engine);
end.
