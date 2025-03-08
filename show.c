/*
#define show_numbers_LEN 4
int* const show_numbers = (int*)0x02090E30;	//表示する4桁の数値4つ

typedef void Draw(int, int, int, int, int, int);
Draw* const draw = (Draw*)0x0200FE64;

const int max_digit = 10000;
#define TIMER_RESET 0x40000

//残機描画関数(0x02090D48)の中身を書き換える
void f(int some_addr, int x_pos, int y_pos, int lives){

	int x = 0x3C - 19;

	for(int i=0; i < show_numbers_LEN; i++){

		unsigned int num = show_numbers[i];

		unsigned int digit = max_digit;


		if(num >= TIMER_RESET){
			num = 0;
		}


		//	num = num % digit;	b0	f4
		while(num >= digit){
			//num -= digit;
			asm volatile("sub %0, %0, %1;" : "+r"(num) : "r"(digit));	//最適化抑制
		}
		


		do{

			digit = (digit * 205) >> 11;	//num /= 10;

			int img = 0x021e2668;
			while(num >= digit){
				num -= digit;
				img += 8;
			}

			draw(0x78, img, 0, x, y_pos, 1);	//数字描画

			x += 10;

		}while(digit > 1);

		x += 8;

	}

}
*/

void f(int some_addr, int x_pos, int y_pos, int lives){
	asm volatile("stmdb sp!, {r4-r9, lr};");

	//第5～6引数の設定
	asm volatile("mov r3, #1");
	asm volatile("stmdb sp!, {r2-r3};");


	asm volatile("ldr r8, [pc, #0x78]");

	asm volatile("mov r9, #205;");

	asm volatile("mov r4, #0x29");
	//int x = 0x3C - 19;


	asm volatile("mov r5, #0x6C");
	//numbers_loop:
	//for(int i=0; i < show_numbers_LEN; i++){

		asm volatile("ldr r6, [pc, r5];");
		//unsigned int num = show_numbers[i];

		asm volatile("mov r7, #0x710;");
		asm volatile("orr r7, r7, #0x2000;");
		//unsigned int digit = max_digit;


		asm volatile("movs r2, r6, lsr #18;");
		//if(num >= TIMER_RESET){
			asm volatile("movne r6, #0;");
			//num = 0;
		//}


		//	num = num % digit;	b0	f4
		//divide_loop:
		asm volatile("cmp r6, r7;");
		//while(num >= digit){
			asm volatile("subcs r6, r6, r7;");
			//num -= digit;
			asm volatile("movcs r0, r0;");
			//goto divide_loop;
		//}


		//digit_loop:
		//do{

			asm volatile("mul r7, r7, r9;");
			asm volatile("mov r7, r7, lsr #11;");
			//digit = (digit * 205) >> 11;	//num /= 10;

			asm volatile("mov r1, r8;");
			//int img = 0x021e2668;
			//dd:
			asm volatile("cmp r6, r7;");
			//while(num >= digit){
				asm volatile("subcs r6, r6, r7;");
				//num -= digit;
				asm volatile("addcs r1, r1, #8;");
				//img += 8;
				asm volatile("movcs r1, r1;");
				//goto dd;
			//}


			asm volatile("mov r0, #0x78;");
			asm volatile("mov r2, #0;");
			asm volatile("mov r3, r4;");

			asm volatile("mov r0, r0;");
			//draw(0x78, img, 0, x, y_pos, 1);	//数字描画


			asm volatile("add r4, r4, #10;");
			//x += 10;

		//}while(digit > 1);
		asm volatile("movs r2, r7, lsr #1;");
		asm volatile("movne r0, r0;");
		//goto digit_loop;	//ne


		asm volatile("add r4, r4, #8;");
		//x += 8;

	//}
	asm volatile("cmp r5, #0x78");
	asm volatile("addne r5, r5, #4");
	asm volatile("movne r1, r1;");
	//goto numbers_loop;	//ne


	asm volatile("add sp, sp, #8;");
	asm volatile("ldmia sp!, {r4-r9, pc};");
}