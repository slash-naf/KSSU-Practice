#include "symbols.h"

const int32_t RoMK_positions[7] = {0x01D10956, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C};

void _start(void){
	Sav* s = &ctx.sav[gameMode];

	//マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる
	consumedItems[0] = 0;

	//座標を監視してフロア遷移時の情報を保持する
	if(getPos == 0){

		//遷移中の最初のフレーム(座標が0になったら)
		if(ctx.tmp_pos != 0){
			ctx.tmp_pos = 0;
			//QLしたとき
			if(timer >= TIMER_RESET){
				timer = 0;

				//無敵キャンディ時間をロード
				playerInvincibility = s->sav_playerInvincibility;
			}else{
				//無敵キャンディ時間を保持
				ctx.tmp_playerInvincibility = playerInvincibility;
			}
		}
	}else{
		//遷移後の最初のフレーム(座標が0ではなくなったら)
		if(ctx.tmp_pos == 0){	
			ctx.tmp_pos = getPos;	//フロア遷移時の初期座標を保持
			ctx.tmp_playerMode = playerMode;	//フロア遷移時のワープスターに乗っているかやゴールゲーム中かなどの状態を保持
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
			//フロア
			s->sav_gameStates = gameStates ^ (STATE_FLOOR_LOAD ^ STATE_PAUSE);

			//銀河
			s->sav_mww_abilities = mww_abilities;
			s->sav_mww_selectedAbility = mww_selectedAbility;

			//格闘王系でのボス
			s->sav_arena_boss = arena_bosses[arena_idx];

			//能力
			s->sav_playerStates = playerStates;
			s->sav_playerRiding = playerRiding;
			
			s->sav_helperStates = helperStates;
			if(s->sav_helperStates == 0x08080101){s->sav_helperStates = 0x08080201;}	//通常状態からウィリーライダーをQLするときの対策
			s->sav_helperRode   = helperRode;

			//むてきキャンディ
			s->sav_playerInvincibility = ctx.tmp_playerInvincibility;

			//フロア遷移時の座標と状態
			s->sav_pos = ctx.tmp_pos;
			s->sav_playerMode = ctx.tmp_playerMode;

			int8_t* sav_gameStatesPtr = (int8_t*)(&(s->sav_gameStates));
			if( sav_gameStatesPtr[1] == 4 && sav_gameStatesPtr[3] == 0 ){	//メタ逆のステージ最初のフロアなら
				int32_t chapter = sav_gameStatesPtr[2];
				s->sav_pos = RoMK_positions[chapter];
			}else{
				switch(s->sav_gameStates){
				case 0x00040601:
					//大王5-1でQSすると次のフロアでソフトロックするのの修正
					s->sav_playerMode = 0;
					break;
				case 0x02080501:
					//マルク
					s->sav_pos = 0x02190042;
					s->sav_playerMode = 0x000000FF;
					break;
				}
			}

			//ほおばりのセーブ
			ctx.sav_inhale1 = 0;
			if(playerForm == Form_INHALE){
				ctx.sav_inhale1 = playerInhale1;
				ctx.sav_inhale2 = playerInhale2;
			}

			//曲の設定。Lなら通常、Rなら曲リセット
			s->options = heldButtons;
		}
		break;
	case STATE_PLAY:
		break;
	default:
		if(timer >= TIMER_RESET){	//QLしたとき
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
