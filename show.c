
#define show_numbers_LEN 4
int* const show_numbers = (int*)0x02090E30;	//表示する4桁の数値4つ

typedef void Draw(int, int, int, int, int, int);
Draw* const draw = (Draw*)0x0200FE64;

const int max_digit = 10000;
const int max_digit_mask = 0x3FFF;
#define TIMER_RESET 0x1000000

#define DIGITS_LEN 4
const short digits[4] = {1000, 100, 10, 1};

//残機描画関数(0x02090D48)の中身を書き換える
void f(int some_addr, int x_pos, int y_pos, int lives){

	int x = 0x3C - 19;

	int i = 0;
	for(int i=0; i < show_numbers_LEN; i++){

		unsigned int num = show_numbers[i];

		if(num >= TIMER_RESET){
			num = 0;
		}
		num &= max_digit_mask;
		if(num >= max_digit){num -= max_digit;}

		for(int j=0; j < DIGITS_LEN; j++){

			int digit = digits[j];

			int img = 0x021e2668;
			while(num >= digit){
				num -= digit;
				img += 8;
			}

			draw(0x78, img, 0, x, y_pos, 1);	//数字描画

			x += 10;
		};
		x += 8;
	}

}


