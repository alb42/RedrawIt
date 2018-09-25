program RedrawIt;
{$mode objfpc}{$H+}
{$WARNINGS OFF}
{$NOTES OFF}
uses
  Classes, SysUtils, Exec, AGraphics, Intuition, Utility, Math, Types, inputevent, fgl;

const
  VERSION = '$VER: RedrawIt 0.1 (01.08.2018)';

type
  TAnimDir = (adRight, adLeft, adBottom);
  TLevelType =(ltRandom, ltTutorial, ltUser, ltFile);
    //
  TArea = array of array of Boolean; // Playfield Area
  TAxis = array of array of Integer; // Side Numbers for X and Y Axis
  //
  TAnimPoint = record
    x1,y1, x2, y2, x3, y3, x4, y4: Word;
    Fill: Boolean;
  end;

  // Level File
  TDataHead = packed record
    Magic: array[0..3] of Char;
    Name: array[0..31] of Char;
    Num: Integer;
  end;

  TLevelHead = packed record
    Number: LongInt;
    Text: array[0..255] of Char;
    Magic: LongWord;
    NumX, NumY: Word;
  end; // Followed by NumX*NumY bytes
  // End Level File

  // Program Levels
  TLevelFile = record
    LevelName: string;
    Filename: string;
  end;
  TLevelFiles = array of TLevelFile;

  TLevel = record
    Name: string;
    Magic: LongWord;
    NumX, NumY: Integer;
    Enabled: Boolean;
    Field: TArea;
  end;
  TLevels = array of TLevel;


const
  PtAnim : array[0..9] of TAnimPoint =
    (
     (x1: 6; y1: 4; x2:  6; y2: 6; x3:  4; y3:  6; x4: 4; y4:  4; Fill: True),
     (x1: 7; y1: 3; x2:  7; y2: 7; x3:  3; y3:  7; x4: 3; y4:  3; Fill: False),
     (x1: 7; y1: 2; x2:  8; y2: 7; x3:  3; y3:  8; x4: 2; y4:  3; Fill: False),
     (x1: 6; y1: 1; x2:  9; y2: 6; x3:  4; y3:  9; x4: 1; y4:  4; Fill: False),
     (x1: 5; y1: 0; x2: 10; y2: 5; x3:  5; y3: 10; x4: 0; y4:  5; Fill: False),
     (x1: 4; y1: 0; x2: 10; y2: 4; x3:  6; y3: 10; x4: 0; y4:  6; Fill: False),
     (x1: 3; y1: 0; x2: 10; y2: 3; x3:  7; y3: 10; x4: 0; y4:  7; Fill: False),
     (x1: 2; y1: 0; x2: 10; y2: 2; x3:  8; y3: 10; x4: 0; y4:  8; Fill: False),
     (x1: 1; y1: 0; x2: 10; y2: 1; x3:  9; y3: 10; x4: 0; y4:  9; Fill: False),
     (x1: 0; y1: 0; x2: 10; y2: 0; x3: 10; y3: 10; x4: 0; y4: 10; Fill: True)
    );
  NumRedrawPts = 75;
  RedrawPts: array[0..NumRedrawPts - 1] of TPoint =
    ((x: 0; y:0), (x: 0; y:1), (x: 0; y:2), (x: 0; y:3), (x: 0; y:4),       // R
     (x: 1; y:0), (x: 1; y:2),
     (x: 2; y:1), (x: 2; y:3), (x: 2; y:4),

     (x: 4; y:0), (x: 4; y:1), (x: 4; y:2), (x: 4; y:3), (x: 4; y:4),       // E
     (x: 5; y:0), (x: 5; y:2), (x: 5; y:4),
     (x: 6; y:0), (x: 6; y:4),

     (x: 8; y:0), (x: 8; y:1), (x: 8; y:2), (x: 8; y:3), (x: 8; y:4),       // D
     (x: 9; y:0), (x: 9; y:4),
     (x: 10; y:1), (x: 10; y:2), (x: 10; y:3),

     (x: 12; y:0), (x: 12; y:1), (x: 12; y:2), (x: 12; y:3), (x: 12; y:4),  // R
     (x: 13; y:0), (x: 13; y:2),
     (x: 14; y:1), (x: 14; y:3), (x: 14; y:4),

     (x: 16; y:1), (x: 16; y:2), (x: 16; y:3), (x: 16; y:4),                // A
     (x: 17; y:0), (x: 17; y:2),
     (x: 18; y:1), (x: 18; y:2), (x: 18; y:3), (x: 18; y:4),

     (x: 20; y:0), (x: 20; y:1), (x: 20; y:2), (x: 20; y:3), (x: 20; y:4),  // W
     (x: 21; y:3),
     (x: 22; y:2),
     (x: 23; y:3),
     (x: 24; y:0), (x: 24; y:1), (x: 24; y:2), (x: 24; y:3), (x: 24; y:4),

     (x: 28; y:0), (x: 28; y:1), (x: 28; y:2), (x: 28; y:3), (x: 28; y:4),  // I

     (x: 30; y:0),                                                          // T
     (x: 31; y:0), (x: 31; y:1), (x: 31; y:2), (x: 31; y:3), (x: 31; y:4),
     (x: 32; y:0));


