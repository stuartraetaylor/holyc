// vim: set ft=c:

#define DEBUG 1
#define SLOW 0

#define MIN_LEN 1
#define MAX_LEN 2048
#define STEP 3

#define MIN_X 0
#define MIN_Y 0

#define MAX_X TEXT_ROWS-2
#define MAX_Y TEXT_COLS

#define STATUS_ROW TEXT_ROWS-2

#define ATT_TEXT (WHITE<<12 +BLACK<<8)
#define ATT_GAME (CYAN<<12  +RED<<8)

#define CHAR_SNAKE CH_SPACE+ATT_GAME
#define CHAR_APPLE CH_SPACE+ATTRF_INVERT+ATT_GAME

// Screen.
U32 text[TEXT_ROWS][TEXT_COLS];
I64 delay; Bool game_end;

// Movement.
class Move {
  I64 dx,dy;
};

Move mv_left,mv_right,mv_up,mv_down;
mv_left.dx=0; mv_left.dy=-1;
mv_right.dx=0; mv_right.dy=1;
mv_up.dx=-1; mv_up.dy=0;
mv_down.dx=1; mv_down.dy=0;

// Snake.
I64 sx,sy,len,
    tail_x[MAX_LEN],
    tail_y[MAX_LEN];
Move *dir;

// Apple.
I64 ax,ay;

I64 score() { return len-MIN_LEN; }

I8 status_bg[TEXT_COLS]; MemSet(status_bg,' ',sizeof(status_bg));

//See $LK,"TextBase Layer",A="HI:TextBase Layer"$.
U0 DrawIt(CTask *task,CDC *) {
  //$LK,"gr.text_base",A="MN:CGrGlbls"$ gets clear 30fps, so we must use our own permanent text array.
  MemCpy(gr.text_base+TEXT_COLS,text,(TEXT_ROWS-1)*TEXT_COLS*sizeof(U32));

  TextPrint(task,0,STATUS_ROW,ATT_TEXT>>8,"%s", status_bg);

  TextPrint(task,TEXT_COLS-10,STATUS_ROW,ATT_TEXT>>8,
	"Score:%3d ",score());

  if (DEBUG) {
    TextPrint(task,0,STATUS_ROW,ATT_TEXT>>8,
	"x=%2d,y=%2d,ax=%2d,ay=%2d,dx=%d,dy=%d,len=%d,delay=%d",
	sx,sy,ax,ay,dir->dy,dir->dx,len,delay);
  }
}

U0 init() {
  sx=10; sy=10;
  dir=&mv_right;
  len=MIN_LEN;  
  ax=15; ay=MAX_Y/2;

  MemSet(tail_x,0,sizeof(tail_x));
  MemSet(tail_y,0,sizeof(tail_y));  

  game_end=FALSE;
}

Move* inv_move(Move* m) {
  switch (m) {
    case &mv_left:
      return &mv_right;
    case &mv_right:
      return &mv_left;
    case &mv_up:
      return &mv_down;
    case &mv_down:
      return &mv_up;
  }
}

U0 plot_snake() {
  // Move tail.
  I64 px = tail_x[0],
      py = tail_y[0];

  tail_x[0] = sx;
  tail_y[0] = sy;
  
  I64 i;
  for (i=1;i<len;i++) {
    I64 tx = tail_x[i],
        ty = tail_y[i];

    tail_x[i] = px;
    tail_y[i] = py;

    px=tx;
    py=ty;
  }

  // Move head.
  sx += dir->dx;
  sy += dir->dy;

  // Detect tail collision.
  for (i=0;i<len;i++) {
    if (sx == tail_x[i] && sy == tail_y[i]) {
      game_end=TRUE; // Lose!
      MemSet(text,'L',sizeof(text));
      Sleep(700);
      return;
    }
  }

  // Wrap screen.
  if (sx >= MAX_X)
    sx = MIN_X; 
  if (sy >= MAX_Y)
    sy = MIN_Y;

  if (sx < MIN_X)
    sx = MAX_X-1;
  if (sy < MIN_Y)
    sy = MAX_Y-1;
        	
  // Plot snake.
  text[sx][sy] = CHAR_SNAKE;
  
  for (i=0;i<len;i++)
    text[tail_x[i]][tail_y[i]] = CHAR_SNAKE;

}

U0 plot_apple() {
  // Detect collision.
  if (sx == ax && sy == ay) {
    text[ax][ay] = 0;
    len += STEP+(len/5.0);

    ax = (RandU64+MIN_X)%(MAX_X-MIN_X);
    ay = (RandU64+MIN_Y)%(MAX_Y-MIN_Y);
  }

  if (len == MAX_LEN) {
    game_end=TRUE; // Win!
    MemSet(text,'W',sizeof(text));
    Sleep(700);
    return;
  }

  // Plot.
  text[ax][ay] = CHAR_APPLE;
}

U0 animate() {
  while (TRUE) {
    if (!game_end)
      MemSet(text,0,sizeof(text));

    if (!game_end)
      plot_apple;

    if (!game_end)
      plot_snake;

    delay = 100*(1+SLOW)-score();
    Sleep(delay);
    Refresh;
  }
}

U0 move(Move *d) {
  if (d == inv_move(dir))
    return;

  dir=d;
}

U0 game() {
  SettingsPush; //See $LK,"SettingsPush",A="MN:SettingsPush"$
  AutoComplete;
  WinBorder;
  WinMax;
  DocCursor;
  DocClear;

  Fs->animate_task=Spawn(&animate,NULL,"Snake",,Fs);
  Fs->draw_it=&DrawIt;
  Fs->win_inhibit=WIG_TASK_DFT-WIF_SELF_FOCUS-WIF_SELF_BORDER;

  I64 sc;
  try {
    while (TRUE) {
      switch (GetKey(&sc)) {
        case CH_ESC:
        case CH_SHIFT_ESC:
          goto done;
        case 0:   
          switch (sc.u8[0]) {
            case SC_CURSOR_LEFT:
              move(&mv_left);
	      break;
            case SC_CURSOR_RIGHT:
              move(&mv_right);
              break;
            case SC_CURSOR_UP:
              move(&mv_up);
              break;
            case SC_CURSOR_DOWN:
              move(&mv_down);
              break;     
          }
      }
    
      // Restart.
      if (game_end)
        init;
    }
    done:
  } catch
      PutExcept;

  SettingsPop;
}

init;
game;
