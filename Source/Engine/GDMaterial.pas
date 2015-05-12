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
unit GDMaterial;

{$MODE Delphi}

{******************************************************************************}
{* Holds the material classes                                                 *}
{******************************************************************************}

interface

Uses
  Classes,
  SysUtils,
  dglOpenGL,
  GDRenderer,
  GDTexture,
  GDConstants,
  GDFog,
  FileUtil,
  GDResource,
  GDTiming,
  GDStringParsing;

Type

{******************************************************************************}
{* Material class                                                             *}
{******************************************************************************}

  TGDMaterial = class (TGDResource)
  private
    FName    : String;
    FTexture : TGDTexture;
    FHasAlpha : Boolean;
    FAlphaFunc : double;
    FDoBloom : boolean;
    FDoTreeAnim : boolean;
  public
    property Name : String read FName write FName;
    property Texture : TGDTexture read FTexture write FTexture;
    property HasAlpha : Boolean read FHasAlpha write FHasAlpha;
    property AlphaFunc : double read FAlphaFunc write FAlphaFunc;
    property DoBloom : Boolean read FDoBloom write FDoBloom;
    property DoTreeAnim : Boolean read FDoTreeAnim write FDoTreeAnim;

    constructor Create();
    destructor  Destroy(); override;

    procedure   ApplyMaterial();
    procedure   DisableMaterial();
    procedure   BindMaterialTextures();
  end;
  
implementation

uses
  GDResources,
  GDLighting,
  GDFoliage;

{******************************************************************************}
{* Create material                                                            *}
{******************************************************************************}

constructor TGDMaterial.Create();
begin
end;

{******************************************************************************}
{* Destroy material                                                           *}
{******************************************************************************}

destructor TGDMaterial.Destroy();
begin
  Resources.RemoveResource(TGDResource(FTexture));
  FHasAlpha := false;
  FAlphaFunc := 1.0;
  FDoBloom := false;
  FDoTreeAnim := false;
  inherited;
end;

{******************************************************************************}
{* Apply material                                                             *}
{******************************************************************************}

procedure   TGDMaterial.ApplyMaterial();
begin
  Renderer.MeshShader.Enable();
  Renderer.MeshShader.SetFloat3('V_LIGHT_DIR', DirectionalLight.Direction.X,
                                               DirectionalLight.Direction.Y,
                                               DirectionalLight.Direction.Z);
  Renderer.MeshShader.SetFloat4('V_LIGHT_AMB', DirectionalLight.Ambient.R,
                                               DirectionalLight.Ambient.G,
                                               DirectionalLight.Ambient.B,
                                               DirectionalLight.Ambient.A);
  Renderer.MeshShader.SetFloat4('V_LIGHT_DIFF', DirectionalLight.Diffuse.R,
                                                DirectionalLight.Diffuse.G,
                                                DirectionalLight.Diffuse.B,
                                                DirectionalLight.Diffuse.A);
  Renderer.MeshShader.SetFloat('F_MIN_VIEW_DISTANCE', FogManager.FogShader.MinDistance);
  Renderer.MeshShader.SetFloat('F_MAX_VIEW_DISTANCE', FogManager.FogShader.MaxDistance);
  Renderer.MeshShader.SetFloat4('V_FOG_COLOR', FogManager.FogShader.Color.R,
                                               FogManager.FogShader.Color.G, FogManager.FogShader.Color.B,
                                               FogManager.FogShader.Color.A);
  Renderer.MeshShader.SetInt('T_COLORMAP', 0);

  if DoTreeAnim then
    Renderer.MeshShader.SetInt('I_DO_TREE_ANIM', 1)
  else
    Renderer.MeshShader.SetInt('I_DO_TREE_ANIM', 0);
  Renderer.MeshShader.SetFloat('F_ANIMATION_SPEED', Timing.ElapsedTime / Foliage.TreeAnimationSpeed);
  Renderer.MeshShader.SetFloat('F_ANIMATION_STRENGTH', Foliage.TreeAnimationStrength);

  if FHasAlpha then
  begin
    glEnable(GL_ALPHA_TEST);
    glAlphaFunc(GL_GREATER, FAlphaFunc);
    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
  end;
end;

{******************************************************************************}
{* Disable material                                                           *}
{******************************************************************************}

procedure TGDMaterial.DisableMaterial();
begin
  if FHasAlpha then
  begin
    glDisable(GL_ALPHA_TEST);
    glDisable(GL_BLEND);
  end;
end;

{******************************************************************************}
{* Bind the material textures                                                 *}
{******************************************************************************}

procedure   TGDMaterial.BindMaterialTextures();
begin
  FTexture.BindTexture( GL_TEXTURE0 );
end;

end.