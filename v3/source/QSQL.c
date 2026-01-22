#include "symbols.h"

const uint32_t RoMK_positions[7] = {0x01D10956, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C};

void _start(void){
	Sav* s = &ctx.sav[gameMode][ctx.indexes[gameMode]];
	Sav* t = &ctx.tmp_sav;

	//マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる
	consumedItems[0] = 0;

	//座標を監視してフロア遷移時の情報を保持する
	if(getPos == 0 || getPos == POS_VALUE_IN_CORKBOARD){
		//遷移中の最初のフレーム(座標が0になったら)
		if(t->sav_pos != 0){
			t->sav_pos = 0;
			ctx.prevMusic = music;
			if(ctx.loadSav != LoadSav_NONE){
				playerInvincibility = s->sav_playerInvincibility;	//無敵キャンディ時間をロード
				if(ctx.loadSav == LoadSav_QL){
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
			ctx.loadSav = LoadSav_NONE;

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
			if(ctx.prevMusic != music){
				t->options |= SavOption_MUSIC_RESET;
			}
		}
	}

	//ほおばりのロード
	if(ctx.sav_inhale1 != 0){
		playerInhale1 = ctx.sav_inhale1;
		playerInhale2 = ctx.sav_inhale2;
		playerInvincibility = 1;
	}

	//ダイナのスイッチがステージに入ってるときはあってステージ選択画面ではおためし部屋があるようにする
	if(gameMode == DYNA_BLADE){
		db_switches = 0;
		if(gameState > 1){
			db_switches = 3;
		}
	}

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		//ポーズ時にY押しながら左右で格闘王のボスを切り替える
		if(Y & heldButtons){
			int last = 13;
			switch(gameMode){
			case THE_ARENA:
				last = 18;
				goto SWITCH_BOSS;
			case THE_TRUE_ARENA:
				last = 9;
				goto SWITCH_BOSS;
			case HELPER_TO_HERO:
			SWITCH_BOSS:
				int id = t->sav_arena_boss;

				if(LEFT & pressedButtons){
					id--;
					if(id < 0){
						id = last;
					}
				}else if(RIGHT & pressedButtons){
					id++;
					if(id > last){
						id = 0;
					}
				}else{break;}

				t->sav_arena_boss = id;
				arena_boss = id;
				arena_boss_img_changing = 2;
				break;
			}
		}
		//ポーズ時にXでジェットをセーブ
		if(X & pressedButtons){
			((uint8_t*)(&t->sav_playerStates))[3] = JET;
		}
		//ポーズ時にYで座標をセーブ
		if(Y & pressedButtons){
			t->sav_pos = getPos;
		}

		//十字キーの入力に応じた8方向と無入力の9通りの値を得る
		int arrow = (heldButtons & 0xF0) >> 4;
		if(arrow > 8){arrow = (0b0111 << 9) >> arrow;}

		//ポーズ時にLでQS
		if(L & pressedButtons){
			//セーブスロット選択
			ctx.indexes[gameMode] = arrow;
			s = &ctx.sav[gameMode][arrow];

			*s = *t;

			//ほおばりのセーブ
			ctx.sav_inhale1 = 0;
			if(playerForm == Form_INHALE){
				ctx.sav_inhale1 = playerInhale1;
				ctx.sav_inhale2 = playerInhale2;
			}
		}
		//ポーズ時にRでロードのモードを設定
		if(R & pressedButtons){
			ctx.loadOptions = heldButtons;
		}
		break;
	case STATE_PLAY:
		break;
	default:
		if(ctx.loadSav == LoadSav_QL){
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
