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
unit GDRenderer;

{$MODE Delphi}

{******************************************************************************}
{* Hold the main renderer class. The render class is responsible for          *}
{* managing the opengl window, opengl states and GLSL shaders.                *}
{******************************************************************************}

interface

uses
  Graphics,
  Windows,
  SysUtils,
  dglOpenGL,
  GDConstants,
  GDSettings,
  GDTexture,
  GDGLObjects,
  GDConsole,
  GDModes,
  GDTiming;

type

{******************************************************************************}
{* Renderer class                                                             *}
{******************************************************************************}

  TGDRenderer  = Class
  private
    FInitialized        : boolean;

    FResourceWND        : HWND;
    FResourceDC         : HDC;
    FResourceRC         : HGLRC;

    FViewPortWND        : HWND;
    FViewPortDC         : HDC;
    FViewPortRC         : HGLRC;
    FCanResize          : boolean;
    FState              : TGDRenderState;
    
    FTerrainShader      : TGDGLShader;
    FSkyShader          : TGDGLShader;
    FWaterShader        : TGDGLShader;
    FGrassShader        : TGDGLShader;
    FBlurShader         : TGDGLShader;
    FBloomMixShader     : TGDGLShader;
    FMeshShader         : TGDGLShader;
    FFinalShader        : TGDGLShader;
    FCopyShader         : TGDGLShader;
    FColorShader        : TGDGLShader;
    FTextureShader      : TGDGLShader;

    FFrameBuffer         : TGDGLFrameBufferObject;
    FRenderBuffer1       : TGDGLRenderBufferObject;
    FRenderBuffer2       : TGDGLRenderBufferObject;
    FSourceImage1        : TGDTexture;
    FSourceImage2        : TGDTexture;
    FBloomImage          : TGDTexture;
    FHorizontalBlurImage : TGDTexture;
    FVerticalBlurImage   : TGDTexture;
    FBloomStrengh        : Double;

    procedure InitShaders();
    procedure ClearShaders();
    procedure InitFrameBuffers();
    procedure ClearFrameBuffers();
    Procedure ResizeFrameBuffers();

    procedure RenderQuad();
  public
    property    Initialized     : boolean read FInitialized;

    property    TerrainShader  : TGDGLShader read FTerrainShader;
    property    SkyShader      : TGDGLShader read FSkyShader;
    property    WaterShader    : TGDGLShader read FWaterShader;
    property    GrassShader    : TGDGLShader read FGrassShader;
    property    BlurShader     : TGDGLShader read FBlurShader;
    property    BloomMixShader : TGDGLShader read FBloomMixShader;
    property    CopyShader     : TGDGLShader read FCopyShader;
    property    MeshShader     : TGDGLShader read FMeshShader;
    property    FinalShader    : TGDGLShader read FFinalShader;
    property    ColorShader    : TGDGLShader read FColorShader;
    property    TextureShader  : TGDGLShader read FTextureShader;

    property    BloomStrengh : Double read FBloomStrengh write FBloomStrengh;

    Constructor Create();
    Destructor  Destroy();override;

    function    InitViewPort( aWnd  : HWND ): boolean;
    function    ShutDownViewPort() : boolean;
    procedure   ResizeViewPort();

    procedure   RenderState( aState : TGDRenderState );
    procedure   StartFrame();
    procedure   EndFrame();
    function    MakeCurrent() : boolean;
    procedure   SwitchToOrtho();
    procedure   SwitchToPerspective();
    procedure   VerticalSync();
    function    CheckUsePostProcessing(): boolean;
    procedure   StartRenderSource();
    procedure   EndRenderSource();
    procedure   StartRenderUnderWaterSource();
    procedure   EndRenderUnderWaterSource();
    procedure   StartRenderBloom();
    procedure   EndRenderBloom();
    procedure   ApplyBlurToImage( aSourceImage : TGDTexture; aBlurStrength : double );
    procedure   RenderFinal();
  end;

var
  Renderer : TGDRenderer;

