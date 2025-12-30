#include "symbols.h"

// ミックスルーレット中に毎フレーム実行されるカウントアップ処理
void _start() {
    ctx.mix_cnt++;
}
