#ifndef SYMBOLS_H
#define SYMBOLS_H

#include <stdint.h>

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

enum Music{
	Music_MUTE = 0xFFFFFC19,
};

enum Ability{
	NORMAL  = 1,
	CUTTER  = 2,
	MIRROR  = 3,
	BEAM    = 4,
	FIGHTER = 5,
	SUPLEX  = 6,
	YOYO    = 7,
	WHEEL   = 8,
	BOMB    = 9,
	ICE     = 0xA,
	FIRE    = 0xB,
	PLASMA  = 0xC,
	NINJA   = 0xD,
	STONE   = 0xE,
	WING    = 0xF,
	JET     = 0x10,
	COPY    = 0x11,
	HAMMER  = 0x12,
	SWORD   = 0x13,
	PARASOL = 0x14,
	PAINT   = 0x15,
	MIKE    = 0x16,
	CRASH   = 0x17,
	COOK    = 0x18,
	SLEEP   = 0x19,
};

enum Form{
	Form_NORMAL = 1,
	Form_INHALE = 2,	//ほおばっている状態
	Form_HOVER  = 3,	//ホバーヒートや羽ばたきは1のまま
	Form_SWIM   = 4,
};

// 乱数・タイマー
#define seed                    (*(int16_t*)0x02041D3C)    // 乱数
#define seedTimer               (*(int16_t*)0x02041D3A)    // 乱数更新タイマー
#define timer                   (*(int32_t*)0x02041D60)    // タイマー

// オーディオ
#define music                   (*(int32_t*)0x020485C4)    // 曲。0xFFFFFC19がミュートだけどフロア遷移時に入れても曲が最初からになるだけ

// ゲーム状態
#define gameStates              (*(int32_t*)0x0205B244)
#define gameState               (*(int8_t*)0x0205B244)
#define gameMode                (*(int8_t*)0x0205B245)
#define stage                   (*(int8_t*)0x0205B246)
#define room                    (*(int8_t*)0x0205B247)
#define playerMode              (*(int32_t*)0x0205B248)    // ワープスターに乗っているかやゴールゲーム中かなど
#define setPos                  (*(int32_t*)0x0205B24C)    // フロア遷移時の初期座標の設定
#define consumedItems           ((int32_t*)0x0205B270)     // キャンディや1upなどの復活しないアイテムが取られるとこのアドレスから列挙されていく。0を入れれば復活

// スコア・進行
#define score                   (*(int32_t*)0x0205B3C0)    // スコア
#define lives                   (*(int8_t*)0x0205B3C4)     // 残機
#define mkuPt                   (*(int8_t*)0x0205B3C5)     // MKUのPt
#define db_switches             (*(int8_t*)0x0206BDEA)     // ダイナのスイッチを押したか。1ビット目が「おためし部屋１」、2ビット目が「おためし部屋２」。0を入れればスイッチ復活
#define gco_treasures           ((int32_t*)0x0206E100)     // 洞窟のお宝を取得済みか60ビットで記録される。0でリセット
#define gco_gold                (*(int32_t*)0x0206E108)    // 洞窟のゴールド
#define gco_bosses              (*(int8_t*)0x0206E10E)     // ボスを倒したか
#define gco_treasuresCnt        (*(int8_t*)0x0206E112)     // お宝所持数
#define arena_idx               (*(int8_t*)0x0206FC62)     // 格闘王系で何戦目か
#define arena_bosses            ((int8_t*)0x0206FC66)      // 格闘王系でのボスの並びが記憶されている配列

// 銀河
#define mww_abilities               (*(int32_t*)0x02070A40)    // 銀河の開放済み能力
#define mww_abilitiesByStage        ((int8_t*)0x02070A47)      // ステージごとの開放済み能力の数を記憶した長さ8の配列
#define mww_selectedAbility         (*(int8_t*)0x02070A5C)     // 銀河の選択能力。能力自体の値とは別
#define mww_changingSelectedAbility (*(int8_t*)0x02070A5E)     // 選択能力が遷移中なら1