implementation

uses
  GDMain,
  GDWater;

{******************************************************************************}
{* Create the renderer class                                                  *}
{******************************************************************************}

constructor TGDRenderer.Create();
var
  iError      : string;
  iWndClass   : TWndClass;
  iDWStyle    : DWORD;
  iDWExStyle  : DWORD;
  iInstance   : HINST;
  iStr        : String;
  iGLInt      : GLInt;
  iGLFLoat    : GLFLoat;

function WndProc(aWnd: HWND; aMsg: UINT;  aWParam: WPARAM;  aLParam: LPARAM): LRESULT; stdcall;
begin
  Result := 1;
end;

begin
  Inherited;
  FCanResize := false;

  Console.Write('Initializing renderer...');
  try
    FInitialized := true;
    iInstance := GetModuleHandle(nil);
    ZeroMemory(@iWndClass, SizeOf(wndClass));

    with iWndClass do
    begin
      style         := CS_HREDRAW or CS_VREDRAW or CS_OWNDC;
      lpfnWndProc   := @WndProc;
      hInstance     := iInstance;
      hCursor       := LoadCursor(0, IDC_ARROW);
      lpszClassName := 'OpenGL';
    end;

    if (RegisterClass(iWndClass) = 0) then
      Raise Exception.Create('Failed to register reource windows class');

    iDWStyle   := WS_OVERLAPPEDWINDOW or WS_CLIPCHILDREN or WS_CLIPSIBLINGS;
    iDWExStyle := WS_EX_APPWINDOW or WS_EX_WINDOWEDGE;
    FResourceWND := CreateWindowEx(iDWExStyle,
                                      'OpenGL',
                                      'Window',
                                      iDWStyle,
                                      0, 0,
                                      50, 50,
                                       0,
                                      0,
                                      iInstance,
                                      nil);

    if FResourceWND = 0 then
      Raise Exception.Create('Failed to create resource window');

    //Get the device context
    FResourceDC := GetDC(FResourceWND);
    if (FResourceDC = 0) then
      Raise Exception.Create('Failed to get a device context');

    //Create the OpenGL rendering context
    FResourceRC := CreateRenderingContext(FResourceDC, [opDoubleBuffered, opStereo], 32, 32, 0, 0, 0, 0);;
    if (FResourceRC = 0) then
      Raise Exception.Create('Failed to create a rendering context');

    //Activate the rendering context
    ActivateRenderingContext(FResourceDC, FResourceRC);

    //Read OpenGL properties and implementation
    ReadExtensions;
    ReadImplementationProperties;

    //Check requirements.
    glGetIntegerv(GL_MAX_TEXTURE_UNITS_ARB, @iGLInt);
    if iGLInt < MRS_TEXTURE_UNITS then
      Raise Exception.Create('Not ennough texture units!');

    glGetFloatv(GL_MAX_TEXTURE_MAX_ANISOTROPY_EXT, @iGLFLoat);
    if iGLFLoat < MRS_ANISOTROPIC_FILTERING then
      Raise Exception.Create('To low anisotropic filtering!');

    glGetFloatv(GL_MAX_TEXTURE_SIZE, @iGLFLoat);
    if iGLFLoat < MRS_TEXTURE_SIZE then
      Raise Exception.Create('To low texture size!');

    iStr := glGetString(GL_EXTENSIONS);
    If ((Pos('GL_ARB_shader_objects', iStr) <= 0) or
       (Pos('GL_ARB_fragment_program', iStr) <= 0) or
       (Pos('GL_ARB_fragment_shader', iStr) <= 0) or
       (Pos('GL_ARB_vertex_program', iStr) <= 0) or
       (Pos('GL_ARB_vertex_shader', iStr) <= 0)) then
      Raise Exception.Create('Opengl Shading Language not supported!');

    if Pos('GL_EXT_framebuffer_object', iStr) <= 0 then
      Raise Exception.Create('Frame Buffer Objects not supported!');

    //Set basic OpenGL settings.
    glClearColor(0.5, 0.5, 0.5, 1.0);
    glClearDepth(1.0);
    glEnable(GL_DEPTH_TEST);
    glCullFace(GL_BACK);
    glEnable(GL_CULL_FACE);
    glDepthFunc(GL_LESS);
    glActiveTexture(GL_TEXTURE0);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE1);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE2);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE3);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE4);
    glEnable(GL_TEXTURE_2D);
    glActiveTexture(GL_TEXTURE5);
    glEnable(GL_TEXTURE_2D);
    glHint(GL_PERSPECTIVE_CORRECTION_HINT, GL_NICEST);
    glHint(GL_POINT_SMOOTH_HINT, GL_NICEST);
    glHint(GL_LINE_SMOOTH_HINT, GL_NICEST);
    glHint(GL_POLYGON_SMOOTH_HINT, GL_NICEST);
    glEnable(GL_NORMALIZE);
    glDisable(GL_FOG);
    glDisable(GL_LIGHTING);

    //commands
    Console.AddCommand('RBloomMult', '0.0 to 1.0 : Set the bloom multiplier value', CT_FLOAT, @FBloomStrengh);
  except
    on E: Exception do
    begin
      iError := E.Message;
      FInitialized := false;
    end;
  end;

  Console.WriteOkFail(FInitialized, iError);

  If FInitialized then
    InitShaders();