type
  TEventProcedure = procedure(Win: PWindow);

  TGameStatus = (gsMainMenu, gsLevel, gsGame, gsLeaveGame, gsHelp, gsWin, gsEdit, gsQuit);

  // Base class for all game positions
  TGameClass = class
  protected
    FMouseDown: Boolean;
  public
    procedure PaintWindow(Win: PWindow); virtual;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); virtual;
    procedure FirstEnter(Win: PWindow); virtual;
    procedure MouseMove(Win: PWindow; x, y: Integer); virtual;
    procedure TimeTick(Win: PWindow); virtual;
    procedure KeyUp(Win: PWindow; Qual, Key: LongInt); virtual;
  end;

  // The full GameField with Area and side Numbers
  TField = class
    Area: TArea;       // the playfield area (True = light up)
    AreaSize: TSize;   // Size of Area for faster Access
    XAxis: TAxis;      // Numbers for the X Axis
    MaxX: Integer;     // Maximal Size of XAxis-Numbers
    YAxis: TAxis;      // Numbers of the Y Axis
    MaxY: Integer;     // Maximal Size of YAxis-Numbers
    procedure CalcSides; // Refresh the Side Numbers
    procedure SetSize(AX, AY: Integer); // Set and Clear AreaSize
  end;

  // An abstract Button with animation
  TButton = class
  private
    TimeToMove: LongInt;
    Border: TRect;         // Outer border of the Button
    FText: string;         // Text on the Button
    StartOffset: TPoint;   // Startoffset of the animation when it is running (relative of left top border)
    Offset: TPoint;        // current Offset of the animation when it is running (relative of left top border)
    StartTime: Cardinal;   // Time of Animation start
    FSelected: Boolean;    //
    WithBorder: Boolean;
    FEnabled: Boolean;
    function GetIsMoving: Boolean;
    procedure SetEnabled(AValue: Boolean);
  public
    constructor Create(AText: string; P: TPoint); virtual;
    procedure StartAnimation(Win: PWindow; Dir: TAnimDir); // 0 from right, 1 from left, 2 from bottom border

    procedure DoAnimation(Win: PWindow); // draw next animation step (should be called in a loop as long StartOffset.X <> 0 and StartOffset.Y <> 0)
    procedure DrawButton(Win: PWindow);  // draw the button at current position

    function MouseOver(Win: PWindow; x, y: Integer): Boolean;
    property IsMoving: Boolean read GetIsMoving;
    property Enabled: Boolean read FEnabled write SetEnabled;
  end;

  TNumEdit = class
  private
    Border: TRect;
    PlusSel: Boolean;
    PlusBorder: TRect;
    MinSel: Boolean;
    MinusBorder: TRect;
    FValue: Integer;
    FMinValue: Integer;
    FMaxValue: Integer;
  public
    constructor Create(DefValue: Integer; P: TPoint); virtual;

    procedure DrawNumEdit(Win: PWindow);
    function MouseOver(Win: PWindow; x, y: Integer): Boolean;
    function MouseClick(Win: PWindow; x, y: Integer): Boolean;

    property Value: Integer read FValue write FValue;
    property MinValue: Integer read FMinValue write FMinValue;
    property MaxValue: Integer read FMaxValue write FMaxValue;
  end;


  TGameEditor = class(TGameClass)
  private
    Field: TField;
    GameR: TRect;
  public
    constructor Create; virtual;
    destructor Destroy; override;


  end;

  // Window is in the Game
  TGameField = class(TGameClass)
  private
    Field: TField;    //
    GField: TField;
    GameR: TRect;
    XOK, YOK: array of Boolean;
    Done: Boolean;
    Enable: Boolean;
    StartTime: LongWord;
    LastClickedTile: TPoint;
    procedure CompareFields;
    procedure DrawTime(Win: PWindow);
    procedure CheckDone(Win: PWindow);
    procedure DoEndanimation(Win: PWindow);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure RandomField(SX, SY: Integer);
    procedure LoadLevel(Num: Integer);
    procedure PaintWindow(Win: PWindow); override;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); override;
    procedure MouseMove(Win: PWindow; x, y: Integer); override;
    procedure FirstEnter(Win: PWindow); override;
    procedure TimeTick(Win: PWindow); override;
    procedure KeyUp(Win: PWindow; Qual, Key: LongInt); override;
  end;

  TGameMenu = class(TGameClass)
  private
    Buttons: array[0..2] of TButton;
    Textstatus: array[0..NumRedrawPts - 1] of record
      NextCall: LongWord;
      Fwd: Boolean;
      Pos: Byte;
    end;
    TextOffset: TPoint;
    Ver: string;
    procedure DrawPoint(Win: PWindow; xs, ys, p: LongInt);
    procedure IdleDraw(Win: PWindow; OnlyDraw: Boolean = False);
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure PaintWindow(Win: PWindow); override;
    procedure FirstEnter(Win: PWindow); override;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); override;
    procedure MouseMove(Win: PWindow; x, y: Integer); override;
    procedure TimeTick(Win: PWindow); override;
  end;

  TGameMessage = class(TGameClass)
  private
    FButton: TButton;
  public
    FText: TStringList;
    FBtnText: string;
    OnClick: TEventProcedure;
    WImage: Boolean;
    //
    constructor Create; virtual;
    destructor Destroy; override;
    procedure PaintWindow(Win: PWindow); override;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); override;
    procedure MouseMove(Win: PWindow; x, y: Integer); override;
    procedure FirstEnter(Win: PWindow); override;
  end;

  TGameQuestion = class(TGameClass)
  private
    FYesButton: TButton;
    FNoButton: TButton;
  public
    FText: TStringList;
    FBtnText: string;
    OnYesClick: TEventProcedure;
    OnNoClick: TEventProcedure;
    WImage: Boolean;
    //
    constructor Create; virtual;
    destructor Destroy; override;
    procedure PaintWindow(Win: PWindow); override;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); override;
    procedure MouseMove(Win: PWindow; x, y: Integer); override;
    procedure FirstEnter(Win: PWindow); override;
  end;

  TFileButton = class
    FileName: string;
    Button: TButton;
  end;
  TFileButtons = specialize TFPGObjectList<TFileButton>;

  TGameLevel = class(TGameClass)
  private
    TutorialButton: TButton;
    FileButtons: TFileButtons;
    LevelButtons: TFileButtons;
    UserButton: TButton;
    BackButton: TButton;
    RandomButton: TButton;
    RandomX, RandomY: TNumEdit;
    procedure LevelToButtons;
  public
    constructor Create; virtual;
    destructor Destroy; override;
    procedure PaintWindow(Win: PWindow); override;
    procedure MouseClick(Win: PWindow; x, y: Integer; Down: Boolean); override;
    procedure MouseMove(Win: PWindow; x, y: Integer); override;
    procedure FirstEnter(Win: PWindow); override;
  end;

var
  GameStatus: TGameStatus = gsMainMenu;
  Game: array[TGameStatus] of TGameClass;
  FileList: TLevelFiles;
  PrgEnd: Boolean = False;


  Levels: TLevels;
  CurLevelType: TLevelType = ltRandom;
  CurLevelNum: Integer = 0;

procedure LoadTutorial;
begin
  CurLevelType := ltTutorial;
  CurLevelNum := 0;
  SetLength(Levels, 3);
  with Levels[0] do
  begin
    Name := 'Basics';
    Magic := 1;
    NumX := 4;
    NumY := 1;
    Enabled := True;
    SetLength(Field, NumX, NumY);
    Field[0,0] := True;
    Field[1,0] := True;
    Field[2,0] := True;
    Field[3,0] := False;
  end;
  with Levels[1] do
  begin
    Name := 'Spaces';
    Magic := 2;
    NumX := 4;
    NumY := 1;
    Enabled := False;
    SetLength(Field, NumX, NumY);
    Field[0,0] := True;
    Field[1,0] := True;
    Field[2,0] := False;
    Field[3,0] := True;
  end;

  with Levels[2] do
  begin
    Name := '2D';
    Magic := 3;
    NumX := 4;
    NumY := 4;
    Enabled := False;
    SetLength(Field, NumX, NumY);
    Field[0,0] := True;
    Field[1,0] := True;
    Field[2,0] := False;
    Field[3,0] := True;
    Field[0,1] := True;
    Field[1,1] := False;
    Field[2,1] := False;
    Field[3,1] := True;
    Field[0,2] := True;
    Field[1,2] := False;
    Field[2,2] := True;
    Field[3,2] := False;
    Field[0,3] := True;
    Field[1,3] := False;
    Field[2,3] := True;
    Field[3,3] := True;
  end;

end;


//######################################################################
//                Basis Gameclass

procedure TGameClass.PaintWindow(Win: PWindow);
begin
end;

procedure TGameClass.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
begin
  FMouseDown := Down;
end;

procedure TGameClass.FirstEnter(Win: PWindow);
begin
end;

procedure TGameClass.MouseMove(Win: PWindow; x, y: Integer);
begin
end;

procedure TGameClass.TimeTick(Win: PWindow);
begin
end;

procedure TGameClass.KeyUp(Win: PWindow; Qual, Key: LongInt);
begin
end;


//######################################################################
//                Button Class
constructor TButton.Create(AText: string; P: TPoint);
begin
  inherited Create;
  FText := AText;
  Border := Rect(P.X, P.Y, P.X + 100, P.Y + 20);
  StartOffset.X := 0;
  StartOffSet.Y := 0;
  TimeToMove := 1000;
  WithBorder := True;
  FEnabled := True;
end;

procedure TButton.StartAnimation(Win: PWindow; Dir: TAnimDir);
begin
  FSelected := False;
  case Dir of
    adRight: begin
      StartOffset.X := (Win^.GZZWidth - Border.Left);
      StartOffset.Y := 0;
    end;
    adLeft: begin
      StartOffset.X := -(Border.Left + Border.Width);
      StartOffset.Y := 0;
    end;
    adBottom: begin
      StartOffset.X := 0;
      StartOffset.Y := (Win^.GZZHeight - Border.Top);
    end;
  end;
  StartTime := GetTickCount;
end;

procedure TButton.DoAnimation(Win: PWindow);
var
  t1: LongWord;
  Cur: TRect;
begin
  if (StartOffset.X = 0) and (StartOffset.Y = 0) then
    Exit;
  t1 := GetTickCount - StartTime;
  SetAPen(Win^.RPort, 2);
  Cur := Border;
  Cur.Offset(Offset);
  RectFill(Win^.RPort, Cur.Left, Cur.Top, Cur.Right, Cur.Bottom);
  //
  if t1 > TimeToMove then
  begin
    Offset := Point(0,0);
    StartOffset := Point(0,0);
  end
  else
  begin
    Offset.X := Round(StartOffset.X - ((t1 / TimeToMove) * StartOffset.X));
    Offset.Y := Round(StartOffset.Y - ((t1 / TimeToMove) * StartOffset.Y));
  end;
  DrawButton(Win);
end;

function TButton.GetIsMoving: Boolean;
begin
  Result := (StartOffset.X <> 0) or (StartOffset.Y <> 0);
end;

procedure TButton.DrawButton(Win: PWindow);
var
  Cur: TRect;
  w: Integer;
  Bitmap: PBitmap;
  ARP: TRastPort;
  RP: PRastPort;
