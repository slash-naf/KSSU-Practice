
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


