#include "symbols.h"
#include <stdint.h>

// ============================================================================
// 定数・マクロ定義
// ============================================================================

// ゴースト記録用バッファ (二重バッファ: Ping-Pong Buffer)
// バッファ先頭(index 0)に記録フレーム数、以降各フレームの座標(X[16bit] | Y[16bit])を格納
#define GHOST_BUF_A ((uint32_t*)0x02F10000)
#define GHOST_BUF_B ((uint32_t*)0x02F20000)
#define MAX_GHOST_FRAMES 16000 // 64KBバッファ(16384ワード)に収まる最大フレーム数 (約4.4分)

// DS 画面解像度およびカリングマージン
#define SCREEN_WIDTH   256
#define SCREEN_HEIGHT  192
#define CULL_MARGIN    32

// OAM スロット設定
#define GHOST_OAM_INDEX 127 // ゲーム側スプライトとの衝突を避けるため末尾スロットを使用

// ゲーム内常駐の公式「星（スター）」アイコン設定 (16x16スプライト)
// DISPCNTの1D Boundary 256バイトモードにおける正規タイル番号 (Tile 222: 222*256 = 56,832 = 0xDE00)
#define STAR_TILE_INDEX 222
#define STAR_PAL_INDEX  7   // 公式星アイコン用パレット (黄色)

// OAM アトリビュートビット定義
#define OBJ_DISABLE     0x0200 // Attr0: 非表示フラグ
#define GHOST_OBJ_MODE  0x0400 // Attr0: 半透明モード (0x0400: 半透明, 0x0000: 不透明)
#define OBJ_SIZE_16X16  0x4000 // Attr1: 16x16ドット (Shape: Square, Size: 1)
#define OBJ_PRIORITY_2  0x0800 // Attr2: 表示優先度2 (BG手前、通常スプライト優先度)

// 座標取得マクロ (32bitパック値から 16bit 符号付き座標を展開)
#define POS_X(p) ((int16_t)((p) & 0xFFFF))
#define POS_Y(p) ((int16_t)((p) >> 16))

// DS OAM構造体 (各8バイト)
typedef struct {
	uint16_t attr0;
	uint16_t attr1;
	uint16_t attr2;
	uint16_t attr3;
} OAMEntry;

// ハードウェアOAM (Main Engine: 0x07000000)
#define HW_OAM ((volatile OAMEntry*)0x07000000)

// メインRAM上のShadow OAMバッファ (0x0203F898)
#define SHADOW_OAM ((volatile OAMEntry*)0x0203F898)

// GPU ブレンドレジスタ (Main Engine 2D)
// ゲーム本体のVBlankハンドラがShadowバッファからハードウェアI/Oへ一括転送しているため両方に定義
#define REG_BLDCNT       (*(volatile uint16_t*)0x04000050)
#define REG_BLDALPHA      (*(volatile uint16_t*)0x04000052)

// ゲーム本体のVBlank転送用Shadowレジスタ (ベースアドレス: 0x02041D80)
// VBlank転送処理(0x02001994-0x020019AC)の解析結果:
//   0x02041D80 + 0x2A = 0x02041DAA : Shadow BLDCNT (16bit) -> REG_BLDCNT
//   0x02041D80 + 0x2C = 0x02041DAC : Shadow EVA (下位8bit)
//   0x02041D80 + 0x2E = 0x02041DAE : Shadow EVB (下位8bit) -> (EVA | (EVB << 8)) -> REG_BLDALPHA
#define SHADOW_BLDCNT    (*(volatile uint16_t*)0x02041DAA)
#define SHADOW_BLD_EVA   (*(volatile uint16_t*)0x02041DAC)
#define SHADOW_BLD_EVB   (*(volatile uint16_t*)0x02041DAE)

// ブレンド設定 (50%半透明: EVA=8, EVB=8、全レイヤーを第2ターゲットに指定)
#define BLD_2ND_ALL   0x3F00           // BG0〜BG3, OBJ, Backdrop をブレンド対象に指定
#define BLD_ALPHA_50  ((8 << 8) | 8)   // 第1ターゲット 8/16(50%), 第2ターゲット 8/16(50%)

// ============================================================================
// 状態変数
// ============================================================================

// バッファ管理ポインタ
static uint32_t* rec_buf = GHOST_BUF_A;
static uint32_t* play_buf = GHOST_BUF_B;

// 実行状態
static uint32_t current_frame = 0;
static uint32_t play_total_frames = 0;
static uint8_t is_recording = 0;

