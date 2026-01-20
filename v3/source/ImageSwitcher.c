#include "symbols.h"

// 関数ポインタ
#define free_resource   ((void (*)(uint32_t))0x02002E78)
#define load_resource_A ((uint32_t (*)(uint32_t))0x02003BE4)
#define load_resource_B ((uint32_t (*)(uint32_t))0x02003820)
#define setup_resource  ((void (*)(uint32_t, uint32_t, uint32_t, uint32_t))0x02002428)

void _start(int32_t* r) {
	// R4レジスタにコンテキストのポインタが入っている
	uint32_t* resource_handle = (uint32_t*)(r[4] + 0x40);
	uint8_t* load_state = (uint8_t*)(r[4] + 0x44);
	uint8_t* image_index = (uint8_t*)(r[4] + 0x48);

	// ロード処理を実行 (State 2 のフローを模倣: 解放 -> ロード)
	
	// 1. 古いリソースを解放
	if (*resource_handle != 0) {
		free_resource(*resource_handle);
		*resource_handle = 0;
	}

	// 2. モードに応じた最新のリソースをロード
	uint32_t image_id = *image_index;
	uint32_t sub_image_id = 0x0206e000 + image_id * 12;

	if (gameMode == THE_ARENA) {
		// 格闘王の道
		sub_image_id += 0x140;
		image_id += 0x40;
	} else if (gameMode == THE_TRUE_ARENA) {
		// 真・格闘王への道
		sub_image_id += 0x014;
		if(image_id < 6){
			image_id += 0x53;
		}else{
			image_id += 0x57;
		}
	} else if (gameMode == HELPER_TO_HERO) {
		// ヘルパーマスター
		sub_image_id += 0x098;
		image_id += 0x31;
	}

	image_id += 0x12000;
	setup_resource(1, load_resource_A(image_id), 0x06218400, 0x2400);

	image_id -= 0x30;
	*resource_handle = load_resource_B(image_id);
	setup_resource(0x36, *resource_handle, 0x5c00, 0x1a0);

	setup_resource(1, load_resource_A(*(uint32_t*)sub_image_id), 0x06603800, 0x300);

	*load_state = 3;
}


