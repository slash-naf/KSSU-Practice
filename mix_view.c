void step(){
	asm volatile("str r1, [pc, #-0x10]");	//退避

	asm volatile("ldr r1, [pc, #-0x10]");	//mix_cnt
	asm volatile("add r1, r1, #1");	//カウントアップ
	asm volatile("str r1, [pc, #-0x18]");	//mix_cnt

	asm volatile("ldr r1, [pc, #-0x20]");	//復元
	asm volatile("sub r1, r1, #1");	//元の処理

}

void view(int r0, int r1, int r2){
	asm volatile("stmdb sp!, {r0-r2}");	//退避

	if(r0 == 0 && r2 == 0){
		asm volatile("ldr %0, [pc, #-0x34]" : "+r"(r0));	//mix_cnt

		r1 = 1;

		while((++r0) & 3){
			r1 *= 10;
		}

		*((int*)0x02090DE4) = r1;

		asm volatile("str %0, [pc, #-0x60]" : "+r"(r0));	//mix_cnt
	}

	asm volatile("ldmia sp!, {r0-r2}");	//復元

}