begin
  RP := @ARP;
  Bitmap := AllocBitMap(Border.Width + 1, Border.Height + 1, Win^.RPort^.Bitmap^.Depth, 0, Win^.RPort^.Bitmap);
  InitRastPort(RP);
  RP^.Bitmap := Bitmap;
  RP^.Layer := nil;
  RP^.Font := Win^.RPort^.Font;

  SetRast(RP, 2);

  Cur := Border;
  Cur.SetLocation(0, 0);
  SetAPen(RP, 1);
  GfxMove(RP, Cur.Left, Cur.Top);
  Draw(RP, Cur.Right, Cur.Top);
  Draw(RP, Cur.Right, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Top);

  if WithBorder then
  begin
    Cur.Inflate(-2, -2);
    GfxMove(RP, Cur.Left, Cur.Top);
    Draw(RP, Cur.Right, Cur.Top);
    Draw(RP, Cur.Right, Cur.Bottom);
    Draw(RP, Cur.Left, Cur.Bottom);
    Draw(RP, Cur.Left, Cur.Top);
  end;


  Cur.Inflate(-1, -1);
  if FSelected then
    SetAPen(RP, 3)
  else
    SetAPen(RP, 2);
  RectFill(RP, Cur.Left, Cur.Top, Cur.Right, Cur.Bottom);


  SetDrMd(RP, JAM1);
  if Enabled then
    SetAPen(RP, 1)
  else
    SetAPen(RP, 0);
  w := Cur.Width div 2 - TextLength(RP, PChar(FText), Length(FText)) div 2;
  GfxMove(RP, Cur.Left + w, Cur.Top + Cur.Height div 2 + 3);
  GFXText(RP, PChar(FText), Length(FText));

  Cur := Border;
  Cur.Offset(Offset);
  ClipBlit(RP, 0,0, Win^.RPort, Cur.Left, Cur.Top, Cur.Width + 1, Cur.Height + 1, $00C0);

  FreeBitmap(Bitmap);
end;

function TButton.MouseOver(Win: PWindow; x, y: Integer): Boolean;
begin
  Result := False;
  if not Enabled then
    Exit;
  Result := PtInRect(Border, Point(X, Y));
  if Result <> FSelected then
  begin
    FSelected := Result;
    DrawButton(Win);
  end;
end;

procedure TButton.SetEnabled(AValue: Boolean);
begin
  if AValue = FEnabled then
    Exit;
  FEnabled := AValue;
end;

//######################################################################
//                NumEdit class
constructor TNumEdit.Create(DefValue: Integer; P: TPoint);
begin
  inherited Create;
  FValue := DefValue;
  Border := Rect(P.X, P.Y, 100, 30);
  MinSel := False;
  PlusSel := False;
  MinValue := -MaxInt;
  MaxValue := MaxInt;
end;

procedure TNumEdit.DrawNumEdit(Win: PWindow);
var
  Cur: TRect;
  w: Integer;
  Bitmap: PBitmap;
  ARP: TRastPort;
  RP: PRastPort;
  TextSize: TTextExtent;
  Val: string;
begin
  // Draw the actual Num Edit
  RP := @ARP;
  Bitmap := AllocBitMap(Border.Width + 1, Border.Height + 1, Win^.RPort^.Bitmap^.Depth, 0, Win^.RPort^.Bitmap);
  InitRastPort(RP);
  RP^.Bitmap := Bitmap;
  RP^.Layer := nil;
  RP^.Font := Win^.RPort^.Font;

  SetRast(RP, 2);

  Cur := Border;
  Cur.SetLocation(0, 0);
  SetAPen(RP, 1);
  GfxMove(RP, Cur.Left, Cur.Top);
  Draw(RP, Cur.Right, Cur.Top);
  Draw(RP, Cur.Right, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Top);

  MinusBorder := Border;
  MinusBorder.Width := 20;

  PlusBorder := MinusBorder;
  PlusBorder.SetLocation(Border.Right - 20, Border.Top);

  // Draw - Button
  Cur := MinusBorder;
  Cur.SetLocation(0,0);
  Cur.Inflate(-2, -2);
  SetAPen(RP, 1);
  GfxMove(RP, Cur.Left, Cur.Top);
  Draw(RP, Cur.Right, Cur.Top);
  Draw(RP, Cur.Right, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Top);


  if FValue = FMinValue then
  begin
    SetAPen(RP, 0);
  end
  else
  begin
    if MinSel then
    begin
      SetAPen(RP, 3);
      Cur.Inflate(-1, -1);
      RectFill(RP, Cur. Left, Cur.Top, Cur.Right, Cur.Bottom);
    end;
    SetAPen(RP, 1);
  end;
  // the sign

  GFXMove(RP, Cur.Left + 2, Cur.Top + Cur.Height div 2);
  Draw(RP, Cur.Right - 2, Cur.Top + Cur.Height div 2);

  // Draw + Button
  Cur := PlusBorder;
  Cur.SetLocation(PlusBorder.Left - Border.Left,0);
  Cur.Inflate(-2, -2);
  SetAPen(RP, 1);
  GfxMove(RP, Cur.Left, Cur.Top);
  Draw(RP, Cur.Right, Cur.Top);
  Draw(RP, Cur.Right, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Bottom);
  Draw(RP, Cur.Left, Cur.Top);

  if FValue = FMaxValue then
  begin
    SetAPen(RP, 0);
  end
  else
  begin
    if PlusSel then
    begin
      SetAPen(RP, 3);
      Cur.Inflate(-1, -1);
      RectFill(RP, Cur. Left, Cur.Top, Cur.Right, Cur.Bottom);
    end;
    SetAPen(RP, 1);
  end;
  // the sign
  GFXMove(RP, Cur.Left + 2, Cur.Top + Cur.Height div 2);
  Draw(RP, Cur.Right - 2, Cur.Top + Cur.Height div 2);
  GFXMove(RP, Cur.Left + Cur.Width div 2, Cur.Top + 2);
  Draw(RP, Cur.Left + Cur.Width div 2, Cur.Bottom - 2);


  // Draw the Actual Value
  Val := IntToStr(FValue);
  SetAPen(RP, 1);
  SetDrMd(RP, JAM1);
  TextExtent(RP, PChar(Val), Length(Val), @TextSize);
  Cur := Border;
  Cur.SetLocation(0,0);
  GFXMove(RP, Cur.Width div 2 - TextSize.te_Width div 2, Cur.Height div 2 + 3);
  GFXText(RP, PChar(Val), Length(Val));

  Cur := Border;
  ClipBlit(RP, 0,0, Win^.RPort, Cur.Left, Cur.Top, Cur.Width + 1, Cur.Height + 1, $00C0);

  FreeBitmap(Bitmap);
end;

function TNumEdit.MouseOver(Win: PWindow; x, y: Integer): Boolean;
begin
  Result := False;
  //if not Enabled then
  //  Exit;
  Result := PtInRect(MinusBorder, Point(X, Y));
  if Result <> MinSel then
  begin
    MinSel := Result;
    DrawNumEdit(Win);
  end;
  Result := PtInRect(PlusBorder, Point(X, Y));
  if Result <> PlusSel then
  begin
    PlusSel := Result;
    DrawNumEdit(Win);
  end;

end;


function TNumEdit.MouseClick(Win: PWindow; x, y: Integer): Boolean;
begin
  MinSel := PtInRect(MinusBorder, Point(X, Y));
  if MinSel then
  begin
    FValue := EnsureRange(FValue - 1, FMinValue, FMaxValue);
    DrawNumEdit(Win);
  end;
  PlusSel := PtInRect(PlusBorder, Point(X, Y));
  if PlusSel then
  begin
    FValue := EnsureRange(FValue + 1, FMinValue, FMaxValue);
    DrawNumEdit(Win);
  end;
end;


//######################################################################
//                Field class
procedure TField.SetSize(AX, AY: Integer);
var
  x, y: Integer;
begin
  AreaSize.CX := AX;
  AreaSize.CY := AY;
  SetLength(Area, AX, AY);
  for y := 0 to AreaSize.CY - 1 do
    for x := 0 to AreaSize.CX - 1 do
      Area[x, y] := False;
  CalcSides;
end;

// Calc side numbers
procedure TField.CalcSides;
var
  x, y, Idx: Integer;
begin
  SetLength(XAxis, AreaSize.CX, AreaSize.CY);
  SetLength(YAxis, AreaSize.CY, AreaSize.CX);
  MaxX := 1;
  MaxY := 1;
  // XAxis
  for x := 0 to AreaSize.CX - 1 do
  begin
    Idx := 0;
    XAxis[x, Idx] := 0;
    for y := 0 to AreaSize.CY - 1 do
    begin
      if Area[x,y] then
        Inc(XAxis[x,Idx])
      else
      begin
        if XAxis[x,Idx] > 0 then
        begin
          Inc(Idx);
          XAxis[x, Idx] := 0;
        end;
      end;
    end;
    if (XAxis[x, Idx] > 0) or (Idx = 0) then
      Inc(Idx);
    SetLength(XAxis[x], Idx); // Final length
    if Idx > MaxX then
      MaxX := Idx;
  end;
  // YAxis
  for y := 0 to AreaSize.CY - 1 do
  begin
    Idx := 0;
    YAxis[y, Idx] := 0;
    for x := 0 to AreaSize.CX - 1 do
    begin
      if Area[x,y] then
        Inc(YAxis[y,Idx])
      else
      begin
        if YAxis[y,Idx] > 0 then
        begin
          Inc(Idx);
          YAxis[y, Idx] := 0;
        end;
      end;
    end;
    if (YAxis[y, Idx] > 0) or (Idx = 0) then
      Inc(Idx);
    SetLength(YAxis[y], Idx); // Final Length
    if Idx > MaxY then
      MaxY := Idx;
  end;