// プレイヤー・ヘルパー
#define getPos                  (*(int32_t*)0x02076878)    // 1Pの座標
#define playerHP                (*(int8_t*)0x02076A94)     // 1PのHP
#define playerMaxHP             (*(int8_t*)0x02076A96)     // 1Pの最大HP
#define helperHP                (*(int8_t*)0x02076CD8)     // 2PのHP
#define helperMaxHP             (*(int8_t*)0x02076CDA)     // 2Pの最大HP
#define displayMode             (*(int32_t*)0x0209ECC4)    // スコア・ゴールドの所に何が表示されるか。0ならスコア・ゴールドを表示
#define playerStates            (*(int32_t*)0x020BA318)    // 1Pの能力・状態
#define playerAbility           (*(int8_t*)0x020BA31B)     // 1Pの能力
#define playerForm              (*(int8_t*)0x020BA31C)     // 1Pのホバリングかほおばってるかとか
#define playerRiding            (*(int8_t*)0x020BA31D)     // ウィリーライダーなら2
#define playerInhale1           (*(int32_t*)0x020BA5B0)
#define playerInhale2           (*(int32_t*)0x020BA5B4)
#define playerInvincibility     (*(int16_t*)0x020BA5CC)    // 1Pのむてきキャンディ/1Pと2pのメタクイックの残り時間
#define helperStates            (*(int32_t*)0x020BAB34)    // 2Pの能力・状態
#define helperRode              (*(int8_t*)0x020BAB39)     // ウィリーライダーなら2
#define helperInvincibility     (*(int16_t*)0x020BADE8)    // 2Pのむてきキャンディの残り時間

// その他
#define menuPageIdx             (*(int8_t*)0x021983CA)     // ポーズのメニューのページ番号
#define heldButtons             (*(int16_t*)0x02041E64)   // 押しているボタンに対応するビットが1になる
#define pressedButtons          (*(int16_t*)0x02041E68)   // 押したボタンに対応するビットが1になる
#define buttons                 (*(int16_t*)0x04000130)    // 押しているボタンに対応するビットが0になる

//自作
#define show                    ((int32_t*)0x02090DD8)     // 下画面に表示させる4桁の数値4つ
//大域変数
typedef struct {
	//QSQL.c
		//遷移時に保持するもの
			//座標
			int32_t tmp_pos;
			int32_t sav_pos;
			//ワープスターに乗っているかやゴールゲーム中かなど
			int32_t tmp_playerMode;
			int32_t sav_playerMode;
			//QSによる書き込みも遷移時に行うもの
				//無敵キャンディ
				int16_t tmp_playerInvincibility;
				int16_t sav_playerInvincibility;
				int16_t tmp_helperInvincibility;
				int16_t sav_helperInvincibility;
				//乱数
				int16_t tmp_seed;
				int16_t sav_seed;
				int16_t tmp_seedTimer;
				int16_t sav_seedTimer;

		//ほおばりのセーブ
		int32_t sav_inhale1;
		int32_t sav_inhale2;

		//ゲーム状態
		int32_t sav_gameStates;

		//プレイヤー・ヘルパー
		int32_t sav_playerStates;
		int8_t sav_playerRiding;
		int32_t sav_helperStates;
		int8_t sav_helperRode;

		//銀河
		int32_t sav_mww_abilities;
		int8_t sav_mww_selectedAbility;

		//格闘王
		int8_t sav_arena_boss;

		//QS時に押していたボタン
		int16_t options;

	//MixView
	uint8_t mix_cnt;	//MixView用のカウンター
} Data;
#define ctx (*(Data*)0x023FD000)
//定数
#define TIMER_RESET 0x40000000	//タイマーをリセットしたいとき入れることにした数値

#endif // SYMBOLS_H
