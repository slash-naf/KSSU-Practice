#include "symbols.h"

const int32_t RoMK_positions[7] = {0x01D10956, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C};

void _start(void){
	Sav* s = &ctx.sav[gameMode];
	Sav* t = &ctx.tmp_sav;

	//マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる
	consumedItems[0] = 0;

	//座標を監視してフロア遷移時の情報を保持する
	if((getPos == 0 || getPos == POS_VALUE_IN_CORKBOARD)){
		//遷移中の最初のフレーム(座標が0になったら)
		if(t->sav_pos != 0){
			t->sav_pos = 0;
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
			t->sav_arena_boss = arena_bosses[arena_idx];

			//オプションの設定
			t->options = 0;
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
		//ポーズ時にXでジェットをセーブ
		if(X & pressedButtons){
			((int8_t*)(&s->sav_playerStates))[3] = JET;
		}
		//ポーズ時にYで座標をセーブ
		if(Y & pressedButtons){
			s->sav_pos = getPos;
		}
		//ポーズ時にL/RでQS
		if((L | R) & pressedButtons){
			*s = *t;

			//ほおばりのセーブ
			ctx.sav_inhale1 = 0;
			if(playerForm == Form_INHALE){
				ctx.sav_inhale1 = playerInhale1;
				ctx.sav_inhale2 = playerInhale2;
			}

			//オプションの設定。Lなら通常、Rなら曲リセット。
			s->options = heldButtons;
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
