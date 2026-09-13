#include "symbols.h"
#include <stdint.h>

// 乱数カウンタのマスク (4桁表示に合わせて0〜4095でラップさせる)
#define ADVANCES_MASK (~0xF000)

// 乱数の進んだ量
// total (下位16bit): 全乱数進み回数
// narrowed (上位16bit): 絞り込み乱数進み回数 (8Fごとの定期的な進みを除外)
typedef union {
	struct {
		uint16_t total;
		uint16_t narrowed;
	};
	uint32_t raw;
} SeedAdvances;

SeedAdvances advances;

// 表示用バッファのポインタ (QSQLのshow配列のアドレスを設定)
// show[0]: seedTimer (乱数更新タイマー)
// show[1]: advances.total (全乱数進み回数)
// show[2]: advances.narrowed (絞り込み乱数進み回数)
// show[3]: seed (現在の乱数)
uint32_t* p_show;

// 表示バッファの更新
void UpdateRNG(void){
	if(p_show){
		p_show[0] = seedTimer & ADVANCES_MASK;
		p_show[1] = advances.total & ADVANCES_MASK;
		p_show[2] = advances.narrowed & ADVANCES_MASK;
		p_show[3] = seed;
	}
}

// advance_seed (0x0200B88C) フック用: 定期乱数進み時に加算
void AddFromAdvanceSeed(void){
	advances.total++;
	advances.narrowed++;
}

// randi (0x0200B8D0) フック用: 8F周期 (0x020801b0, 0x020801cc) を除外して加算
void AddFromRandi(void){
	register uint32_t* sp asm("sp");
	uint32_t lr = sp[13]; // トランポリンで退避された r14 (フック地点の lr)

	advances.total++;
	if(lr != 0x020801b0 && lr != 0x020801cc){
		advances.narrowed++;
	}
}

// 特定の乱数検知用: randi 実行直後に UpdateRNG を呼び出すラッパー関数
extern uint32_t randi(uint32_t max);
uint32_t RandiWithUpdate(uint32_t max){
	uint32_t result = randi(max);
	UpdateRNG();
	return result;
}