end;

//######################################################################
//                GameEditor class
constructor TGameEditor.Create;
begin
  inherited Create;
  Field := TField.Create;
  Field.AreaSize.CX := 0;
  Field.AreaSize.CY := 0;
end;

destructor TGameEditor.Destroy;
begin
  Field.Free;
  inherited;
end;


//######################################################################
//                  GameField Object
constructor TGameField.Create;
begin
  inherited;
  Field := TField.Create;
  GField := TField.Create;
  Field.AreaSize.CX := 0;
  Field.AreaSize.CY := 0;
end;

destructor TGameField.Destroy;
begin
  Field.Free;
  GField.Free;
  inherited;
end;

//          create a "Random" Field
procedure TGameField.RandomField(SX, SY: Integer);
var
  x,y: Integer;
  Perc: Integer;
begin
  Randomize;
  Perc := Random(70) + 21;
  Field.SetSize(SX, SY);
  GField.SetSize(SX, SY);
  //
  SetLength(XOk, Field.AreaSize.CX);
  SetLength(YOk, Field.AreaSize.CY);
  for y := 0 to Field.AreaSize.CY - 1 do
    for x := 0 to Field.AreaSize.CX - 1 do
      Field.Area[x, y] := Random(101) <= Perc;
  //
  Field.CalcSides;
  GField.CalcSides;
  CompareFields;
end;

procedure TGameField.LoadLevel(Num: Integer);
var
  x, y: Integer;
begin
  CurLevelNum := Num;
  Field.SetSize(Levels[Num].NumX, Levels[Num].NumY);
  GField.SetSize(Levels[Num].NumX, Levels[Num].NumY);
  //
  SetLength(XOk, Field.AreaSize.CX);
  SetLength(YOk, Field.AreaSize.CY);

  for y := 0 to Field.AreaSize.CY - 1 do
    for x := 0 to Field.AreaSize.CX - 1 do
      Field.Area[x, y] := Levels[Num].Field[x,y];
  //
  Field.CalcSides;
  GField.CalcSides;
  CompareFields;
end;

procedure TGameField.FirstEnter(Win: PWindow);
begin
  FMouseDown := False;
  StartTime := GetTickCount;
  PaintWindow(Win);
end;

//   Compare solved Field and User Field (only Side results)
procedure TGameField.CompareFields;
var
  x,y: Integer;
begin
  Done := False;
  for x := 0 to High(XOK) do
    XOK[x] := False;
  for y := 0 to High(YOK) do
    YOK[y] := False;
  //
  if (Length(XOK) <> GField.AreaSize.CX) or (Length(YOK) <> GField.AreaSize.CY) or (Length(XOK) <> Field.AreaSize.CX) or (Length(YOK) <> Field.AreaSize.CY) then
    Exit;

  Done := True;
  for x := 0 to GField.AreaSize.CX - 1 do
  begin
    XOK[x] := True;
    if Length(Field.XAxis[x]) = Length(GField.XAxis[x]) then
    begin
      for y := 0 to High(GField.XAxis[x]) do
      begin
        if GField.XAxis[x,y] <> Field.XAxis[x,y] then
        begin
          //writeln(x,',',y, '  ', GField.XAxis[x,y], ' <> ', GField.XAxis[x,y]);
          XOK[x] := False;
          Done := False;
          Break;
        end;
      end;
    end
    else
    begin
      XOK[x] := False;
      Done := False;
    end;
  end;

  for x := 0 to GField.AreaSize.CY - 1 do
  begin
    YOK[x] := True;
    if Length(Field.YAxis[x]) = Length(GField.YAxis[x]) then
    begin
      for y := 0 to High(GField.YAxis[x]) do
      begin
        if GField.YAxis[x,y] <> Field.YAxis[x,y] then
        begin
          YOK[x] := False;
          Done := False;
          Break;
        end;
      end;
    end
    else
    begin
      YOK[x] := False;
      Done := False;
    end;
  end;

end;

//          Paint Game Field (GameField)
procedure TGameField.PaintWindow(Win: PWindow);
var
  x, y: Integer;
  str: string;
  FontSize: TTextExtent;
  FSize: Integer;
  CH, CW: Integer;
  SF: TRect;
begin
  SetRast(Win^.RPort, 2);
  TextExtent(Win^.RPort, 'W', 1, @FontSize);
  FSize := FontSize.te_Height + 5;

  GameR.Top := (Max(3, Field.MaxX) * FSize) + 5;
  GameR.Left := (Max(3, Field.MaxY) * FSize) + 5;
  GameR.Width := Max(Field.AreaSize.CX * FSize, ((Win^.GZZWidth - 100) - GameR.Left) - 5);
  GameR.Height := Max(Field.AreaSize.CY * FSize, (Win^.GZZHeight - GameR.Top) - 5);
  CH := Min(GameR.Height div Field.AreaSize.CY, GameR.Width div Field.AreaSize.CX);
  CW := CH;
  GameR.Height := CH * Field.AreaSize.CY;
  GameR.Width := CW * Field.AreaSize.CX;

  DrawTime(Win);

  //Win^.MinWidth := 10 + GameR.Width;
  //Win^.MinHeight := 10 + GameR.Height;

  SetAPen(Win^.RPort , 3);
  for y := 0 to Field.AreaSize.CY - 1 do
  begin
    for x := 0 to Field.AreaSize.CX - 1 do
    begin
      if GField.Area[x,y] then
      begin
        SF := Rect(GameR.Left + x * CW, GameR.Top + y * CH, GameR.Left + (x + 1) * CW, GameR.Top + (y + 1) * CH);
        SF.Inflate(-1,-1);
        //
        SetAPen(Win^.RPort, 2);
        GfxMove(Win^.RPort, SF.Left, SF.Top);
        Draw(Win^.RPort, SF.Right, SF.Top);
        Draw(Win^.RPort, SF.Right, SF.Bottom);
        SetAPen(Win^.RPort, 1);
        Draw(Win^.RPort, SF.Left, SF.Bottom);
        Draw(Win^.RPort, SF.Left, SF.Top);
        //
        SF.Inflate(-1,-1);
        SetAPen(Win^.RPort , 3);
        RectFill(Win^.RPort,SF.Left, SF.Top, SF. Right, SF.Bottom);
      end;
    end;
  end;

  SetAPen(Win^.RPort , 1);
  for y := 0 to Field.AreaSize.CY do
  begin
    if (y <= High(YOK)) and YOK[y] then
    begin
      SetAPen(Win^.RPort , 0);
      RectFill(Win^.RPort, 5, GameR.Top + y * CH, GameR.Left, GameR.Top + (y + 1) * CH);
    end;
    SetAPen(Win^.RPort , 1);
    GFXMove(Win^.RPort, 5, GameR.Top + y * CH);
    Draw(Win^.RPort, GameR.Right, GameR.Top + y * CH);
  end;

  for x := 0 to Field.AreaSize.CX do
  begin
    if (x <= High(XOK)) and XOK[x] then
    begin
      SetAPen(Win^.RPort , 0);
      RectFill(Win^.RPort, GameR.Left + x * CW, 5, GameR.Left + (x + 1) * CW, GameR.Top);
    end;

    SetAPen(Win^.RPort , 1);
    GFXMove(Win^.RPort, GameR.Left + x * CW, 5);
    Draw(Win^.RPort, GameR.Left + x * CW, GameR.Bottom);
  end;

  SetAPen(Win^.RPort , 1);
  SetDrMd(Win^.RPort, Jam1);
  for x := 0 to Field.AreaSize.CX - 1 do
  begin
    for y := 0 to High(Field.XAxis[x]) do
    begin
      //
      str := IntToStr(Field.XAxis[x,y]);
      if Field.XAxis[x,y] < 10 then
        str := ' ' + str;
      GFXMove(Win^.RPort, GameR.Left + (x * CW) + 5, (GameR.Top - High(Field.XAxis[x]) * FSize - FSize div 2) + (y * FSize));
      GFXText(Win^.RPort, PChar(str), Length(str));
    end;
  end;

  SetBPen(Win^.RPort , 1);
  SetDrMd(Win^.RPort, Jam1);
  for y := 0 to Field.AreaSize.CY - 1 do
  begin
    for x := 0 to High(Field.YAxis[y]) do
    begin
      //
      str := IntToStr(Field.YAxis[y,x]);
      if Field.YAxis[y,x] < 10 then
        str := ' ' + str;
      GFXMove(Win^.RPort, (GameR.Left - High(Field.YAxis[y]) * FSize - FSize) + (x * FSize), GameR.Top + (y * CH) + 5 + FSize div 2);
      GFXText(Win^.RPort, PChar(str), Length(str));
    end;
  end;
