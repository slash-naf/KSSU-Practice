#include "symbols.h"
#include <stdint.h>

// セーブコンテキスト構造体 (ゲーム側のセーブ関数に渡されるパラメータ)
typedef struct {
	uint32_t unk[3];
	void* buffer;         // offset 0x0C: 書き込み元データのアドレス
	uint32_t save_offset; // offset 0x10: セーブメディア内の書き込み先オフセット
	uint32_t size;        // offset 0x14: 書き込みバイト数
} SaveContext;

// ログバッファのアドレス (先頭 1 ワードは記録されたログワード数)
#define LOG_ADDR 0x02F00000
#define log_buffer ((uint32_t*)LOG_ADDR)

// ダンプ済みフラグ (1回のセーブ処理で複数回フックが実行されるため、2回目以降の重複書き込みを抑止する)
int8_t is_dumped;

// セーブデータ書き込み処理 (0x02026BD4) フック関数
// 水晶の畑のセーブ部屋でRボタンを押しながらセーブした場合のみ、セーブ先バッファをログ配列に差し替える
void HookSave(void){
	register SaveContext* r0 asm("r0");
	SaveContext* ctx = r0;

	if(gameStates == 0x06010300 && ((~buttons) & R)){	// 水晶の畑のセーブ部屋でR
		ctx->buffer = (void*)log_buffer;
		ctx->save_offset = 0;
		// ゲーム側のセーブ処理はブロック単位で複数回ループするため、初回のみログ全体を書き込み、以降はサイズ0にして重複書き込みを防止する
		ctx->size = is_dumped ? 0 : (log_buffer[0] + 1) * sizeof(uint32_t);	// ヘッダ + ログ本体のバイト数
		is_dumped = 1;
	}
}
