#include "symbols.h"
#include <stdint.h>

//QSQLでロードする情報
typedef struct {
	//ゲーム状態
	uint32_t sav_gameStates;

	//座標
	uint32_t sav_pos;
	//ワープスターに乗っているかやゴールゲーム中かなど
	uint32_t sav_playerMode;
	//無敵キャンディ
	uint16_t sav_playerInvincibility;

	//プレイヤー・ヘルパー
	uint8_t sav_playerRiding;
	uint8_t sav_helperRode;
	uint32_t sav_playerStates;
	uint32_t sav_helperStates;

	//銀河
	uint32_t sav_mww_abilities;
	uint8_t sav_mww_selectedAbility;

	//格闘王
	uint8_t sav_arena_boss;

	//ビットフラグ
	uint16_t options;
} Sav;
enum SavOption{
	SavOption_MUSIC_RESET = 0x1,	//曲リセットするか
};

//ゲームモードとセーブスロットごとのQSQLでロードする情報
#define GameModeLen 12
#define SaveSlotLen 9
typedef struct {
	Sav slots[SaveSlotLen];
	uint8_t index;
} SaveGroup;
SaveGroup saveGroups[GameModeLen];

//遷移時に保持するQSQLでロードする情報
Sav tmp_sav;
Sav prev_sav;
//QL中のSav
Sav* ql;

//ロードのリダイレクトの設定
uint8_t redirect;
enum Redirect{
	Redirect_Loop = 2,	//左
	Redirect_QL = 6,	//左上
	Redirect_Random = 4,	//上
	Redirect_Recommend = 5,	//右上
};
int32_t prevTimer;

//ほおばりのセーブ
uint32_t sav_inhale1;
uint32_t sav_inhale2;

//曲が変わったかの監視用
uint32_t prevMusic;

//MixView用のカウンター
uint32_t mix_cnt;

// 下画面に表示させる4桁の数値4つ
uint32_t show[4];

const uint32_t RoMK_positions[7] = {0x01D10956, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C};
const uint8_t abilities_for_save[9] = {
	JET,	//ニュートラル
	STONE,	//右
	NORMAL,	//左
	FIRE,	//左下
	WING,	//上
	WHEEL,	//右上
	NINJA,	//左上
	PARASOL,	//右下
	HAMMER,	//下
};

//十字キーの入力に応じた8方向と無入力の9通りの値を得る
static inline int getArrow(void){
	int arrow = (heldButtons & 0xF0) >> 4;
	if(arrow > 8){arrow = (0b0111 << 9) >> arrow;}
	return arrow;
}