end;

procedure TGameField.DrawTime(Win: PWindow);
var
  CurTime, h, s: LongWord;
  t: string;
  TextSize: TTextExtent;
begin
  CurTime := (GetTickCount - StartTime) div 1000;
  h := CurTime div 60;
  s := CurTime mod 60;
  t := '';
  if h < 10 then
    t := '0';
  t := t + IntToStr(h) + ':';
  if s < 10 then
    t := t + '0';
  t := t + IntToStr(s);
  //
  TextExtent(Win^.RPort, PChar(t), Length(t), @TextSize);
  h := GameR.Left - TextSize.te_Width - 1;
  s := GameR.Top - TextSize.te_Height div 2;
  SetAPen(Win^.RPort, 1);
  SetBPen(Win^.RPort, 2);
  SetDrMd(Win^.RPort, JAM2);
  GfxMove(Win^.RPort, h, s);
  GfxText(Win^.RPort, PChar(t), Length(t));
end;

procedure TGameField.TimeTick(Win: PWindow);
begin
  DrawTime(Win);
end;


//          Mouse move (GameField)
procedure TGameField.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
var
  CH: Integer;
  CurTime, h, s: LongWord;
  t: string;
begin
  inherited;
  if not Down then
    Exit;
  CH := GameR.Height div Field.AreaSize.CY;
  if PtInRect(GameR, Point(X,Y)) then
  begin
    X := (X - GameR.Left) div CH;
    Y := (Y - GameR.Top) div CH;
    if (X >= 0) and (Y >= 0) and (X < Field.AreaSize.CX) and (Y < Field.AreaSize.CY) then
    begin
      LastClickedTile := Point(x,y);
      GField.Area[x,y] := not GField.Area[x,y];
      Enable := GField.Area[x,y];
      GField.CalcSides;
      CompareFields;
      PaintWindow(Win);
    end;
    CheckDone(Win);
  end;
end;


//          Mouse Click (GameField)
procedure TGameField.MouseMove(Win: PWindow; x, y: Integer);
var
  CH: Integer;
begin
  inherited;
  //
  if not FMouseDown then
    Exit;
  CH := GameR.Height div Field.AreaSize.CY;
  if PtInRect(GameR, Point(X,Y)) then
  begin
    X := (X - GameR.Left) div CH;
    Y := (Y - GameR.Top) div CH;
    if (X >= 0) and (Y >= 0) and (X < Field.AreaSize.CX) and (Y < Field.AreaSize.CY) then
    begin
      if GField.Area[x,y] <> Enable then
      begin
        LastClickedTile := Point(x,y);
        GField.Area[x,y] := Enable;
        GField.CalcSides;
        CompareFields;
        PaintWindow(Win);
      end;
    end;
    CheckDone(Win);
  end;
end;

procedure TGameField.KeyUp(Win: PWindow; Qual, Key: LongInt);
begin
  if Key = $45 then
  begin
    GameStatus := gsLeaveGame;
    Game[GameStatus].FirstEnter(Win);
  end;
end;

procedure TGameField.DoEndanimation(Win: PWindow);
var
  s, e: TRect;
  CH, i, n: Integer;
  p: Single;
  st: array[0..3] of TPoint;
begin
  CH := GameR.Height div Field.AreaSize.CY;
  s := Rect(GameR.Left + LastClickedTile.X * CH, GameR.Top + LastClickedTile.Y * CH, GameR.Left + (LastClickedTile.X + 1) * CH, GameR.Top + (LastClickedTile.Y + 1) * CH);// Start rect
  e := Rect(0, 0, Win^.GZZWidth, Win^.GZZHeight);
  SetAPen(Win^.RPort, 1);
  for i := 1 to 100 do
  begin
    p := i / 100;
    st[0].X := Round(s.Left - (s.Left * p));
    st[0].Y := Round(s.Top + (e.Bottom - s.Top) * p);

    st[1].X := Round(s.Right - (s.Right * p));
    st[1].Y := Round(s.Top + (e.Top - s.Top) * p);

    st[2].X := Round(s.Right + (e.Right - s.Right) * p);
    st[2].Y := Round(s.Bottom + (e.Top - s.Bottom) * p);

    st[3].X := Round(s.Right + (e.Right - s.Right) * p);
    st[3].Y := Round(s.Bottom + (e.Bottom - s.Bottom) * p);

    GFXMove(Win^.RPort, St[3].X, St[3].Y);
    for n := 0 to 3 do
    begin
      Draw(Win^.RPort, St[n].X, St[n].Y);
    end;
    Sleep(10);
  end;
end;


procedure TGameField.CheckDone(Win: PWindow);
var
  CurTime, h, s: LongWord;
  t: string;
begin
  if Done then
  begin
    // Endanimation
    DoEndAnimation(Win);
    //
    GameStatus := gsWin;
    CurTime := (GetTickCount - StartTime) div 1000;
    h := CurTime div 60;
    s := CurTime mod 60;
    t := '';
    if h < 10 then
      t := '0';
    t := t + IntToStr(h) + ':';
    if s < 10 then
      t := t + '0';
    t := t + IntToStr(s);
    if CurLevelNum >= High(Levels) then
    begin
      with TGameMessage(Game[gsWin]) do
      begin
        FText.Clear;
        FText.Add('Congratulation');
        FText.Add('You finished this level in ' + t);
        FText.Add('');
        FText.Add('Press "OK" to go back to level selector');
        WImage := True;
      end;
    end
    else
    begin
      with TGameMessage(Game[gsWin]) do
      begin
        FText.Clear;
        FText.Add('Congratulation');
        FText.Add('You finished this level in ' + t);
        FText.Add('');
        FText.Add('Press "OK" for next level');
        FText.Add('"' + Levels[CurLevelNum + 1].Name + '"');

        Levels[CurLevelNum + 1].Enabled := True;
        WImage := True;
      end;
    end;
    FMouseDown := False;
    Game[GameStatus].FirstEnter(Win);
  end;
end;


//######################################################################
//               Game Menu
constructor TGameMenu.Create;
var
  i: Integer;
begin
  inherited;
  Ver := Copy(VERSION, Pos('RedrawIt', VERSION) + 9, Length(VERSION));

  for i := 0 to NumRedrawPts - 1 do
  begin
    Textstatus[i].Fwd := True;
    Textstatus[i].Pos := 9;
  end;
  Buttons[0] := TButton.Create('New Game', Point(-300, -200));
  Buttons[1] := TButton.Create('About', Point(-300, -200));
  Buttons[2] := TButton.Create('Quit', Point(-300, -200));
end;

destructor TGameMenu.Destroy;
var
  i: Integer;
begin
  for i := 0 to High(Buttons) do
    Buttons[i].Free;
  inherited;
end;

// Paint Window
procedure TGameMenu.PaintWindow(Win: PWindow);
var
  s, w, i: Integer;
  t: string;
  TextSize: TTextExtent;
begin
  // Clear window
  SetRast(Win^.RPort, 2);
  // Draw the Buttons
  s := Win^.GZZHeight;
  for i := High(Buttons) downto 0 do
  begin
    w := Win^.GZZWidth div 2 - Buttons[i].Border.Width div 2;
    s := s - (Buttons[i].Border.Height + 10);
    Buttons[i].Border.SetLocation(w, s);
    Buttons[i].DrawButton(Win);
  end;
  // Offset for the Title Text
  TextOffset.X := Win^.GZZWidth div 2 - 180;
  TextOffset.Y := Win^.GZZHeight div 4 - 55;
  IdleDraw(Win, True);
  // little small texts
  t := 'by ALB42';
  TextExtent(Win^.RPort, PChar(t), Length(t), @TextSize);
  w := Win^.GZZWidth - (TextSize.te_Width + 5);
  s := Win^.GZZHeight - (TextSize.te_Height);
  SetDrMd(Win^.RPort, JAM1);
  SetAPen(Win^.RPort, 1);
  GfxMove(Win^.RPort, w, s);
  GfxText(Win^.RPort, PChar(t), Length(t));
  // Version
  GfxMove(Win^.RPort, 5, s);
  GfxText(Win^.RPort, PChar(Ver), Length(Ver));