end;

{******************************************************************************}
{* Destroy the renderer class                                                 *}
{******************************************************************************}

Destructor TGDRenderer.Destroy();
var
  iError  : string;
  iResult : boolean;
  iInstance   : HINST;
begin
  inherited;
  Console.Write('Shutting down renderer...');
  try
    //Clear shaders.
    ClearShaders();

    //Destroy rendering context
    DeactivateRenderingContext();
    DestroyRenderingContext(FResourceRC);

    //destroy the window
    if ((FResourceWND <> 0) and (not DestroyWindow(FResourceWND))) then
      Raise Exception.Create('Failed to destroy window');

    iInstance := GetModuleHandle(nil);
    if (not UnRegisterClass('OpenGL', iInstance)) then
      Raise Exception.Create('Failed to unregister window class');
  except
    on E: Exception do
    begin
      iError := E.Message;
      iResult := false;
    end;
  end;
  Console.WriteOkFail(iResult, iError);
end;

{******************************************************************************}
{* Init the viewport                                                          *}
{******************************************************************************}

function TGDRenderer.InitViewPort( aWnd  : HWND ): boolean;
var
  iError    : string;
begin
  Console.Write('Initializing viewport...');
  try
    Result := true;

    //get the device context
    FViewPortWND := aWnd;
    FViewPortDC := GetDC(FViewPortWND);
    if (FViewPortDC = 0) then
      Raise Exception.Create('Failed to get a device context');

    //Create the OpenGL rendering context
    FViewPortRC := CreateRenderingContext(FViewPortDC, [opDoubleBuffered, opStereo], 32, 32, 0, 0, 0, 0);;
    if (FViewPortRC = 0) then
      Raise Exception.Create('Failed to create a rendering context');

    //Activate and share the rendering context
    ActivateRenderingContext(FViewPortDC, FViewPortRC);
    wglShareLists(FResourceRC, FViewPortRC);

    ResizeViewPort();
    VerticalSync();
    InitFrameBuffers();

    FCanResize := true;
  except
    on E: Exception do
    begin
      iError := E.Message;
      result := false;
    end;
  end;
  Console.WriteOkFail(result, iError);

  if result then
    Main.InitBaseResources();
end;

{******************************************************************************}
{* Shutdown the renderer                                                      *}
{******************************************************************************}

function TGDRenderer.ShutDownViewPort() : boolean;
var
  iError    : string;
