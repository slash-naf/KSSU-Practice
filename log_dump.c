
void f(){

	asm volatile(
		"mov r0, #0;"
		"mov r1, #0x02F00000;"
		"ldrh r2, [r1];"

		"mov r10, r0;"

		"mov r8, #0xFF00;"

		"ldrh r9, [r1, r2];"
		"cmp r9, r8;"

		"moveq r2, #0;"
		"moveq r0, r0;"

		"strh r8, [r1, r2];"
		"add r2, r2, #2;"
		"strh r8, [r1, r2];"
		"add r2, r2, #2;"
		"strh r8, [r1, r2];"

		"bic r2, r2, #3;"
		"mov r0, r0;"
	);

}
/*
r10 r0
r9 r1
r8 r2

03802B74 b 02efff00
b 03802B78
*/