end;

// First Enter
procedure TGameMenu.FirstEnter(Win: PWindow);
var
  i: Integer;
  Moving: Boolean;
begin
  Randomize;
  // Reset Title Text status
  for i := 0 to High(Textstatus) do
  begin
    Textstatus[i].Fwd := False;
    Textstatus[i].Pos := i mod Length(PtAnim);
  end;
  PaintWindow(Win);
  // restart the Button fly in
  for i := 0 to High(Buttons) do
    Buttons[i].StartAnimation(Win,TAnimDir(i mod 3));
  // Draw the whole contents (Title Text, Buttons, side texts)
  PaintWindow(Win);
  // Draw the Button fly in anymation
  repeat
    for i := 0 to High(Buttons) do
      Buttons[i].DoAnimation(Win);
    IdleDraw(Win, False);
    Sleep(1);
    Moving := False;
    for i := 0 to High(Buttons) do
      Moving := Moving or Buttons[i].IsMoving;
  until not Moving;
end;

procedure TGameMenu.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
var
  i: Integer;
begin
  inherited;
  if not Down then
    Exit;
  for i := 0 to High(Buttons) do
  begin
    if PtInRect(Buttons[i].Border, Point(X, Y)) then
    begin
      case i of
        0: GameStatus := gsLevel;
        //GameStatus := gsGame;
        1: GameStatus := gsHelp;
        2: begin PrgEnd := True; Exit; end;
      end;
      Game[GameStatus].FirstEnter(Win);
      Game[GameStatus].PaintWindow(Win);
    end;
  end;
end;

procedure TGameMenu.MouseMove(Win: PWindow; x, y: Integer);
var
  i: Integer;
begin
  for i := 0 to High(Buttons) do
    Buttons[i].MouseOver(Win, x, y);
end;

procedure TGameMenu.DrawPoint(Win: PWindow; xs, ys, p: LongInt);
begin
  if (p<0) or (p>High(PtAnim)) then
    Exit;

  SetAPen(Win^.RPort, 0);
  RectFill(Win^.RPort, xs, ys, xs + 10, ys + 10);
  SetAPen(Win^.RPort, 2);
  GfxMove(Win^.RPort, xs + PtAnim[p].x1, ys + PtAnim[p].y1);
  Draw(Win^.RPort, xs + PtAnim[p].x2, ys + PtAnim[p].y2);
  Draw(Win^.RPort, xs + PtAnim[p].x3, ys + PtAnim[p].y3);
  SetAPen(Win^.RPort, 1);
  Draw(Win^.RPort, xs + PtAnim[p].x4, ys + PtAnim[p].y4);
  Draw(Win^.RPort, xs + PtAnim[p].x1, ys + PtAnim[p].y1);
  if PtAnim[p].Fill then
  begin
    SetAPen(Win^.RPort, 3);
    if p = 0 then
      WritePixel(Win^.RPort, xs + 5, ys + 5)
    else
      RectFill(Win^.RPort, xs + PtAnim[p].x1 + 1, ys + PtAnim[p].y1 + 1, xs + PtAnim[p].x3 - 1, ys + PtAnim[p].y3 - 1);
  end;
end;

procedure TGameMenu.IdleDraw(Win: PWindow; OnlyDraw: Boolean = False);
var
  CurTime: LongWord;
  i,x,y: Integer;
  DoNext: Boolean;
begin
  CurTime := GetTickCount;
  for i := 0 to High(RedrawPts) do
  begin
    DoNext := CurTime >= TextStatus[i].NextCall;
    if (not DoNext) and (not OnlyDraw) then
      Continue;

    TextStatus[i].Nextcall := CurTime + 99;
    if TextStatus[i].Fwd then
    begin
      if TextStatus[i].Pos = High(PtAnim) then
      begin
        TextStatus[i].Fwd := False;
        TextStatus[i].NextCall := CurTime + Random(1000) + 3000;
      end
      else
        Inc(TextStatus[i].Pos);
    end
    else
    begin
      if TextStatus[i].Pos = Low(PtAnim) then
      begin
        TextStatus[i].Fwd := True;
        TextStatus[i].NextCall := CurTime + Random(1000);
      end
      else
        Dec(TextStatus[i].Pos);
    end;

    x := RedrawPts[i].x * 11 + TextOffset.X;
    y := RedrawPts[i].y * 11 + TextOffset.Y;
    DrawPoint(Win, x, y, TextStatus[i].Pos);
  end;
end;

procedure TGameMenu.TimeTick(Win: PWindow);
begin
  IdleDraw(Win, False);
end;

//######################################################################
//               Game Message
constructor TGameMessage.Create;
begin
  inherited;
  FText := TStringList.Create;
  FButton := TButton.Create('OK', Point(-300, -200));
  WImage := False;
end;

destructor TGameMessage.Destroy;
begin
  FText.Free;
  FButton.Free;
  inherited;
end;

procedure TGameMessage.PaintWindow(Win: PWindow);
var
  FontSize: TTextExtent;
  s, w, fh, H, i, x, y: Integer;
  line: string;
  GF: TGameField;
begin
  SetDrMd(Win^.RPort, JAM1);
  SetAPen(Win^.RPort, 1);
  SetRast(Win^.RPort, 2);
  TextExtent(Win^.RPort, 'W', 1, @FontSize);
  h := FontSize.te_Height + 5;
  fh := h * FText.Count + 2;
  s := Win^.GZZHeight div 2 - fh div 2;
  for i := 0 to FText.Count - 1 do
  begin
    line := FText[i];
    w := Win^.GZZWidth div 2 - TextLength(Win^.RPort, PChar(Line), Length(Line)) div 2;
    GfxMove(Win^.RPort, w, s + i * h);
    GFXText(Win^.RPort, PChar(line), Length(line));
  end;
  w := Win^.GZZWidth div 2 - FButton.Border.Width div 2;
  s := Win^.GZZHeight - (FButton.Border.Height + 10);
  FButton.Border.SetLocation(w, s);
  FButton.DrawButton(Win);

  if WImage then
  begin
    GF := TGameField(Game[gsGame]);
    s := (Win^.GZZHeight div 2 - fh div 2) div 2;
    w := Min(10, max(2, s div GF.GField.AreaSize.CY));
    fh := Win^.GZZWidth  div 2 - (w * GF.GField.AreaSize.CX) div 2;
    H := s div 2 - (w * GF.GField.AreaSize.CY) div 2;
    //
    SetAPen(Win^.RPort, 1);
    for y := 0 to GF.GField.AreaSize.CY - 1 do
    begin
      for x := 0 to GF.GField.AreaSize.CX - 1 do
      begin
        if GF.GField.Area[x,y] then
        begin
          RectFill(Win^.RPort, fh + x * w, H + y * w, fh + (x + 1) * w, H + (y + 1) * w);
        end;
      end;
    end;
  end;
end;


procedure TGameMessage.FirstEnter(Win: PWindow);
begin
  PaintWindow(Win);
  FButton.StartAnimation(Win, adBottom);
  repeat
    FButton.DoAnimation(Win);
    Sleep(1);
  until not FButton.IsMoving;
  PaintWindow(Win);
end;

procedure TGameMessage.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
begin
  inherited;
  if not Down then
    Exit;
  if PtInRect(FButton.Border, Point(X, Y)) then
  begin
    if Assigned(OnClick) then
      OnClick(Win);
  end;
end;

procedure TGameMessage.MouseMove(Win: PWindow; x, y: Integer);
begin
  FButton.MouseOver(Win, x, y);
end;

//######################################################################
//               Game Question (simply yes/no questions)
constructor TGameQuestion.Create;
begin
  inherited;
  FText := TStringList.Create;
  FYesButton := TButton.Create('Yes', Point(-300, -200));
  FNoButton := TButton.Create('No', Point(-300, -200));
end;

destructor TGameQuestion.Destroy;
begin
  FText.Free;
  FYesButton.Free;
  FNoButton.Free;
  inherited;
end;

procedure TGameQuestion.PaintWindow(Win: PWindow);
var
  FontSize: TTextExtent;
  s, w, fh, H, i: Integer;
  line: string;