begin
  Console.Write('Shutting down viewport...');
  try
    FCanResize := false;
    result := true;
    Main.ClearBaseResources();
    ClearFrameBuffers();
    wglMakeCurrent(0, 0);
    if (not wglDeleteContext(FViewPortRC)) then
    begin
      FViewPortRC := 0;
      Raise Exception.Create('Unable to activate OpenGL rendering context!');
    end;
    if ((FViewPortDC > 1) and (ReleaseDC(FViewPortWND, FViewPortDC) = 0)) then
    begin
      FViewPortDC := 0;
      Raise Exception.Create('Release of device context failed!');
    end;
  except
    on E: Exception do
    begin
      iError := E.Message;
      result := false;
    end;
  end;

  Console.WriteOkFail(result, iError);
end;

{******************************************************************************}
{* Resize the windows viewport                                                *}
{******************************************************************************}

procedure TGDRenderer.ResizeViewPort();
begin
  if not(FCanResize) then exit;
  MakeCurrent();
  if (Settings.Height = 0) then
    Settings.Height := 1;
  glViewport(0, 0, Settings.Width, Settings.Height);
  glMatrixMode(GL_PROJECTION);
  glLoadIdentity();
  gluPerspective(45.0, Settings.Width/Settings.Height, 25, Settings.ViewDistance * R_VIEW_DISTANCE_STEP);
  glMatrixMode(GL_MODELVIEW);
  glLoadIdentity();
  ResizeFrameBuffers();
end;

{******************************************************************************}
{* Set the renderstate                                                        *}
{******************************************************************************}

procedure  TGDRenderer.RenderState( aState : TGDRenderState );
begin
  FState := aState;
  glPolygonMode(GL_FRONT, GL_FILL);
  glColor4f(1,1,1,1);
  glDisable(GL_BLEND);

  Case FState Of
    RS_COLOR   :   begin
                     FColorShader.Enable();
                   end;
    RS_WIREFRAME : begin
                     glPolygonMode(GL_FRONT_AND_BACK, GL_LINE);
                     glClearColor(0.3, 0.3, 0.3, 1.0);
                     FColorShader.Enable();
                   end;
    RS_TEXTS   :   begin
                     glEnable(GL_DEPTH_TEST);
                     glDepthFunc(GL_LEQUAL);
                     glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
                     glEnable(GL_BLEND);
                     FTextureShader.Enable();
                     FTextureShader.SetInt('T_COLORMAP', 0);
                   end;
     RS_TEXTURE  : begin
                     FTextureShader.Enable();
                     FTextureShader.SetInt('T_COLORMAP', 0);
                   end;
    end;
end;

{******************************************************************************}
{* Init the shaders                                                           *}
{******************************************************************************}

procedure TGDRenderer.InitShaders();
begin
  Timing.Start();
  Console.Write('......Initializing shaders');
  FTerrainShader  := TGDGLShader.Create();
  FTerrainShader.InitShaders( SHADER_TERRAIN );
  FSkyShader      := TGDGLShader.Create();
  FSkyShader.InitShaders( SHADER_SKY );
  FWaterShader    := TGDGLShader.Create();
  FWaterShader.InitShaders( SHADER_WATER );
  FGrassShader    := TGDGLShader.Create();
  FGrassShader.InitShaders( SHADER_GRASS );
  FBlurShader     := TGDGLShader.Create();
  FBlurShader.InitShaders( SHADER_BLUR );
  FBloomMixShader := TGDGLShader.Create();
  FBloomMixShader.InitShaders( SHADER_BLOOMMIX );
  FCopyShader   := TGDGLShader.Create();
  FCopyShader.InitShaders( SHADER_COPY );
  FMeshShader := TGDGLShader.Create();
  FMeshShader.InitShaders( SHADER_MESH );
  FFinalShader := TGDGLShader.Create();
  FFinalShader.InitShaders( SHADER_FINAL );
  FColorShader := TGDGLShader.Create();
  FColorShader.InitShaders( SHADER_COLOR );
  FTextureShader := TGDGLShader.Create();
  FTextureShader.InitShaders( SHADER_TEXTURE );
  Timing.Stop();
  Console.Write('......Done initializing shaders (' + Timing.TimeInSeconds + ' Sec)');
