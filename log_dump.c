
void f(){

	asm volatile(
		"mov r1, #0x02F00000;"
		"str r1, [r0, #0xC];"
		"ldr r2, [r1, #-0x8];"
		"str r2, [r0, #0x14];"
		"mov r2, #0;"
		"str r2, [r1, #-0x8];"
		"str r2, [r0, #0x10];"
	);

}