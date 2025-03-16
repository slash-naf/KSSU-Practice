int* const seed  = (int*)0x02041D3C;	//乱数
int* const timer = (int*)0x02041D60;	//タイマー

short* const seed_advances = (short*)0x023FE57C;
short* const narrowed_seed_advances = (short*)0x023FE57E;

typedef struct{
	int timer;
	int seed_advances;
	int narrowed_seed_advances;
	int seed;
}Show;
Show* const show = (Show*)0x02090DD8;	//自前で作った4桁の数値4つ

const int lr_1st_advance_by_8F = 0x020801b0;
const int lr_2nd_advance_by_8F = 0x020801cc;


//乱数の進んだ量の加算
void add_from_advance_seed(){
	//r1のみ破壊

	asm volatile("ldr r1, [pc, #-0x30]");	//seed_advances

	asm volatile("add r1, r1, #0x00000001");
	asm volatile("add r1, r1, #0x00010000");

	asm volatile("bic r1, r1, #0x0000F000");
	asm volatile("bic r1, r1, #0xF0000000");

	asm volatile("str r1, [pc, #-0x44]");	//seed_advances

	//本来する処理
	asm volatile("str r0,[r2, #0x4a4]");

}
void add_from_randi(){
	/*
	int lr;
	asm volatile(
		"mov %0, lr;"
		: "=r"(lr)
	);

	*seed_advances = (*seed_advances + 1) & ~0xF000;

	if(lr != lr_1st_advance_by_8F && lr != lr_2nd_advance_by_8F){

		*narrowed_seed_advances = (*narrowed_seed_advances + 1) & ~0xF000;

	}
	*/

	//r2のみ破壊

	asm volatile("ldrh r2, [pc, #-0x14]");	//seed_advances
	asm volatile("add r2, r2, #1");
	asm volatile("bic r2, r2, #0xF000");
	asm volatile("strh r2, [pc, #-0x14]");	//seed_advances
	
	asm volatile("sub r2, lr, #0x02080000");
	asm volatile("cmp r2, #0x1b0");
	asm volatile("cmpne r2, #0x1cc");

	asm volatile("moveq r0, r0");	//飛ばす

	asm volatile("ldrh r2, [pc, #-0x12]");	//narrowed_seed_advances
	asm volatile("add r2, r2, #1");
	asm volatile("bic r2, r2, #0xF000");
	asm volatile("strh r2, [pc, #-0x12]");	//narrowed_seed_advances

	//本来する処理
	asm volatile("str r1, [r3, #0x4a4]");
	asm volatile("mul r0, r1, r0");
	asm volatile("mov r0, r0, lsr #12");
}

//表示の更新
void update(){
	/*
	(*show).seed = *seed;
	(*show).timer = *timer;
	(*show).seed_advances = *seed_advances;
	(*show).narrowed_seed_advances = *narrowed_seed_advances;
	*/

	//r4以降だけ破壊
	asm volatile("ldr r4, [pc, #0x18]");	//seedのアドレス
	asm volatile("ldr r8, [pc, #0x18]");	//showのアドレス

	asm volatile("ldrh r5, [pc, #-0x14]");	//seed_advances
	asm volatile("ldr r7, [r4, #0]");	//seed
	asm volatile("ldrh r6, [pc, #-0x12]");	//narrowed_seed_advances
	asm volatile("ldr r4, [r4, #0x24]");	//timer

	asm volatile("stmia r8, {r4-r7}");	//書き込み

}
