#include "symbols.h"
#include <stdint.h>

// ============================================================================
// 定数・マクロ定義
// ============================================================================

#define MAX_GHOST_FRAMES 7200  // 最大フレーム数 (2分 = 120秒, 21バッファで計604.8KB)
#define MAX_FLOORS       32    // 1走あたりに記録可能な最大フロア数
#define MAX_SAVED_RUNS   20    // 開始地点ごとに保存可能な最大走数 (20地点)

// 記録用および保存用の実体バッファ配列 (rec用 1個 + 保存用 20個 = 計21個, BSSに配置)
static uint32_t ghost_buffers[1 + MAX_SAVED_RUNS][MAX_GHOST_FRAMES];
#define GHOST_BUF(i) (ghost_buffers[i])

// リセットおよびフロア開始同期の動作モード
enum GhostResetMode {
	GHOST_SYNC_FLOOR   = 0, // 通常フロア遷移: 新フロア開始点へ再生フレームを同期
	GHOST_RESET_RETRY  = 1, // 通常QL: 走りを更新せず維持し、該当開始地点の走りをリトライ
	GHOST_RESET_UPDATE = 2, // SELECT+L によるQL: 直前の走りを該当開始地点スロットに保存・更新
};

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
#define STAR_HALF_SIZE  8   // 16x16星アイコンの中心合わせオフセット

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
// 走行データ構造体
// ============================================================================

typedef struct {
	uint32_t* buf;                     // 座標データバッファへのポインタ
	uint32_t floor_starts[MAX_FLOORS]; // 各フロアの開始フレーム番号
	uint32_t floor_count;              // 記録されたフロア数
	uint32_t total_frames;             // 総記録フレーム数 (0なら未使用スロット)
	uint32_t start_game_states;        // 記録開始時の sav_gameStates
	uint32_t start_pos;                // 記録開始時の sav_pos
	uint32_t last_used;                // LRU用アクセス順序カウンタ
} GhostRun;

// ============================================================================
// 状態変数
// ============================================================================

// 記録用ワークデータ (インデックス 0 のバッファを使用)
static GhostRun rec_run_data = { GHOST_BUF(0), {0}, 1, 0, 0, 0, 0 };
static GhostRun* rec_run = &rec_run_data;

