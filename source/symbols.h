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
	SWORD  = 0x12,
	HAMMER   = 0x13,
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
#define seed                    (*(uint16_t*)0x02041D3C)    // 乱数
#define seedTimer               (*(uint16_t*)0x02041D3A)    // 乱数更新タイマー
#define timer                   (*(uint32_t*)0x02041D60)    // タイマー

// オーディオ
#define music                   (*(uint32_t*)0x020485C4)    // 曲。0xFFFFFC19がミュートだけどフロア遷移時に入れても曲が最初からになるだけ

// ゲーム状態
#define gameStates              (*(uint32_t*)0x0205B244)
#define gameState               (*(uint8_t*)0x0205B244)
#define gameMode                (*(uint8_t*)0x0205B245)
#define stage                   (*(uint8_t*)0x0205B246)
#define room                    (*(uint8_t*)0x0205B247)
#define playerMode              (*(uint32_t*)0x0205B248)    // ワープスターに乗っているかやゴールゲーム中かなど
#define setPos                  (*(uint32_t*)0x0205B24C)    // フロア遷移時の初期座標の設定
#define consumedItems           ((uint32_t*)0x0205B270)     // キャンディや1upなどの復活しないアイテムが取られるとこのアドレスから列挙されていく。0を入れれば復活

// スコア・進行
#define score                   (*(uint32_t*)0x0205B3C0)    // スコア
#define lives                   (*(uint8_t*)0x0205B3C4)     // 残機
#define mkuPt                   (*(uint8_t*)0x0205B3C5)     // MKUのPt
#define db_switches             (*(uint8_t*)0x0206BDEA)     // ダイナのスイッチを押したか。1ビット目が「おためし部屋１」、2ビット目が「おためし部屋２」。0を入れればスイッチ復活
#define gco_treasures           ((uint32_t*)0x0206E100)     // 洞窟のお宝を取得済みか60ビットで記録される。0でリセット
#define gco_gold                (*(uint32_t*)0x0206E108)    // 洞窟のゴールド
#define gco_bosses              (*(uint8_t*)0x0206E10E)     // ボスを倒したか
#define gco_treasuresCnt        (*(uint8_t*)0x0206E112)     // お宝所持数
#define arena_idx               (*(uint8_t*)0x0206FC62)     // 格闘王系で何戦目か
#define arena_bosses            ((uint8_t*)0x0206FC66)      // 格闘王系でのボスの並びが記憶されている配列
#define arena_boss              (*(uint8_t*)0x02049B48)     // 格闘王系での現在のボス
#define arena_boss_img_changing (*(uint8_t*)0x02049B44)     // 格闘王系での下画面のボスの画像を変化させるための情報。通常時は0、下画面ホワイトアウトで1→3、"???"からの変化は2→3。ImageSwitcher.cを"???"からの変化の処理に上書きすることで、2にすると現在のarena_bossの画像に切り替わる

// 銀河
#define mww_abilities               (*(uint32_t*)0x02070A40)    // 銀河の開放済み能力
#define mww_abilitiesByStage        ((uint8_t*)0x02070A47)      // ステージごとの開放済み能力の数を記憶した長さ8の配列
#define mww_selectedAbility         (*(uint8_t*)0x02070A5C)     // 銀河の選択能力。能力自体の値とは別
#define mww_changingSelectedAbility (*(uint8_t*)0x02070A5E)     // 選択能力が遷移中なら1

// プレイヤー・ヘルパー
#define getPos                  (*(uint32_t*)0x02076878)    // 1Pの座標
#define playerHP                (*(uint8_t*)0x02076A94)     // 1PのHP
#define playerMaxHP             (*(uint8_t*)0x02076A96)     // 1Pの最大HP
#define helperHP                (*(uint8_t*)0x02076CD8)     // 2PのHP
#define helperMaxHP             (*(uint8_t*)0x02076CDA)     // 2Pの最大HP
#define displayMode             (*(uint32_t*)0x0209ECC4)    // スコア・ゴールドの所に何が表示されるか。0ならスコア・ゴールドを表示
#define playerStates            (*(uint32_t*)0x020BA318)    // 1Pの能力・状態
#define playerAbility           (*(uint8_t*)0x020BA31B)     // 1Pの能力
#define playerForm              (*(uint8_t*)0x020BA31C)     // 1Pのホバリングかほおばってるかとか
#define playerRiding            (*(uint8_t*)0x020BA31D)     // ウィリーライダーなら2
#define playerInhale1           (*(uint32_t*)0x020BA5B0)
#define playerInhale2           (*(uint32_t*)0x020BA5B4)
#define playerInvincibility     (*(uint16_t*)0x020BA5CC)    // 1Pのむてきキャンディ/1Pと2pのメタクイックの残り時間
#define helperStates            (*(uint32_t*)0x020BAB34)    // 2Pの能力・状態
#define helperRode              (*(uint8_t*)0x020BAB39)     // ウィリーライダーなら2
#define helperInvincibility     (*(uint16_t*)0x020BADE8)    // 2Pのむてきキャンディの残り時間

// その他
#define menuPageIdx             (*(uint8_t*)0x021983CA)     // ポーズのメニューのページ番号
#define heldButtons             (*(uint16_t*)0x02041E64)   // 押しているボタンに対応するビットが1になる
#define pressedButtons          (*(uint16_t*)0x02041E68)   // 押したボタンに対応するビットが1になる
#define buttons                 (*(uint16_t*)0x04000130)    // 押しているボタンに対応するビットが0になる

//自作
#define show                    ((uint32_t*)0x02090DD8)     // 下画面に表示させる4桁の数値4つ
typedef struct {//QSQLでロードする情報
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

	//何か
	uint16_t options;
} Sav;
//大域変数
typedef struct {
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
	uint8_t mix_cnt;

	//ゲームモードとセーブスロットごとのQSQLでロードする情報
	uint8_t indexes[12];
	Sav sav[12][9];
} Data;
#define ctx (*(Data*)0x022E1000)

//定数
enum SavOption{
	SavOption_MUSIC_RESET = 0x1,
};
enum LoadOption{
	LoadOption_LOOP = LEFT,
	LoadOption_REDO = RIGHT,
};
enum LoadSav{
	LoadSav_NONE = 0,
	LoadSav_OVERRIDE = 1,
	LoadSav_QL = 2,
};
#define POS_VALUE_IN_CORKBOARD 0x020728CC

#endif // SYMBOLS_H