void QS(void){
	SaveGroup* g = &saveGroups[gameMode];
	Sav* t = &tmp_sav;

	//マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる
	consumedItems[0] = 0;

	//座標を監視してフロア遷移時の情報を保持する
	if(getPos == 0 || getPos == POS_IN_CORKBOARD){
		//遷移中の最初のフレーム(座標が0になったら)
		if(t->sav_pos != 0){
			prev_sav = *t;

			t->sav_pos = 0;
			prevMusic = music;
			if(ql){
				playerInvincibility = ql->sav_playerInvincibility;	//無敵キャンディ時間をロード

				//タイマーリセット
				timer = 0;
				prevTimer = 0;
			}else{
				//無敵キャンディ時間を保持
				t->sav_playerInvincibility = playerInvincibility;
			}
		}
	}else{
		//遷移後の最初のフレーム(座標が0ではなくなったら)
		if(t->sav_pos == 0){	
			ql = 0;

			//フロア遷移時の座標と状態
			t->sav_pos = getPos;	//フロア遷移時の初期座標を保持
			t->sav_playerMode = playerMode;	//フロア遷移時のワープスターに乗っているかやゴールゲーム中かなどの状態を保持

			//状態・ゲームモード・ステージ・フロア
			t->sav_gameStates = (room << 24) | (stage << 16) | (gameMode << 8) | STATE_FLOOR_LOAD;

			//個別の対応
			if(gameMode == RoMK){
				//メタ逆のステージ最初のフロアなら
				if(room == 0){
					t->sav_pos = RoMK_positions[stage];
				}
			}else{
				switch(t->sav_gameStates){
				case 0x00040601:
					//大王5-1でQSすると次のフロアでソフトロックするのの対策
					t->sav_playerMode = 0;
					break;
				case 0x02080501:
					//銀河に願いをのマルク戦
					t->sav_pos = 0x02190042;
					t->sav_playerMode = 0x000000FF;
					break;
				}
			}

			//能力
			t->sav_playerStates = playerStates;
			t->sav_playerRiding = playerRiding;
			
			t->sav_helperStates = helperStates;
			if(t->sav_helperStates == 0x08080101){t->sav_helperStates = 0x08080201;}	//通常状態からウィリーライダーをQLするときの対策
			t->sav_helperRode   = helperRode;

			//銀河
			t->sav_mww_abilities = mww_abilities;
			t->sav_mww_selectedAbility = mww_selectedAbility;

			//格闘王系でのボス
			t->sav_arena_boss = arena_boss;

			//曲を最初からにするかの設定
			t->options = 0;
			if(prevMusic != music){
				t->options |= SavOption_MUSIC_RESET;
			}
		}
	}

	//ほおばりのロード
	if(sav_inhale1 != 0){
		playerInhale1 = sav_inhale1;
		playerInhale2 = sav_inhale2;
		playerInvincibility = 1;
	}

	//ダイナのスイッチがステージに入ってるときはあってステージ選択画面ではおためし部屋があるようにする
	if(gameMode == DYNA_BLADE){
		if(gameState > 1){
			db_switches = 3;
		}else{
			db_switches = 0;
		}
	}

	//ミックスのカウントアップ停止を検知して結果を表示(最初の能力の1F目は検知できない)
	if(mix_cnt != 0){
		if(mix_cnt < (mix_cnt << 20)){
			mix_cnt += 0x100000;
		}else{
			show[3] = 1;
			while((mix_cnt = (mix_cnt + 1) & 3)){
				show[3] *= 10;
			}
		}
	}

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		//ポーズ時にY押しながら左右で格闘王のボスを切り替える
		if(Y & heldButtons){
			int last;
			switch(gameMode){
			case THE_ARENA:
				last = 18;
				goto SWITCH_BOSS;
			case HELPER_TO_HERO:
				last = 13;
				goto SWITCH_BOSS;
			case THE_TRUE_ARENA:
				last = 9;
			SWITCH_BOSS:
				if((LEFT | RIGHT) & pressedButtons){
					int id = t->sav_arena_boss;

					if(LEFT & pressedButtons){
						id--;
						if(id < 0){
							id = last;
						}
					}else{
						id++;
						if(id > last){
							id = 0;
						}
					}

					t->sav_arena_boss = id;
					arena_boss = id;
					arena_boss_img_changing = 2;
				}
				break;
			}
		}else{
			//十字キーの入力に応じた8方向と無入力の9通りの値を得る
			int arrow = getArrow();
			//ポーズ時にLでQS
			if(L & pressedButtons){
				//セーブスロット選択
				g->index = arrow;
				g->slots[arrow] = *t;

				//ほおばりのセーブ
				if(playerForm == Form_INHALE){
					sav_inhale1 = playerInhale1;
					sav_inhale2 = playerInhale2;
				}else{
					sav_inhale1 = 0;
				}
			}
			//Xで解除
			else if(X & pressedButtons){
				g->slots[arrow].sav_gameStates = 0;
			}
			//Rでロードのリダイレクトの設定
			else if(R & pressedButtons){
				redirect = arrow;
			}
		}
		break;
	case STATE_PLAY:
		//はるかぜとともにのステージ冒頭のムービー中とかワープスターに乗ってるときでもポーズできるようにする
		if((R & heldButtons) && (START & heldButtons)){
			gameState = STATE_PAUSE;
		}
		break;
	default:
		if(prevTimer == -1){
			show[0] = 0;
		}else{
			int n = timer - prevTimer;	//区間タイム
			prevTimer = timer;
			if(n > 0){
				show[0] = timer;	//表示タイムの更新
				//区間タイム
				if(n > 1){
					show[3] = show[2];
					show[2] = show[1];
					show[1] = n;
				}else{
					show[1] += n;
				}
			}
		}
	}
}