// 開始地点ごとに保存される走行データプール (インデックス 1〜20 のバッファを使用)
static GhostRun saved_runs[MAX_SAVED_RUNS] = {
	{ GHOST_BUF(1),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(2),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(3),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(4),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(5),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(6),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(7),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(8),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(9),  {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(10), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(11), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(12), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(13), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(14), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(15), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(16), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(17), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(18), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(19), {0}, 0, 0, 0, 0, 0 },
	{ GHOST_BUF(20), {0}, 0, 0, 0, 0, 0 },
};

// 再生中の走行データへのポインタ (NULLなら再生対象なし)
static GhostRun* play_run = 0;

// 実行状態
static uint32_t rec_frame = 0;
static uint32_t play_frame = 0;
static uint32_t play_floor_idx = 0;
static uint8_t is_rec_valid = 0;  // QL済みでゴースト記録が有効か (未QL時はゴースト機能無効)
static uint8_t is_play_valid = 0; // 現在のセーブ地点と一致しゴースト再生可能か (1: 再生, 0: 非表示)
static uint32_t access_clock = 0; // LRU置き換え用タイムスタンプ

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

// 画面内描画範囲内かどうかを判定 (DS画面 256x192, マージン +-32ドット)
static inline int IsOnScreen(int x, int y){
	return (x >= -CULL_MARGIN && x <= SCREEN_WIDTH && y >= -CULL_MARGIN && y <= SCREEN_HEIGHT);
}

// 走行データの記録メタデータを初期化する
static inline void InitGhostRun(GhostRun* run, uint32_t game_states, uint32_t pos){
	run->start_game_states = game_states;
	run->start_pos = pos;
	run->floor_count = 1;
	run->floor_starts[0] = 0; // 第1フロアは0フレームから
	run->total_frames = 0;
}

// 開始地点に一致する保存済み走行データを検索する (見つからなければ NULL)
static GhostRun* FindSavedRun(uint32_t game_states, uint32_t pos){
	for(int i = 0; i < MAX_SAVED_RUNS; i++){
		if(saved_runs[i].total_frames > 0 &&
		   saved_runs[i].start_game_states == game_states &&
		   saved_runs[i].start_pos == pos){
			return &saved_runs[i];
		}
	}
	return 0;
}

// 保存先スロットを取得する (既存一致 -> 空きスロット -> 最古LRUスロット)
static GhostRun* AllocateSaveSlot(uint32_t game_states, uint32_t pos){
	GhostRun* oldest = &saved_runs[0];
	GhostRun* empty = 0;

	for(int i = 0; i < MAX_SAVED_RUNS; i++){
		GhostRun* r = &saved_runs[i];

		// 1. 同一開始地点の既存スロットがあれば最優先で再利用
		if(r->total_frames > 0 && r->start_game_states == game_states && r->start_pos == pos){
			return r;
		}
		// 2. 空きスロットがあれば保持 (最初に見つかったスロット)
		if(r->total_frames == 0 && !empty){
			empty = r;
		}
		// 3. 全スロット使用中の場合に備えて最古スロットを追跡
		if(r->last_used < oldest->last_used){
			oldest = r;
		}
	}

	return empty ? empty : oldest;
}

// 走行メタデータをターゲットスロットにコピーする (libcのmemcpy非依存)
static inline void CopyRunMetadata(GhostRun* dst, const GhostRun* src, uint32_t total_frames){
	dst->start_game_states = src->start_game_states;
	dst->start_pos         = src->start_pos;
	dst->floor_count       = src->floor_count;
	dst->total_frames      = total_frames;
	for(uint32_t i = 0; i < src->floor_count; i++){
		dst->floor_starts[i] = src->floor_starts[i];
	}
	dst->last_used = ++access_clock;
}

// 直前の記録走行を開始地点スロットに保存・更新する (バッファポインタをスワップして O(1) で即時完了)
static void SaveGhostRun(void){
	GhostRun* target = AllocateSaveSlot(rec_run->start_game_states, rec_run->start_pos);
	uint32_t frames  = (rec_frame <= MAX_GHOST_FRAMES) ? rec_frame : MAX_GHOST_FRAMES;

	// メタデータをコピーし、バッファポインタをスワップ (64KBの配列コピーなし)
	CopyRunMetadata(target, rec_run, frames);

	uint32_t* tmp_buf = target->buf;
	target->buf       = rec_run->buf;
	rec_run->buf      = tmp_buf;
}

// 通常フロア遷移時の同期処理
static inline void SyncFloor(void){
	// 未QL時、またはまだ記録フレームがない場合は何もしない (初回到達時の誤登録防止)
	if(!is_rec_valid || rec_frame == 0){
		return;
	}

	// 記録側: 新フロア開始フレームを登録
	if(rec_run->floor_count < MAX_FLOORS){
		rec_run->floor_starts[rec_run->floor_count++] = rec_frame;
	}

	// 再生側: 次フロアの開始フレームへ同期 (ジャンプ)
	if(play_run && play_floor_idx < play_run->floor_count){
		play_floor_idx++;
		play_frame = (play_floor_idx < play_run->floor_count)
			? play_run->floor_starts[play_floor_idx]
			: play_run->total_frames;
	}
}

// ============================================================================
// 公開インターフェース
// ============================================================================

// リセットおよびフロア開始同期処理
// mode: enum GhostResetMode (0: フロア同期, 1: 走りを維持してリトライ, 2: 走りを更新してリスタート)
// game_states: ロード先の sav_gameStates (QL時のみ有効)
// pos: ロード先の sav_pos (QL時のみ有効)
void ResetGhost(int mode, uint32_t game_states, uint32_t pos){
	HideGhost();

	// --- 1. 通常フロア遷移時: 新フロア開始点へ再生同期 ---
	if(mode == GHOST_SYNC_FLOOR){
		SyncFloor();
		return;
	}

	// --- 2. QL時: SELECT+L かつ記録有効時なら直前の走りを該当開始地点のスロットに保存 ---
	if(mode == GHOST_RESET_UPDATE && is_rec_valid && rec_frame > 0){
		SaveGhostRun();
	}

	// --- 3. ロード先に対応する保存済みゴーストを検索 ---
	play_run = FindSavedRun(game_states, pos);
	is_play_valid = (play_run != 0);
	if(play_run){
		play_run->last_used = ++access_clock;
	}

	// --- 4. QL共通: 次回記録用データの初期化および再生カウンタのリセット ---
	InitGhostRun(rec_run, game_states, pos);
	rec_frame = 0;
	play_frame = 0;
	play_floor_idx = 0;
	is_rec_valid = 1; // QLされたので記録を有効化
}

// 毎フレーム呼び出される記録・再生・描画処理
void UpdateGhost(void){
	// アクションパート中以外、または未QL状態は何もしない
	if(gameState != STATE_PLAY || !is_rec_valid){
		return;
	}

	// プレイヤーの現在座標を取得 (無効値またはコルクボード時は非表示)
	uint32_t cur_pos = getPos;
	if(cur_pos == 0 || cur_pos == POS_IN_CORKBOARD){
		HideGhost();
		return;
	}

	// --- 1. 記録処理 ---
	if(rec_frame < MAX_GHOST_FRAMES){
		rec_run->buf[rec_frame++] = cur_pos;
	}

	// --- 2. 再生・描画処理 ---
	// ロード地点に一致するゴーストが存在しない、またはフロア終端に達している場合は非表示
	if(!is_play_valid || !play_run || play_floor_idx >= play_run->floor_count){
		HideGhost();
		return;
	}

	// 現在フロアの終端フレーム (次フロアの開始フレーム、または総フレーム数)
	uint32_t play_floor_end = (play_floor_idx + 1 < play_run->floor_count)
		? play_run->floor_starts[play_floor_idx + 1]
		: play_run->total_frames;

	// 現在フロアの再生データ終端 (ゴーストが先にフロアを抜けた場合) は非表示にして終了
	if(play_frame >= play_floor_end){
		HideGhost();
		return;
	}

	uint32_t ghost_pos = play_run->buf[play_frame++];
	uint32_t cam = cameraPos;

	// 画面内描画座標 (ワールド座標 - カメラ座標、16x16星の中心合わせ)
	// 現在のカービィのスプライトに依存せず、カメラ基準で直接描画するため姿勢によるブレがゼロ
	int g_screen_x = POS_X(ghost_pos) - POS_X(cam) - STAR_HALF_SIZE;
	int g_screen_y = POS_Y(ghost_pos) - POS_Y(cam) - STAR_HALF_SIZE;

	// 画面外カリング (DS画面 256x192, マージン +-32ドット)
	if(IsOnScreen(g_screen_x, g_screen_y)){
		ShowGhost(g_screen_x, g_screen_y);
	}else{
		HideGhost();
	}
}