begin
  SetDrMd(Win^.RPort, JAM1);
  SetAPen(Win^.RPort, 1);
  SetRast(Win^.RPort, 2);
  TextExtent(Win^.RPort, 'W', 1, @FontSize);
  h := FontSize.te_Height + 5;
  fh := h * FText.Count + 2;
  s := Win^.GZZHeight div 2 - fh div 2;
  for i := 0 to FText.Count - 1 do
  begin
    line := FText[i];
    w := Win^.GZZWidth div 2 - TextLength(Win^.RPort, PChar(Line), Length(Line)) div 2;
    GfxMove(Win^.RPort, w, s + i * h);
    GFXText(Win^.RPort, PChar(line), Length(line));
  end;
  w := Win^.GZZWidth div 2 - FYesButton.Border.Width - FYesButton.Border.Width div 2;
  s := Win^.GZZHeight - (FYesButton.Border.Height + 10);
  FYesButton.Border.SetLocation(w, s);
  w := Win^.GZZWidth div 2 + FNoButton.Border.Width div 2;
  FNoButton.Border.SetLocation(w, s);
  FYesButton.DrawButton(Win);
  FNoButton.DrawButton(Win);
end;

procedure TGameQuestion.FirstEnter(Win: PWindow);
begin
  PaintWindow(Win);
  FYesButton.StartAnimation(Win, adLeft);
  FNoButton.StartAnimation(Win, adRight);
  repeat
    FYesButton.DoAnimation(Win);
    FNoButton.DoAnimation(Win);
    Sleep(1);
  until (not FYesButton.IsMoving) and (not FNoButton.IsMoving);
  PaintWindow(Win);
end;

procedure TGameQuestion.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
begin
  inherited;
  if not Down then
    Exit;
  if PtInRect(FYesButton.Border, Point(X, Y)) then
  begin
    if Assigned(OnYesClick) then
      OnYesClick(Win);
  end;
  if PtInRect(FNoButton.Border, Point(X, Y)) then
  begin
    if Assigned(OnNoClick) then
      OnNoClick(Win);
  end;
end;

procedure TGameQuestion.MouseMove(Win: PWindow; x, y: Integer);
begin
  FYesButton.MouseOver(Win, x, y);
  FNoButton.MouseOver(Win, x, y);
end;

//######################################################################
//               TGame Level (Level selector)

procedure RefreshFileList(List: TFileButtons);
var
  Info: TSearchRec;
  Entry: TFileButton;
  i: Integer;
begin
  SetLength(FileList, 0);
  if FindFirst ('*.lvl', faAnyFile, Info) = 0 then
  begin
    repeat
      //
    until FindNext(Info) <> 0;
  end;
  FindClose(Info);

  for i := 0 to 9 do
  begin
    Entry := TFileButton.Create;
    Entry.Button := TButton.Create('File ' + IntToStr(I+1), Point(5, 40 + i* 20));
    Entry.Button.WithBorder := False;
    List.Add(Entry);
  end;
end;

constructor TGameLevel.Create;
begin
  inherited Create;
  TutorialButton := TButton.Create('Tutorial', Point(5, -200));
  TutorialButton.WithBorder := False;
  //
  FileButtons := TFileButtons.Create(True);
  RefreshFileList(FileButtons);
  //
  LevelButtons := TFileButtons.Create(True);
  //
  UserButton := TButton.Create('User', Point(5, -200));
  UserButton.WithBorder := False;
  //
  BackButton := TButton.Create('Back', Point(-500, 400));

  RandomButton := TButton.Create('Random', Point(-500, -500));

  RandomX := TNumEdit.Create(5, Point(-500,-500));
  RandomX.MinValue := 1;
  RandomX.MaxValue := 15;
  RandomY := TNumEdit.Create(5, Point(-500,-500));
  RandomY.MinValue := 1;
  RandomY.MaxValue := 15;

end;

destructor TGameLevel.Destroy;
begin
  TutorialButton.Free;
  FileButtons.Free;
  LevelButtons.Free;
  UserButton.Free;
  BackButton.Free;
  RandomButton.Free;
  RandomX.Free;
  RandomY.Free;
  inherited;
end;

procedure TGameLevel.PaintWindow(Win: PWindow);
var
  FontSize: TTextExtent;
  MaxW: Integer;
  s: string;
  y, i: Integer;
begin
  SetRast(Win^.RPort, 2);
  TextExtent(Win^.RPort, 'W', 1, @FontSize);
  //
  s := 'Tutorial';
  MaxW := TextLength(Win^.RPort, PChar(s), Length(s));
  //
  SetAPen(Win^.RPort, 1);
  SetDrMd(Win^.RPort, JAM1);
  //
  GfxMove(Win^.RPort, 5, 2 + FontSize.te_Height);
  GfxText(Win^.RPort, 'Packages', 8);
  y := 5 + FontSize.te_Height + 6;

  // Tutorial
  TutorialButton.Border := Rect(5, y, 20 + MaxW, y + FontSize.te_Height + 2);
  TutorialButton.DrawButton(Win);
  // FileButtons
  for i := 0 to FileButtons.Count - 1 do
  begin
    y := y +  + FontSize.te_Height + 2 ;
    FileButtons[i].Button.Border := Rect(5, y, 20 + MaxW, y + FontSize.te_Height + 2);
    FileButtons[i].Button.DrawButton(Win);
  end;
  // UserButtons
  y := y +  + FontSize.te_Height + 2;
  UserButton.Border := Rect(5, y, 20 + MaxW, y + FontSize.te_Height + 2);
  UserButton.DrawButton(Win);
  // BackButtons
  y := y +  + FontSize.te_Height + 4;
  BackButton.Border := Rect(5, Win^.GZZHeight - FontSize.te_Height - 10, 20 + MaxW, Win^.GZZHeight - 5);
  BackButton.DrawButton(Win);

  // RandomButton
  y := y +  + FontSize.te_Height + 4;
  RandomButton.Border := Rect(Win^.GZZWidth - 5 - (20 + MaxW), Win^.GZZHeight - FontSize.te_Height - 10, Win^.GZZWidth - 5, Win^.GZZHeight - 5);
  RandomButton.DrawButton(Win);

  RandomY.Border := RandomButton.Border;
  RandomY.Border.Width := 60;
  RandomY.Border.Offset(-(RandomButton.Border.Width + 20), 0);
  RandomY.DrawNumEdit(Win);

  RandomX.Border := RandomY.Border;
  RandomX.Border.Offset(-(RandomY.Border.Width + 20), 0);
  RandomX.DrawNumEdit(Win);
  SetAPen(Win^.RPort, 1);
  SetDrMd(Win^.RPort, JAM1);
  GFXMove(Win^.RPort, RandomX.Border.Left - FontSize.te_Width * 2, RandomX.Border.Top + RandomX.Border.Height div 2 + 3);
  GFXText(Win^.RPort, 'X', 1);
  GFXMove(Win^.RPort, RandomY.Border.Left - FontSize.te_Width * 2, RandomY.Border.Top + RandomY.Border.Height div 2 + 3);
  GFXText(Win^.RPort, 'Y', 1);



  // Levels
  if LevelButtons.Count > 0 then
  begin
    MaxW := Max(MaxW, 100);
    for i := 0 to LevelButtons.Count - 1 do
      MaxW := Max(MaxW, TextLength(Win^.RPort, PChar(s), Length(s)));
    //
    SetAPen(Win^.RPort, 1);
    SetDrMd(Win^.RPort, JAM1);
    //
    GfxMove(Win^.RPort, 40 + MaxW, 2 + FontSize.te_Height);
    GfxText(Win^.RPort, 'Levels', 6);
    y := 5 + FontSize.te_Height + 6;
    // FileButtons
    for i := 0 to LevelButtons.Count - 1 do
    begin
      y := y +  + FontSize.te_Height + 2 ;
      LevelButtons[i].Button.Border := Rect(40 + MaxW, y, 60 + 2 * MaxW, y + FontSize.te_Height + 2);
      LevelButtons[i].Button.DrawButton(Win);
    end;
  end;
end;

procedure TGameLevel.MouseClick(Win: PWindow; x, y: Integer; Down: Boolean);
var
  i: Integer;
