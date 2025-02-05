enum Button{
	A      = 0x001,
	B      = 0x002,
	SELECT = 0x004,
	START  = 0x008,
	RIGHT  = 0x010,
	LEFT   = 0x020,
	UP     = 0x040,
	DOWN   = 0x080,
	R      = 0x100,
	L      = 0x200,
	X      = 0x400,
	Y      = 0x800,
};
enum GameState{
	STATE_PLAY         = 0,
	STATE_FLOOR_LOAD   = 1,
	STATE_STAGE_CLEAR  = 2,
	STATE_GAME_CLEAR   = 3,
	STATE_DIE          = 4,
	STATE_SPECIAL      = 5,
	STATE_ARENA_PROCEED= 5,
	STATE_MAP          = 6,
	STATE_ARENA_MATCH  = 6,
	STATE_SWITCH       = 7,
	STATE_SHORT_MOVIE  = 9,
	STATE_PAUSE        = 0xB,
};
enum GameMode{
	SPRING_BREEZE = 0,
	DYNA_BLADE    = 1,
	GOURMET_RACE  = 2,
	GCO           = 3,
	RoMK          = 4,
	MWW           = 5,
	RotK          = 6,
	THE_ARENA     = 7,
	MKU           = 8,
	HELPER_TO_HERO= 9,
	THE_TRUE_ARENA= 0xA,
	BEGINNERS_ROOM= 0xB,
};


int* const seed  = (int*)0x02041D3C;	//乱数
int* const timer = (int*)0x02041D60;	//タイマー

int*  const gameStates=  (int*)0x0205B244;
char* const gameState = (char*)0x0205B244;
char* const gameMode  = (char*)0x0205B245;
char* const stage     = (char*)0x0205B246;
char* const room      = (char*)0x0205B247;

int* const playerState = (int*)0x0205B248;	//ワープスターに乗っているかやゴールゲーム中かなど
int* const setPos      = (int*)0x0205B24C;	//フロア遷移時の初期座標の設定

int* const consumedItems = (int*)0x0205B270;	//キャンディや1upなどの復活しないアイテムが取られるとこのアドレスから列挙されていく。0を入れれば復活

int* const  score =  (int*)0x0205B3C0;	//スコア
char* const lives = (char*)0x0205B3C4;	//残機
char* const mkuPt = (char*)0x0205B3C5;	//MKUのPt

char* const db_switches = (char*)0x0206BDEA;	//ダイナのスイッチを押したか。1ビット目が「おためし部屋１」、2ビット目が「おためし部屋２」。0を入れればスイッチ復活

int* const  gco_treasures    = (int*)0x0206E100;	//洞窟のお宝を取得済みか60ビットで記録される。0でリセット
int* const  gco_gold         = (int*)0x0206E108;	//洞窟のゴールド
char* const gco_bosses       =(char*)0x0206E10E;	//ボスを倒したか
char* const gco_treasuresCnt =(char*)0x0206E112;	//お宝所持数

char* const arena_cnt = (char*)0x0206FC62;	//格闘王系で何戦目か

int* const  mww_abilities               =  (int*)0x02070A40;	//銀河開放済みコピー
char* const mww_selectedAbility         = (char*)0x02070A5C;	//銀河選択コピー
char* const mww_changingSelectedAbility = (char*)0x02070A5E;	//選択コピーが遷移中なら1

int* const  getPos = (int*)0x02076878;	//1Pの座標

char* const playerHP    = (char*)0x02076A94;	//1PのHP
char* const playerMaxHP = (char*)0x02076A96;	//1Pの最大HP
char* const helperHP    = (char*)0x02076CD8;	//2PのHP
char* const helperMaxHP = (char*)0x02076CDA;	//2Pの最大HP

int* const displayMode = (int*)0x0209ECC4;	//スコア・ゴールドの所に何が表示されるか。0ならスコア・ゴールドを表示

int* const  playerStates = (int*)0x020BA318;	//1Pの能力
char* const playerRiding =(char*)0x020BA31D;	//ウィリーライダーなら2
int* const  helperStates = (int*)0x020BAB34;	//2Pの能力
char* const helperRode   =(char*)0x020BAB39;	//ウィリーライダーなら2

int sav_gameStates;

int f(int pressed){
	if(L & pressed){
		switch(*gameState){
		case STATE_PAUSE:	//ポーズ時にLでQS
			sav_gameStates = (*gameStates & 0xFFFFFF00) | STATE_FLOOR_LOAD;	//フロアをセーブ
			break;
		case STATE_PLAY:	//通常時にLでQL
			if(((*gameStates & 0xFFFF) | STATE_FLOOR_LOAD) == (sav_gameStates & 0xFFFF)){	//同じモードでセーブ済みなら
				*gameStates = sav_gameStates;	//フロアをロード
			}
			break;
		}
	}
	return pressed;
}