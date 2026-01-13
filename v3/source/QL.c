#include "symbols.h"

void _start(void){
	Sav* s = &ctx.sav[gameMode];

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		break;
	case STATE_PLAY:
		//通常時にLでQL
		if(L & pressedButtons){
			//タイマーリセット
			timer = TIMER_RESET;	//QLの検知のため

			if(s->sav_gameStates == 0){	//QSしてなければ
				s = &ctx.tmp_sav;
			}
		}

		//ロード
		if(timer >= LOAD_INVINCIBILITY){
			//HPと残機を最大に
			playerHP = playerMaxHP;
			helperHP = helperMaxHP;
			lives = 99;

			//曲のリセット
			if(s->options & R){
				music = Music_MUTE;
			}

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
				//R押しながらLで次のボスへ
				if(R & heldButtons){
					gameState = STATE_ARENA_PROCEED;
				}else{
					arena_idx = 0;
					arena_bosses[0] = s->sav_arena_boss;
					gameState = STATE_ARENA_MATCH;
				}
				break;
			default:
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
	}
}
