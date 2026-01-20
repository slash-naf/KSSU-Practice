#include "symbols.h"

void _start(void){
	//既にQS情報をロード中なら
	if(ctx.loadSav != LoadSav_NONE){
		return;
	}

	Sav* s = &ctx.sav[gameMode][ctx.indexes[gameMode]];

	//場面別の処理
	switch(gameState){
	case STATE_PAUSE:
		break;
	case STATE_PLAY:
		//通常時にLでQL
		if(L & pressedButtons){
			//セーブスロット選択
			if(R & heldButtons){
				int selIdx = ARROW_VAL(heldButtons);
				Sav* selSav = &ctx.sav[gameMode][selIdx];
				//QSされてなければ何もしない
				if(selSav->sav_gameStates != 0){
					ctx.loadSav = LoadSav_QL;
					ctx.indexes[gameMode] = selIdx;
					s = selSav;
				}
			}
			//ロードのモードがLOOP(左)かREDO(右)ならそのフロアに遷移した状態をQLする
			else if(ctx.loadOptions & (LoadOption_LOOP | LoadOption_REDO)){
				ctx.loadSav = LoadSav_QL;
				s = &ctx.tmp_sav;
			}
			//QSされていればQL
			else if(s->sav_gameStates != 0){
				ctx.loadSav = LoadSav_QL;
			}
		}
		break;
	default:
		//ロードのモードを左で設定したらそのフロアに遷移した状態へループさせる
		if(ctx.loadOptions & LoadOption_LOOP){
			ctx.loadSav = LoadSav_OVERRIDE;
			s = &ctx.tmp_sav;
		}
	}

	//ロード
	if(ctx.loadSav != LoadSav_NONE){
		//HPと残機を最大に
		playerHP = playerMaxHP;
		helperHP = helperMaxHP;
		lives = 99;

		//曲のリセット
		if(s->options & SavOption_MUSIC_RESET){
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