void QL(void){
	//既にQS情報をロード中なら
	if(ql){return;}

	SaveGroup* g = &saveGroups[gameMode];
	Sav* s = &tmp_sav;

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		return;
	case STATE_PLAY:
		//通常時にLでQL
		if(L & pressedButtons){
			if(R & heldButtons){
				//十字キーの入力に応じた8方向と無入力の9通りの値を得る
				int arrow = getArrow();
				//Xで能力上書き
				if(X & heldButtons){
					//十字キーによる能力選択
					((uint8_t*)(&s->sav_playerStates))[3] = abilities_for_save[arrow];
				//Yで座標上書き
				}else if(Y & heldButtons){
					s->sav_pos = getPos;
				}
				//Rでセーブスロット選択
				else{
					g->index = arrow;
					goto QL_SLOT;
				}
			}else{
				//Y押しながらで前の一時セーブをQL
				if(Y & heldButtons){
					s = &prev_sav;
				}
				//QSされていればQL
				else{
				QL_SLOT:
					s = &g->slots[g->index];
				}
			}
		}
		//Y押しながらRで一時セーブをQL
		else if(R & pressedButtons){
			if(Y & heldButtons){

			}else{return;}
		}else{return;}
		prevTimer = -1;	//redirectではないQLによるタイマーリセット
		break;
	case STATE_STAGE_CLEAR:
	case STATE_GAME_CLEAR:
	case STATE_MAP:
		if(redirect == Redirect_Random){
			int a[9];
			int len = 0;
			for(int i=0; i < 9; i++){
				if(g->slots[i].sav_gameStates != 0){
					a[len] = i;
					len++;
				}
			}
			g->index = a[seed * len >> 12];
			goto REDIRECT_TO_SLOT;
		}
		else if(redirect == Redirect_QL){
		REDIRECT_TO_SLOT:
			s = &g->slots[g->index];
			break;
		}
		[[fallthrough]];
	default:
		if(redirect == Redirect_Loop){break;}
		return;
	}

	//ロード
	{
		if(s->sav_gameStates == 0){return;}
		ql = s;

		//HPと残機を最大に
		playerHP = playerMaxHP;
		helperHP = helperMaxHP;
		lives = 99;

		//ゲームモード別の処理
		if(gameMode != HELPER_TO_HERO){
			//能力のロード
			playerStates = s->sav_playerStates;
			playerRiding = s->sav_playerRiding;
			helperStates = s->sav_helperStates;
			helperRode   = s->sav_helperRode;
		}
		switch(gameMode){
		case THE_ARENA:
		case THE_TRUE_ARENA:
		case HELPER_TO_HERO:
			//格闘王系のモードでのボスのロード
			arena_idx = 0;
			arena_bosses[0] = s->sav_arena_boss;
			gameState = STATE_ARENA_MATCH;
			//画像切り替え
			arena_boss = s->sav_arena_boss;
			arena_boss_img_changing = 2;
			break;
		default:
			//曲のリセット
			if(s->options & SavOption_MUSIC_RESET){
				music = Music_MUTE;
			}
			//フロアと座標と状態
			gameStates = s->sav_gameStates;
			setPos = s->sav_pos;
			playerMode = s->sav_playerMode;
			switch(gameMode){
			case GCO:
				//洞窟のお宝とボスをリセット
				gco_treasures[0] = 0;
				gco_treasures[1] = 0;
				gco_treasuresCnt = 0;
				gco_bosses = 0;
				break;
			case MWW:
				//銀河の開放済み能力とその選択位置をQL
				mww_abilities = s->sav_mww_abilities;
				mww_selectedAbility = s->sav_mww_selectedAbility;
				mww_changingSelectedAbility = 1;
				//増えすぎるとこれを表示するオレンジ色の丸のところのグラフィックがなんかバグるから一応0にしておく
				mww_abilitiesByStage[0] = 0;
				*(uint32_t*)(mww_abilitiesByStage+1) = 0;
				*(uint16_t*)(mww_abilitiesByStage+5) = 0;
				mww_abilitiesByStage[7] = 0;
				break;
			case MKU:
				//メタナイトでゴーのPtを最大に
				mkuPt = 50;
				break;
			}
		}
	}
}

//真格闘王で下画面のボスの表示を「？？？」から切り替える処理の一部を上書きして他のにも切り替えられるようにする
extern void free_resource(uint32_t handle);
extern uint32_t load_resource_A(uint32_t id);
extern uint32_t load_resource_B(uint32_t id);
extern void setup_resource(uint32_t a, uint32_t b, uint32_t c, uint32_t d);
void ArenaImageSwitcher(int mode){
	register int r4 asm("r4");
	uint32_t* resource_handle = (uint32_t*)(r4 + 0x40);
	uint8_t* image_index = (uint8_t*)(r4 + 0x48);

	//モードに応じたリソースをロード
	uint32_t image_id = *image_index;
	uint32_t sub_image_id = 0x0206e000 + image_id * 12;

	switch(mode){
	case THE_ARENA:	//格闘王の道
		sub_image_id += 0x140;
		image_id += 0x40;
		break;
	case HELPER_TO_HERO:	//ヘルパーマスターへの道
		sub_image_id += 0x098;
		image_id += 0x31;
		break;
	case THE_TRUE_ARENA:	//真・格闘王への道
		sub_image_id += 0x014;
		image_id += (image_id < 6) ? 0x53 : 0x57;
		break;
	default:
		return;
	}

	image_id += 0x12000;
	setup_resource(1, load_resource_A(image_id), 0x06218400, 0x2400);

	image_id -= 0x30;
	*resource_handle = load_resource_B(image_id);
	setup_resource(0x36, *resource_handle, 0x5c00, 0x1a0);

	setup_resource(1, load_resource_A(*(uint32_t*)sub_image_id), 0x06603800, 0x300);

	return;
}

//ミックスルーレット中に毎フレーム実行されるカウントアップ処理
void MixStep(void){
    mix_cnt++;
}

//残機描画関数(0x02090D48)の中身を書き換えて、show配列の数値を下画面に描画する
extern void draw_image(int a, int img, int b, int x, int y, int c);
#define NUMBER_IMAGES 0x021E2668
void DrawNumbers(int some_addr, int x_pos, int y_pos, int lives_){
	(void)some_addr; (void)x_pos; (void)lives_;
	int x = 0x3C - 19;

	for(int i = 0; i < 4; i++){
		unsigned int num = show[i];

		//numが4桁を超える場合は9999
		unsigned int digit = 10000;
		if(num >= digit){
			num = digit - 1;
		}
		//各桁の描画
		do{
			digit = (digit * 205) >> 11;	//digit /= 10

			int img = NUMBER_IMAGES;
			while(num >= digit){
				num -= digit;
				img += 8;
			}

			draw_image(0x78, img, 0, x, y_pos, 1);

			x += 10;
		}while(digit > 1);

		x += 8;
	}
}