end;

{******************************************************************************}
{* Clear the shaders                                                          *}
{******************************************************************************}

procedure TGDRenderer.ClearShaders();
begin
  FreeAndNil(FTerrainShader);
  FreeAndNil(FSkyShader);
  FreeAndNil(FWaterShader);
  FreeAndNil(FGrassShader);
  FreeAndNil(FBlurShader);
  FreeAndNil(FBloomMixShader);
  FreeAndNil(FCopyShader);
  FreeAndNil(FMeshShader);
  FreeAndNil(FFinalShader);
  FreeAndNil(FColorShader);
  FreeAndNil(FTextureShader);
end;

{******************************************************************************}
{* Init the framebuffers                                                      *}
{******************************************************************************}

procedure TGDRenderer.InitFrameBuffers();
begin
  FFrameBuffer         := TGDGLFrameBufferObject.Create();
  FRenderBuffer1       := TGDGLRenderBufferObject.Create();
  FRenderBuffer2       := TGDGLRenderBufferObject.Create();
  FSourceImage1        := TGDTexture.Create();
  FSourceImage2        := TGDTexture.Create();
  FBloomImage          := TGDTexture.Create();
  FHorizontalBlurImage := TGDTexture.Create();
  FVerticalBlurImage   := TGDTexture.Create();
  FBloomStrengh        := 0.5;
  FFrameBuffer.InitFrameBuffer();
  FRenderBuffer1.InitRenderBuffer(Settings.Width, Settings.Height, GL_DEPTH_COMPONENT24);
  FRenderBuffer2.InitRenderBuffer(Settings.Width div 4, Settings.Height div 4, GL_DEPTH_COMPONENT24);
  FSourceImage1.RenderTextureFloat( Settings.Width, Settings.Height );
  FSourceImage2.RenderTextureFloat( Settings.Width, Settings.Height );
  FBloomImage.RenderTextureFloat( Settings.Width, Settings.Height );
  FHorizontalBlurImage.RenderTextureFloat( Settings.Width div 4, Settings.Height div 4);
  FVerticalBlurImage.RenderTextureFloat( Settings.Width div 4, Settings.Height div 4);
end;

{******************************************************************************}
{* Clear the framebuffers                                                     *}
{******************************************************************************}

procedure TGDRenderer.ClearFrameBuffers();
begin
  FreeAndNil(FFrameBuffer);
  FreeAndNil(FRenderBuffer1);
  FreeAndNil(FRenderBuffer2);
  FreeAndNil(FSourceImage1);
  FreeAndNil(FSourceImage2);
  FreeAndNil(FBloomImage);
  FreeAndNil(FHorizontalBlurImage);
  FreeAndNil(FVerticalBlurImage);
end;

{******************************************************************************}
{* Resize buffers                                                             *}
{******************************************************************************}

Procedure TGDRenderer.ResizeFrameBuffers();
begin
  ClearFrameBuffers();
  InitFrameBuffers();
end;

{******************************************************************************}
{* Start a frame                                                              *}
{******************************************************************************}

procedure TGDRenderer.StartFrame();
begin
  glClear(GL_DEPTH_BUFFER_BIT or GL_COLOR_BUFFER_BIT);
  glLoadIdentity;
end;

{******************************************************************************}
{* End a frame                                                                *}
{******************************************************************************}

procedure TGDRenderer.EndFrame();
begin
  SwapBuffers(FViewPortDC);
end;

{******************************************************************************}
{* Make the rendercontext current                                             *}
{******************************************************************************}

function TGDRenderer.MakeCurrent() : boolean;
begin
  Result := wglMakeCurrent(FViewPortDC, FViewPortRC);
end;

{******************************************************************************}
{* Switch to ortho view                                                       *}
{******************************************************************************}