begin
  inherited;
  if not Down then
    Exit;
  if BackButton.MouseOver(Win, x, y) then
  begin
    GameStatus := gsMainMenu;
    Game[GameStatus].FirstEnter(Win);
    Exit;
  end;
  if TutorialButton.MouseOver(Win, x, y) then
  begin
    LoadTutorial;
    LevelToButtons;
    PaintWindow(Win);
    Exit;
  end;

  if RandomButton.MouseOver(Win, x, y) then
  begin
    GameStatus := gsGame;
    TGameField(Game[gsGame]).RandomField(RandomX.Value, RandomY.Value);
    Game[GameStatus].FirstEnter(Win);
    Exit;
  end;

  RandomX.MouseClick(Win, x, y);
  RandomY.MouseClick(Win, x, y);

  for i := 0 to LevelButtons.Count - 1 do
  begin
    if LevelButtons[i].Button.MouseOver(Win, x, y) then
    begin
      GameStatus := gsGame;
      TGameField(Game[gsGame]).LoadLevel(i);
      Game[GameStatus].FirstEnter(Win);
      Exit;
    end;
  end;
end;

procedure TGameLevel.LevelToButtons;
var
  Entry: TFileButton;
  i: Integer;
begin
  LevelButtons.Clear;
  for i := 0 to High(Levels) do
  begin
    Entry := TFileButton.Create;
    Entry.Button := TButton.Create(Levels[i].Name, Point(-100, 100));
    Entry.Button.WithBorder := False;
    Entry.Button.Enabled := Levels[i].Enabled;
    LevelButtons.Add(Entry);
  end;
end;

procedure TGameLevel.MouseMove(Win: PWindow; x, y: Integer);
var
  IsOver: Boolean;
  i: Integer;
begin
  TutorialButton.MouseOver(Win, x, y);
  for i := 0 to FileButtons.Count - 1 do
    FileButtons[i].Button.MouseOver(Win, x, y);
  for i := 0 to LevelButtons.Count - 1 do
    LevelButtons[i].Button.MouseOver(Win, x, y);
  UserButton.MouseOver(Win, x, y);
  BackButton.MouseOver(Win, x, y);
  RandomButton.MouseOver(Win, x, y);
  RandomX.MouseOver(Win, x, y);
  RandomY.MouseOver(Win, x, y);
end;

procedure TGameLevel.FirstEnter(Win: PWindow);
var
  i: Integer;
  Moving: Boolean;
begin
  LevelToButtons;
  PaintWindow(Win);
  //
  TutorialButton.StartAnimation(Win, adLeft);
  for i := 0 to FileButtons.Count - 1 do
    FileButtons[i].Button.StartAnimation(Win, adLeft);
  UserButton.StartAnimation(Win, adLeft);
  BackButton.StartAnimation(Win, adBottom);
  RandomButton.StartAnimation(Win, adRight);
  //
  PaintWindow(Win);
  //
  repeat
    TutorialButton.DoAnimation(Win);
    for i := 0 to FileButtons.Count - 1 do
      FileButtons[i].Button.DoAnimation(Win);
    UserButton.DoAnimation(Win);
    BackButton.DoAnimation(Win);
    RandomButton.DoAnimation(Win);
    Sleep(1);
    Moving := TutorialButton.IsMoving or UserButton.IsMoving or BackButton.IsMoving or RandomButton.IsMoving;
    for i := 0 to FileButtons.Count - 1 do
      Moving := Moving or FileButtons[i].Button.IsMoving;
  until not Moving;
end;


//######################################################################
//               Main Routines
procedure DoPaint(Win: PWindow);
begin
  Game[GameStatus].PaintWindow(Win);
end;

procedure WinClick(Win: PWindow);
begin
  if CurLevelNum >= High(Levels) then
  begin
    GameStatus := gsLevel;
    Game[GameStatus].FirstEnter(Win);
    Game[GameStatus].PaintWindow(Win);
  end
  else
  begin
    GameStatus := gsGame;
    TGameField(Game[GameStatus]).LoadLevel(CurLevelNum + 1);
    Game[GameStatus].FirstEnter(Win);
    Game[GameStatus].PaintWindow(Win);
  end;
end;

procedure HelpOKClick(Win: PWindow);
begin
  GameStatus := gsMainMenu;
  Game[GameStatus].FirstEnter(Win);
  Game[GameStatus].PaintWindow(Win);
end;

procedure ReturnToGameClick(Win: PWindow);
begin
  GameStatus := gsGame;
  Game[GameStatus].PaintWindow(Win);
end;



//           central eventhandling
procedure handle_window_events(win: PWindow);
var
  msg   : PIntuiMessage;
begin
  Game[GameStatus].FirstEnter(Win);
  DoPaint(Win);
  if not Assigned(win^.UserPort) then
  begin
    writeln('win^.userport is nil');
  end;
  PrgEnd := False;
  while not(PrgEnd) do
  begin
    //We have no other ports of signals to wait on,
    // so we'll just use WaitPort() instead of Wait()
    WaitPort(win^.UserPort);

    // Main loop
    while not PrgEnd do
    begin
      Msg := PIntuiMessage(GetMsg(win^.UserPort));
      if not Assigned(Msg) then
        break;
      // use a case statement if looking for multiple event types
      case msg^.IClass of
       IDCMP_CLOSEWINDOW: PrgEnd := True;
       IDCMP_REFRESHWINDOW: DoPaint(Win);
       IDCMP_INTUITICKS: TGameMenu(Game[GameStatus]).TimeTick(Win);
       IDCMP_MOUSEMOVE: Game[GameStatus].MouseMove(Win, Win^.GZZMouseX, Win^.GZZMouseY);
       IDCMP_RAWKEY: if (Msg^.Code and IECODE_UP_PREFIX) <> 0 then Game[GameStatus].KeyUp(Win, Msg^.Qualifier, Msg^.Code and not IECODE_UP_PREFIX);
       IDCMP_MOUSEBUTTONS:
        if Msg^.Code = SelectDown then
          Game[GameStatus].MouseClick(Win, Win^.GZZMouseX, Win^.GZZMouseY, True)
        else
          if Msg^.Code = SelectUp then
            Game[GameStatus].MouseClick(Win, Win^.GZZMouseX, Win^.GZZMouseY, False);
      end;
      ReplyMsg(PMessage(msg));
    end;
  end;
end;

// Main routine
procedure StartMe;
var
  Win: PWindow;
  GS: TGameStatus;
begin
  Game[gsMainMenu] := TGameMenu.Create;
  Game[gsLevel] := TGameLevel.Create;
  Game[gsGame] := TGameField.Create;
  Game[gsLeaveGame] := TGameQuestion.Create;
  with TGameQuestion(Game[gsLeaveGame]) do
  begin
    FText.Add('Do you want leave that level?');
    FText.Add('Progress will be lost.');
    OnYesClick := @HelpOKClick;
    OnNoClick := @ReturnToGameClick;
  end;
  Game[gsHelp] := TGameMessage.Create;
  with TGameMessage(Game[gsHelp]) do
  begin
    FText.Add('Redraw It');
    FText.Add('2018 Marcus "ALB42" Sackrow');
    FText.Add('programmed with FreePascal for Amiga Systems');
    FText.Add('');
    FText.Add('reconstruct the image by the numbers at the side.');
    OnClick := @HelpOKClick;
  end;

  Game[gsWin] := TGameMessage.Create;
  with TGameMessage(Game[gsWin]) do
  begin
    FText.Add('Congratulation');
    FText.Add('You finished this level');
    OnClick := @WinClick;
  end;

  Game[gsEdit] := TGameMessage.Create;
  Game[gsQuit] := TGameMessage.Create;

  Win := OpenWindowTags(nil,
  [
    WA_Left           ,10,
    WA_Top            ,20,
    WA_Width          ,600,
    WA_Height         ,400,
    WA_MaxWidth       ,10000,
    WA_MaxHeight      ,10000,
    WA_MinWidth       ,550,
    WA_MinHeight      ,250,
    WA_Flags,
      WFLG_DEPTHGADGET or WFLG_DRAGBAR or WFLG_CLOSEGADGET or WFLG_SIZEGADGET or
      WFLG_ACTIVATE or WFLG_OTHER_REFRESH or WFLG_GIMMEZEROZERO or WFLG_REPORTMOUSE,
    WA_IDCMP,
      IDCMP_CLOSEWINDOW or IDCMP_REFRESHWINDOW or IDCMP_IDCMPUPDATE or
      IDCMP_MOUSEBUTTONS or IDCMP_MOUSEMOVE or IDCMP_INTUITICKS or
      IDCMP_RAWKEY,
    WA_Title          , AsTAG(PChar('Redraw It')),
    WA_PubScreenName  , AsTAG(PChar('Workbench')),
    TAG_END
  ]);
  //
  try
    if Assigned(Win) then
      handle_window_events(Win);
  finally
    for GS := Low(Game) to High(Game) do
    begin
      Game[GS].Free;
      Game[GS] := nil;
    end;
    if assigned(Win) then
      CloseWindow(Win);
  end;
end;

begin
  StartMe;
end.
