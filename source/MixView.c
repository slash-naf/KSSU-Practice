#include "symbols.h"

// ミックスルーレット中に毎フレーム実行されるカウントアップ処理
void Step(void){
    ctx.mix_cnt++;
}

// ミックス結果が表示されるタイミングで実行される処理
void View(void){
	// 特定の条件（r0とr2が0）の場合のみ処理を実行
	register int r0 asm("r0");
	register int r2 asm("r2");
	if(r0 == 0 && r2 == 0){
		int32_t val = 1;

		// カウンターの値に応じて表示する数値(1, 10, 100, 1000)を決定
		// 4フレーム周期のどのタイミングだったかを判定
		// 最終的に ctx.mix_cnt の下位2ビットは0になって実質的に初期化される
		while((++ctx.mix_cnt) & 3){
			val *= 10;
		}

		// QSQL用の表示領域(一番右)に結果を出力
		show[3] = val;
	}
}
