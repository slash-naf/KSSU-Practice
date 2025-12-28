#include "symbols.h"

const int32_t RoMK_positions[7] = {0x01D10956, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C};

void _start(void){
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
				playerInvincibility = ctx.sav_playerInvincibility;
				helperInvincibility = ctx.sav_helperInvincibility;

				//QS時に上を押していたら乱数のロード
				if(ctx.options & UP){
					seed = ctx.sav_seed;
					seedTimer = ctx.sav_seedTimer;
				}
			}else{
				//無敵キャンディ時間を保持
				ctx.tmp_playerInvincibility = playerInvincibility;
				ctx.tmp_helperInvincibility = helperInvincibility;

				//QS時に上を押していたら乱数の保持
				ctx.tmp_seed = seed;
				ctx.tmp_seedTimer = seedTimer;
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
			((int8_t*)(&ctx.sav_playerStates))[3] = JET;
		}
		//ポーズ時にYで座標をセーブ
		if(Y & pressedButtons){
			ctx.sav_pos = getPos;
		}
		//ポーズ時にL/RでQS
		if((L | R) & pressedButtons){
			//フロア
			ctx.sav_gameStates = gameStates ^ (STATE_FLOOR_LOAD ^ STATE_PAUSE);

			//銀河
			ctx.sav_mww_abilities = mww_abilities;
			ctx.sav_mww_selectedAbility = mww_selectedAbility;

			//格闘王系でのボス
			ctx.sav_arena_boss = arena_bosses[arena_idx];

			//能力
			ctx.sav_playerStates = playerStates;
			ctx.sav_playerRiding = playerRiding;
			
			ctx.sav_helperStates = helperStates;
			if(ctx.sav_helperStates == 0x08080101){ctx.sav_helperStates = 0x08080201;}	//通常状態からウィリーライダーをQLするときの対策
			ctx.sav_helperRode   = helperRode;

			//乱数
			ctx.sav_seed = ctx.tmp_seed;
			ctx.sav_seedTimer = ctx.tmp_seedTimer;

			//むてきキャンディ
			ctx.sav_playerInvincibility = ctx.tmp_playerInvincibility;
			ctx.sav_helperInvincibility = ctx.tmp_helperInvincibility;

			//フロア遷移時の座標
			int8_t* sav_gameStatesPtr = (int8_t*)(&(ctx.sav_gameStates));
			if( sav_gameStatesPtr[1] == 4 && sav_gameStatesPtr[3] == 0 ){	//メタ逆のステージ最初のフロアなら
				int32_t chapter = sav_gameStatesPtr[2];
				ctx.sav_pos = RoMK_positions[chapter];
			}else{
				ctx.sav_pos = ctx.tmp_pos;
			}

			//フロア遷移時の状態
			if(ctx.sav_gameStates == 0x00040601){
				//大王5-1でQSすると次のフロアでソフトロックするのの修正
				ctx.sav_playerMode = 0;
			}else{
				ctx.sav_playerMode = ctx.tmp_playerMode;
			}

			//ほおばりのセーブ
			ctx.sav_inhale1 = 0;
			if(playerForm == Form_INHALE){
				ctx.sav_inhale1 = playerInhale1;
				ctx.sav_inhale2 = playerInhale2;
			}

			//曲の設定。Lなら通常、Rなら曲リセット
			ctx.options = heldButtons;
		}
		break;
	case STATE_PLAY:
		//通常時にLでQL
		if( (L & pressedButtons) && ctx.sav_gameStates != 0 && gameMode == ((int8_t*)(&(ctx.sav_gameStates)))[1] ){
			//タイマーリセット
			timer = TIMER_RESET;	//QLの検知のため

			//HPと残機を最大に
			playerHP = playerMaxHP;
			helperHP = helperMaxHP;
			lives = 99;

			//曲のリセット
			if(ctx.options & R){
				music = Music_MUTE;
			}

			//ゲームモード別の処理
			if(gameMode != HELPER_TO_HERO){
				//能力のロード
				playerStates = ctx.sav_playerStates;
				playerRiding = ctx.sav_playerRiding;
				helperStates = ctx.sav_helperStates;
				helperRode   = ctx.sav_helperRode;
			}
			switch(gameMode){
			case THE_ARENA:
			case THE_TRUE_ARENA:
			case HELPER_TO_HERO:
				//格闘王系のモードでのボスのロード
				//R押しながらLで次のボスへ
				if(R & heldButtons){
					gameState = STATE_ARENA_PROCEED;
				}else{
					arena_idx = 0;
					arena_bosses[0] = ctx.sav_arena_boss;
					gameState = STATE_ARENA_MATCH;
				}
				break;
			default:
				//フロアと座標と状態
				gameStates = ctx.sav_gameStates;
				setPos = ctx.sav_pos;
				playerMode = ctx.sav_playerMode;
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
					mww_abilities = ctx.sav_mww_abilities;
					mww_selectedAbility = ctx.sav_mww_selectedAbility;
					mww_changingSelectedAbility = 1;
					//増えすぎるとこれを表示するオレンジ色の丸のところのグラフィックがなんかバグるから一応0にしておく
					for(int i=0; i < 8; i++){
						mww_abilitiesByStage[i] = 0;
					}
					break;
				case MKU:
					//メタナイトでゴーのPtを最大に
					mkuPt = 50;
					break;
				}
			}
		}
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