// ============================================================================
// 内部関数 (ヘルパー)
// ============================================================================

// ゴーストスプライトを非表示にする (HW_OAM / SHADOW_OAM 両対応)
static inline void HideGhost(void){
	HW_OAM[GHOST_OAM_INDEX].attr0     = OBJ_DISABLE;
	SHADOW_OAM[GHOST_OAM_INDEX].attr0 = OBJ_DISABLE;
}

// ゴーストスプライトをOAMに設定・表示する (HW_OAM / SHADOW_OAM 両対応)
static inline void ShowGhost(int screen_x, int screen_y){
	OAMEntry e = {
		(uint16_t)((screen_y & 0x00FF) | GHOST_OBJ_MODE),
		(uint16_t)((screen_x & 0x01FF) | OBJ_SIZE_16X16),
		(uint16_t)(STAR_TILE_INDEX | (STAR_PAL_INDEX << 12) | OBJ_PRIORITY_2),
		0
	};
	HW_OAM[GHOST_OAM_INDEX]     = e;
	SHADOW_OAM[GHOST_OAM_INDEX] = e;

	// GPU半透明ブレンド設定 (星50% + 背景50%)
	// 実機環境ではVBlank時にゲーム側がShadowレジスタから上書き転送するため両方に設定
	REG_BLDCNT      |= BLD_2ND_ALL;
	REG_BLDALPHA     = BLD_ALPHA_50;
	SHADOW_BLDCNT   |= BLD_2ND_ALL;
	SHADOW_BLD_EVA   = 8;
	SHADOW_BLD_EVB   = 8;
}

// ============================================================================
// 公開インターフェース
// ============================================================================

// フロア開始時またはQL時に呼び出されるリセット処理
// is_ql != 0: QLによる再スタート (直前走りをスワップしてゴースト自動ループ再生)
// is_ql == 0: 通常遷移による新フロア (再生データクリアで新規記録開始)
void ResetGhost(int is_ql){
	if(is_ql){
		// 直前の走りの記録フレーム数をバッファ先頭に保存
		if(is_recording && current_frame > 0){
			rec_buf[0] = current_frame;
		}

		// 二重バッファをスワップ (直前の走りを次回再生用に切り替え)
		uint32_t* tmp = rec_buf;
		rec_buf = play_buf;
		play_buf = tmp;

		// 再生バッファの記録フレーム数を取得 (メモリ未初期化等の不正値ガード)
		uint32_t count = play_buf[0];
		play_total_frames = (count <= MAX_GHOST_FRAMES) ? count : 0;
	}else{
		// 通常遷移時は過去のゴーストをクリア
		play_total_frames = 0;
	}

	// カウンタを初期化して新規記録を開始
	current_frame = 0;
	is_recording = 1;

	// スプライトを非表示に初期化
	HideGhost();
}

// 毎フレーム呼び出される記録・再生・描画処理
void UpdateGhost(void){
	// アクションパート中以外は何もしない
	if(gameState != STATE_PLAY){
		return;
	}

	// プレイヤーの現在座標を取得 (無効値またはコルクボード時は非表示)
	uint32_t cur_pos = getPos;
	if(cur_pos == 0 || cur_pos == POS_IN_CORKBOARD){
		HideGhost();
		return;
	}

	// --- 1. 記録処理 ---
	if(is_recording && current_frame < MAX_GHOST_FRAMES){
		rec_buf[1 + current_frame] = cur_pos;
	}

	// --- 2. 再生・描画処理 ---
	if(current_frame < play_total_frames){
		uint32_t ghost_pos = play_buf[1 + current_frame];
		uint32_t cam = cameraPos;

		// 画面内描画座標 (ワールド座標 - カメラ座標、16x16星の中心合わせ -8ドット)
		// 現在のカービィのスプライトに依存せず、カメラ基準で直接描画するため姿勢によるブレがゼロ
		int g_screen_x = POS_X(ghost_pos) - POS_X(cam) - 8;
		int g_screen_y = POS_Y(ghost_pos) - POS_Y(cam) - 8;

		// 画面外カリング (DS画面 256x192, マージン +-32ドット)
		if(g_screen_x < -CULL_MARGIN || g_screen_x > SCREEN_WIDTH || g_screen_y < -CULL_MARGIN || g_screen_y > SCREEN_HEIGHT){
			HideGhost();
		}else{
			ShowGhost(g_screen_x, g_screen_y);
		}
	}else{
		// 再生データ終端後は非表示
		HideGhost();
	}

	current_frame++;
}
