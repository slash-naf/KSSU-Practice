#include "symbols.h"
#include <stdint.h>

// ============================================================================
// 定数・マクロ定義
// ============================================================================

// ゴースト記録用バッファ (二重バッファ: Ping-Pong Buffer)
#define GHOST_BUF_A ((uint32_t*)0x02F10000)
#define GHOST_BUF_B ((uint32_t*)0x02F20000)
#define MAX_GHOST_FRAMES 16000 // 64KBバッファ(16384ワード)に収まる最大フレーム数 (約4.4分)
#define MAX_FLOORS       32    // 1走あたりに記録可能な最大フロア数

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
#define OBJ_MODE_NORMAL 0x0000 // Attr0: 通常スプライトモード (不透明)
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

// ============================================================================
// 走行データ構造体 (二重バッファ管理用)
// ============================================================================

typedef struct {
	uint32_t* buf;                     // 座標データバッファへのポインタ
	uint32_t floor_starts[MAX_FLOORS]; // 各フロアの開始フレーム番号
	uint32_t floor_count;              // 記録されたフロア数
	uint32_t total_frames;             // 総記録フレーム数
} GhostRun;

// ============================================================================
// 状態変数
// ============================================================================

// 二重バッファ (Ping-Pong Buffer): ポインタを入れ替えるだけで全走行データが一瞬でスワップ可能
static GhostRun run_a = { GHOST_BUF_A, {0}, 1, 0 };
static GhostRun run_b = { GHOST_BUF_B, {0}, 1, 0 };
static GhostRun* rec_run = &run_a;
static GhostRun* play_run = &run_b;

// 実行状態 (記録と再生で独立管理)
static uint32_t rec_frame = 0;
static uint32_t play_frame = 0;
static uint32_t play_floor_idx = 0;
static uint8_t is_recording = 1;

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
		(uint16_t)((screen_y & 0x00FF) | OBJ_MODE_NORMAL),
		(uint16_t)((screen_x & 0x01FF) | OBJ_SIZE_16X16),
		(uint16_t)(STAR_TILE_INDEX | (STAR_PAL_INDEX << 12) | OBJ_PRIORITY_2),
		0
	};
	HW_OAM[GHOST_OAM_INDEX]     = e;
	SHADOW_OAM[GHOST_OAM_INDEX] = e;
}

// ============================================================================
// 公開インターフェース
// ============================================================================

// リセットおよびフロア開始同期処理
// is_ql != 0: QLによるリセット (直前走りを確定・スワップしてループ再生・0フレームから新規記録開始)
// is_ql == 0: 通常フロア遷移 (新フロア開始点へ再生フレームを同期し、新フロアの記録開始点をマーク)
void ResetGhost(int is_ql){
	if(is_ql){
		// 1. 直前の走りの記録フレーム数を確定
		if(is_recording && rec_frame > 0){
			rec_run->total_frames = (rec_frame <= MAX_GHOST_FRAMES) ? rec_frame : MAX_GHOST_FRAMES;
		}

		// 2. 走行データをスワップ (直前の走りを次回再生用に即時切り替え、配列コピー不要)
		GhostRun* tmp = rec_run;
		rec_run = play_run;
		play_run = tmp;

		// 3. 次回記録用データの初期化
		rec_run->floor_count = 1;
		rec_run->floor_starts[0] = 0; // 第1フロアは0フレームから
		rec_run->total_frames = 0;

		// 4. カウンタおよびフロアインデックスを初期化して新規記録を開始
		rec_frame = 0;
		play_frame = 0;
		play_floor_idx = 0;
		is_recording = 1;
	}else{
		// 通常フロア遷移時: 記録側に新フロア開始フレームを登録
		if(is_recording && rec_run->floor_count < MAX_FLOORS){
			rec_run->floor_starts[rec_run->floor_count++] = rec_frame;
		}

		// 再生側: 次フロアの開始フレームへ同期 (ジャンプ)
		play_floor_idx++;
		if(play_floor_idx < play_run->floor_count){
			play_frame = play_run->floor_starts[play_floor_idx];
		}else{
			// 過去の走りがこのフロアに達していなければ再生終了
			play_frame = play_run->total_frames;
		}
	}

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
	if(is_recording && rec_frame < MAX_GHOST_FRAMES){
		rec_run->buf[rec_frame++] = cur_pos;
	}

	// --- 2. 再生・描画処理 ---
	// 現在フロアの終端フレーム (次フロアの開始フレーム、または総フレーム数)
	uint32_t play_floor_end = play_run->total_frames;
	if(play_floor_idx + 1 < play_run->floor_count){
		play_floor_end = play_run->floor_starts[play_floor_idx + 1];
	}

	// 現在フロアの範囲内のみ再生 (ゴーストが先にフロアを抜けた場合は待機)
	if(play_floor_idx < play_run->floor_count && play_frame < play_floor_end){
		uint32_t ghost_pos = play_run->buf[play_frame++];
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
		// 再生データ終端またはフロア終端後は非表示
		HideGhost();
	}
}