procedure TGDRenderer.SwitchToOrtho();
begin
  glEnable(GL_DEPTH_TEST);
  glMatrixMode(GL_PROJECTION);
  glPushMatrix();
  glLoadIdentity();
  glOrtho(0, R_HUDWIDTH, 0, R_HUDHEIGHT, -1, 1);
  glMatrixMode(GL_MODELVIEW);
  glPushMatrix();
  glLoadIdentity();
end;

{******************************************************************************}
{* Switch to perspective view                                                 *}
{******************************************************************************}

procedure TGDRenderer.SwitchToPerspective();
begin
  glEnable(GL_DEPTH_TEST);
  glMatrixMode(GL_PROJECTION);
  glPopMatrix();
  glMatrixMode(GL_MODELVIEW);
  glPopMatrix();
end;

{******************************************************************************}
{* Set vertical sync on or off                                                *}
{******************************************************************************}

procedure TGDRenderer.VerticalSync();
var
   iI : Integer;
begin
   if WGL_EXT_swap_control then
   begin
      iI := wglGetSwapIntervalEXT;

      If Settings.VerticalSync then
        if iI<>1 then
          wglSwapIntervalEXT(1);

      If not(Settings.VerticalSync) then
        if iI<>0 then
          wglSwapIntervalEXT(0);
   end;
end;

{******************************************************************************}
{* Check if post processing is used al together                               *}
{******************************************************************************}

function TGDRenderer.CheckUsePostProcessing(): boolean;
begin
  If ((Settings.UseBloom) or (Water.UnderWater) ) then
    result := true
  else
    result := false;
end;

{******************************************************************************}
{* Render the screen quad for post processing                                 *}
{******************************************************************************}

procedure TGDRenderer.RenderQuad();
begin
  glBegin(GL_QUADS);
    glTexCoord2f(0, 0);   glVertex2f(-1, -1);
    glTexCoord2f(1, 0);   glVertex2f( 1, -1);
    glTexCoord2f(1, 1);   glVertex2f( 1, 1);
    glTexCoord2f(0, 1);   glVertex2f(-1, 1);
  glEnd;
end;

{******************************************************************************}
{* Start the rendering of the source image                                    *}
{******************************************************************************}

procedure TGDRenderer.StartRenderSource();
begin
  FFrameBuffer.Bind();
  FFrameBuffer.AttachTexture(FSourceImage1,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer1,GL_DEPTH_ATTACHMENT_EXT);
  FFrameBuffer.Status();
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
end;

{******************************************************************************}
{* End the rendering of the source image                                      *}
{******************************************************************************}

procedure TGDRenderer.EndRenderSource();
begin
  FFrameBuffer.UnBind();
end;

{******************************************************************************}
{* Start the rendering of the underwater source image                         *}
{******************************************************************************}

procedure TGDRenderer.StartRenderUnderWaterSource();
begin
  FFrameBuffer.Bind();
  FFrameBuffer.AttachTexture(FSourceImage1,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer1,GL_DEPTH_ATTACHMENT_EXT);
  FFrameBuffer.Status();
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
end;

{******************************************************************************}
{* End the rendering of the underwater source image                           *}
{******************************************************************************}

