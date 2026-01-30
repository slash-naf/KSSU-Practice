#include "symbols.h"

//遷移時に保持するQSQLでロードする情報
Sav tmp_sav;

//ほおばりのセーブ
uint32_t sav_inhale1;
uint32_t sav_inhale2;

//曲が変わったかの監視用
uint32_t prevMusic;

//ロードのモード
uint16_t loadOptions;

//Savのロードの状態
uint8_t loadSav;

//MixView用のカウンター
uint32_t mix_cnt;

//ゲームモードとセーブスロットごとのQSQLでロードする情報
uint8_t indexes[12];
Sav sav[12][9];

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

void QS(void){
	Sav* s = &sav[gameMode][indexes[gameMode]];
	Sav* t = &tmp_sav;

	//マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる
	consumedItems[0] = 0;

	//座標を監視してフロア遷移時の情報を保持する
	if(getPos == 0 || getPos == POS_IN_CORKBOARD){
		//遷移中の最初のフレーム(座標が0になったら)
		if(t->sav_pos != 0){
			t->sav_pos = 0;
			prevMusic = music;
			if(loadSav != LoadSav_NONE){
				playerInvincibility = s->sav_playerInvincibility;	//無敵キャンディ時間をロード
				if(loadSav == LoadSav_QL){
					timer = 0;	//タイマーリセット
				}
			}else{
				//無敵キャンディ時間を保持
				t->sav_playerInvincibility = playerInvincibility;
			}
		}
	}else{
		//遷移後の最初のフレーム(座標が0ではなくなったら)
		if(t->sav_pos == 0){	
			loadSav = LoadSav_NONE;

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
		db_switches = 0;
		if(gameState > 1){
			db_switches = 3;
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
		}
		//ポーズ時にYで、QS用に保持した座標を上書き
		if(Y & pressedButtons){
			t->sav_pos = getPos;
		}

		//十字キーの入力に応じた8方向と無入力の9通りの値を得る
		int arrow = (heldButtons & 0xF0) >> 4;
		if(arrow > 8){arrow = (0b0111 << 9) >> arrow;}
		//ポーズ時にXで、QS用に保持した能力を上書き
		if(X & pressedButtons){
			//十字キーによる能力選択
			((uint8_t*)(&t->sav_playerStates))[3] = abilities_for_save[arrow];
		}
		//ポーズ時にLでQS
		if(L & pressedButtons){
			//セーブスロット選択
			indexes[gameMode] = arrow;
			s = &sav[gameMode][arrow];

			*s = *t;

			//ほおばりのセーブ
			sav_inhale1 = 0;
			if(playerForm == Form_INHALE){
				sav_inhale1 = playerInhale1;
				sav_inhale2 = playerInhale2;
			}
		}
		//ポーズ時にRでロードのモードを設定
		if(R & pressedButtons){
			loadOptions = heldButtons;
		}
		break;
	case STATE_PLAY:
		//はるかぜとともにのステージ冒頭のムービー中とかワープスターに乗ってるときでもポーズできるようにする
		if((R & heldButtons) && (START & heldButtons)){
			gameState = STATE_PAUSE;
		}
		break;
	default:
		if(loadSav == LoadSav_QL){
			show[0] = 0;
		}else{
			int n = timer - show[0];	//区間タイム
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
	if(loadSav != LoadSav_NONE){
		return;
	}

	Sav* s = &sav[gameMode][indexes[gameMode]];

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		break;
	case STATE_PLAY:
		//通常時にLでQL
		if(L & pressedButtons){
			//セーブスロット選択
			if(R & heldButtons){
				//十字キーの入力に応じた8方向と無入力の9通りの値を得る
				int arrow = (heldButtons & 0xF0) >> 4;
				if(arrow > 8){arrow = (0b0111 << 9) >> arrow;}

				Sav* selSav = &sav[gameMode][arrow];
				//QSされてなければ何もしない
				if(selSav->sav_gameStates != 0){
					loadSav = LoadSav_QL;
					indexes[gameMode] = arrow;
					s = selSav;
				}
			}
			//ロードのモードがLOOP(左)かREDO(右)ならそのフロアに遷移した状態をQLする
			else if(loadOptions & (LoadOption_LOOP | LoadOption_REDO)){
				loadSav = LoadSav_QL;
				s = &tmp_sav;
			}
			//QSされていればQL
			else if(s->sav_gameStates != 0){
				loadSav = LoadSav_QL;
			}
		}
		break;
	default:
		//ロードのモードを左で設定したらそのフロアに遷移した状態へループさせる
		if(loadOptions & LoadOption_LOOP){
			loadSav = LoadSav_OVERRIDE;
			s = &tmp_sav;
		}
	}

	//ロード
	if(loadSav != LoadSav_NONE){
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

//真格闘王で下画面のボスの表示を「？？？」から切り替える処理を上書きして他のにも切り替えられるようにする
extern void free_resource(uint32_t handle);
extern uint32_t load_resource_A(uint32_t id);
extern uint32_t load_resource_B(uint32_t id);
extern void setup_resource(uint32_t a, uint32_t b, uint32_t c, uint32_t d);
void ArenaImageSwitcher(void){
	register int r4 asm("r4");
	uint32_t* resource_handle = (uint32_t*)(r4 + 0x40);
	uint8_t* load_state = (uint8_t*)(r4 + 0x44);
	uint8_t* image_index = (uint8_t*)(r4 + 0x48);

	// ロード処理を実行 (State 2 のフローを模倣: 解放 -> ロード)
	
	// 1. 古いリソースを解放
	if (*resource_handle != 0) {
		free_resource(*resource_handle);
		*resource_handle = 0;
	}

	// 2. モードに応じた最新のリソースをロード
	uint32_t image_id = *image_index;
	uint32_t sub_image_id = 0x0206e000 + image_id * 12;

	switch(gameMode){
	case THE_ARENA:	//格闘王の道
		sub_image_id += 0x140;
		image_id += 0x40;
		break;
	case HELPER_TO_HERO:	//ヘルパーマスターへの道
		sub_image_id += 0x098;
		image_id += 0x31;
		break;
	default:	//真・格闘王への道
		sub_image_id += 0x014;
		image_id += (image_id < 6) ? 0x53 : 0x57;
	}

	image_id += 0x12000;
	setup_resource(1, load_resource_A(image_id), 0x06218400, 0x2400);

	image_id -= 0x30;
	*resource_handle = load_resource_B(image_id);
	setup_resource(0x36, *resource_handle, 0x5c00, 0x1a0);

	setup_resource(1, load_resource_A(*(uint32_t*)sub_image_id), 0x06603800, 0x300);

	*load_state = 3;
}

//ミックスルーレット中に毎フレーム実行されるカウントアップ処理
void MixStep(void){
    mix_cnt++;
}