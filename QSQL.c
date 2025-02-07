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

int* const playerMode = (int*)0x0205B248;	//ワープスターに乗っているかやゴールゲーム中かなど
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

char* const arena_idx = (char*)0x0206FC62;	//格闘王系で何戦目か
char* const arena_bosses = (char*)0x0206FC66;	//格闘王系でのボスの並びが記憶されている配列

int* const  mww_abilities               =  (int*)0x02070A40;	//銀河の開放済み能力
char* const mww_abilitiesByStage        = (char*)0x02070A47;	//ステージごとの開放済み能力の数を記憶した長さ8の配列
char* const mww_selectedAbility         = (char*)0x02070A5C;	//銀河の選択能力
char* const mww_changingSelectedAbility = (char*)0x02070A5E;	//選択能力が遷移中なら1

int* const  getPos = (int*)0x02076878;	//1Pの座標

char* const playerHP    = (char*)0x02076A94;	//1PのHP
char* const playerMaxHP = (char*)0x02076A96;	//1Pの最大HP
char* const helperHP    = (char*)0x02076CD8;	//2PのHP
char* const helperMaxHP = (char*)0x02076CDA;	//2Pの最大HP

int* const displayMode = (int*)0x0209ECC4;	//スコア・ゴールドの所に何が表示されるか。0ならスコア・ゴールドを表示

int* const  playerStates = (int*)0x020BA318;	//1Pの能力
char* const playerRiding =(char*)0x020BA31D;	//ウィリーライダーなら2
short* const playerInvincibility = (short*)0x020BA5CC;	//1Pのむてきキャンディ/1Pと2pのメタクイックの残り時間

int* const  helperStates = (int*)0x020BAB34;	//2Pの能力
char* const helperRode   =(char*)0x020BAB39;	//ウィリーライダーなら2
short* const helperInvincibility = (short*)0x020BADE8;	//2Pのむてきキャンディの残り時間。メタクイックは1Pのが参照され、こっちは使われない

char* const menuPageIdx =(char*)0x021983CA;	//ポーズのメニューのページ番号

short* const buttons = (short*)0x04000130;	//押したボタンに対応するビットが0になる


int sav_gameStates;

int sav_playerStates;
char sav_playerRiding;
int sav_helperStates;
char sav_helperRode;

int sav_mww_abilities;
char sav_mww_selectedAbility;

int tmp_pos;
int sav_pos;

int tmp_playerMode;
int sav_playerMode;

short tmp_playerInvincibility;
short sav_playerInvincibility;
short tmp_helperInvincibility;
short sav_helperInvincibility;

char sav_arena_boss;

char prev_gameState;

int f(int pressed){
	//フロアに入ったときの座標などを記憶しておく
	if(*getPos == 0){
		tmp_pos = 0;
	}else if(tmp_pos == 0){
		tmp_pos = *getPos;
		tmp_playerMode = *playerMode;
	}

	//場面別の処理
	switch(*gameState){
	case STATE_PAUSE:
		//ポーズ時にLでQS
		if(L & pressed){
			//フロアと座標と状態
			sav_gameStates = *gameStates ^ (STATE_PAUSE ^ STATE_FLOOR_LOAD);
			sav_pos = tmp_pos;
			sav_playerMode = tmp_playerMode;

			//能力
			sav_playerStates = *playerStates;
			sav_playerRiding = *playerRiding;
			sav_playerInvincibility = tmp_playerInvincibility;

			sav_helperStates = *helperStates;
			if(sav_helperStates == 0x08080101){sav_helperStates = 0x08080201;}	//通常状態からウィリーライダーをQLするときの対策
			sav_helperRode   = *helperRode;
			sav_helperInvincibility = tmp_helperInvincibility;

			//銀河
			sav_mww_abilities = *mww_abilities;
			sav_mww_selectedAbility = *mww_selectedAbility;

			//格闘王系
			sav_arena_boss = arena_bosses[*arena_idx];
		}
		break;
	case STATE_PLAY:
		//通常時にLを押したとき同じゲームモードでセーブ済みならQL
		if((L & pressed) && ((*gameStates & 0xFFFF) | STATE_FLOOR_LOAD) == (sav_gameStates & 0xFFFF)){
			//HPと残機を最大に
			*playerHP = *playerMaxHP;
			*helperHP = *helperMaxHP;
			*lives = 99;

			//ゲームモード別の処理
			int mode = (sav_gameStates >> 8) & 0xFF;

			//能力
			if(mode != HELPER_TO_HERO){
				*playerStates = sav_playerStates;
				*playerRiding = sav_playerRiding;
				*playerInvincibility = sav_playerInvincibility;

				*helperStates = sav_helperStates;
				*helperRode   = sav_helperRode;
				*helperInvincibility = sav_helperInvincibility;
			}
			switch(mode){
			case THE_ARENA:
			case THE_TRUE_ARENA:
			case HELPER_TO_HERO:
				//格闘王系のモードでのボスのロード
				//R押しながらLで次のボスへ
				if(R & *buttons){
					*arena_idx = 0;
					arena_bosses[0] = sav_arena_boss;
					*gameState = STATE_ARENA_MATCH;
				}else{
					*gameState = STATE_ARENA_PROCEED;
				}
				break;
			default:
				//フロアと座標と状態
				*gameStates = sav_gameStates;
				*setPos = sav_pos;
				*playerMode = sav_playerMode;

				switch(mode){
				case GCO:
					//洞窟のお宝とボスをリセット
					gco_treasures[0] = 0;
					gco_treasures[1] = 0;
					*gco_treasuresCnt = 0;
					*gco_bosses = 0;
					break;
				case MWW:
					//銀河の開放済み能力とその選択位置をQL
					*mww_abilities = sav_mww_abilities;
					*mww_selectedAbility = sav_mww_selectedAbility;
					*mww_changingSelectedAbility = 1;
					//増えすぎるとこれを表示するオレンジ色の丸のところのグラフィックがなんかバグるから一応0にしておく
					for(int i=0; i < 8; i++){
						mww_abilitiesByStage[i] = 0;
					}
					break;
				case MKU:
					//メタナイトでゴーのPtを最大に
					*mkuPt = 50;
					break;
				}
			}
		}
		break;
	default:
		//フロアのロードとかの開始時に
		if(prev_gameState == STATE_PLAY){
			//むてきキャンディの時間を記憶しておく
			tmp_playerInvincibility = *playerInvincibility;
			tmp_helperInvincibility = *helperInvincibility;
		}
	}

	prev_gameState = *gameState;	//前の gameState を記憶しておく

	return pressed;
}