procedure TGDRenderer.EndRenderUnderWaterSource();
begin
  FFrameBuffer.UnBind();
  ApplyBlurToImage( FSourceImage1, 3 );

  glDisable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  FFrameBuffer.Bind();
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer1, GL_DEPTH_ATTACHMENT_EXT);
  FFrameBuffer.AttachTexture(FSourceImage2,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.Status();

  CopyShader.Enable();
  CopyShader.SetInt('T_SOURCE_IMAGE',0);
  FVerticalBlurImage.BindTexture( GL_TEXTURE0 );
  RenderQuad();
  CopyShader.Disable();

  FFrameBuffer.Unbind();
  glEnable(GL_DEPTH_TEST);
end;

{******************************************************************************}
{* Start the rendering of the bloom image                                     *}
{******************************************************************************}

procedure TGDRenderer.StartRenderBloom();
begin
  FFrameBuffer.Bind();
  FFrameBuffer.AttachTexture(FBloomImage,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer1,GL_DEPTH_ATTACHMENT_EXT);
  FFrameBuffer.Status();
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
end;

{******************************************************************************}
{* End the rendering of the bloom image                                       *}
{******************************************************************************}

procedure TGDRenderer.EndRenderBloom();
begin
  FFrameBuffer.UnBind();
  ApplyBlurToImage( FBloomImage, 1.5 );

  glDisable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  BloomMixShader.Enable();
  BloomMixShader.SetInt('T_SOURCE_IMAGE',0);
  BloomMixShader.SetInt('T_BLUR_IMAGE',1);
  BloomMixShader.SetFloat('I_BLOOM_STENGTH',FBloomStrengh);
  FFrameBuffer.Bind();
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer1, GL_DEPTH_ATTACHMENT_EXT);
  FFrameBuffer.AttachTexture(FSourceImage2,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.Status();

  FSourceImage1.BindTexture( GL_TEXTURE0 );
  FVerticalBlurImage.BindTexture( GL_TEXTURE1 );
  RenderQuad();

  FFrameBuffer.Unbind();
  BloomMixShader.Disable();
  glEnable(GL_DEPTH_TEST);
end;

{******************************************************************************}
{* Apply blur to a source image                                               *}
{******************************************************************************}

procedure TGDRenderer.ApplyBlurToImage( aSourceImage : TGDTexture; aBlurStrength : double );
begin
  glViewport(0, 0, Settings.Width div 4, Settings.Height div 4);
  glDisable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);
  BlurShader.Enable();
  BlurShader.SetInt( 'T_BLUR_IMAGE', 0 );
  FFrameBuffer.Bind();
  FFrameBuffer.AttachRenderBufferObject(FRenderBuffer2, GL_DEPTH_ATTACHMENT_EXT);

  //horizontal
  FFrameBuffer.AttachTexture(FHorizontalBlurImage,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.Status();

  BlurShader.SetFloat4('V_BLUR_OFFSET',aBlurStrength / Settings.Width, 0, 0, 1);
  aSourceImage.BindTexture( GL_TEXTURE0 );
  RenderQuad();

  //vertical
  FFrameBuffer.AttachTexture(FVerticalBlurImage,GL_COLOR_ATTACHMENT0_EXT,GL_TEXTURE_2D);
  FFrameBuffer.Status();
  BlurShader.SetFloat4('V_BLUR_OFFSET', 0, aBlurStrength / Settings.Height, 0, 1);
  FHorizontalBlurImage.BindTexture( GL_TEXTURE0 );
  RenderQuad();;

  FFrameBuffer.Unbind();
  BlurShader.Disable();

  glEnable(GL_DEPTH_TEST);
  glViewport(0, 0, Settings.Width, Settings.Height);
end;

{******************************************************************************}
{* Render the final source image                                              *}
{******************************************************************************}

procedure TGDRenderer.RenderFinal();
begin
  glDisable(GL_DEPTH_TEST);
  glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

  FinalShader.Enable();
  FinalShader.SetInt('T_SOURCE_IMAGE',0);

  If Settings.UseFXAA and not(Modes.RenderObjectBoxes or Modes.RenderNormals or Modes.RenderNodeBoxes) then
    FinalShader.SetInt('I_DO_FXAA',1)
  else
    FinalShader.SetInt('I_DO_FXAA',0);
  FinalShader.SetFloat2('V_SCREEN_SIZE',Settings.Width, Settings.Height);
  FinalShader.SetFloat('I_GAMMA',Settings.Gamma);

  if Water.UnderWater then
  begin
    FSourceImage2.BindTexture( GL_TEXTURE0 );
  end
  else
  begin
    If Settings.UseBloom then
      FSourceImage2.BindTexture( GL_TEXTURE0 )
    else
      FSourceImage1.BindTexture( GL_TEXTURE0 );
  end;

  RenderQuad();

  FinalShader.Disable();
  glEnable(GL_DEPTH_TEST);
end;

end.
