enum Button{
	A      = 0x001,
	B      = 0x002,
	SELECT = 0x004,
	START  = 0x008,
	RIGHT  = 0x010,
	LEFT   = 0x020,
	UP     = 0x040,
	DOWN   = 0x080,
	R      = 0x100,
	L      = 0x200,
	X      = 0x400,
	Y      = 0x800,
};
int* const timer = (int*)0x02041D60;	//タイマー
char* const gameState = (char*)0x0205B244;
int* const  getPos = (int*)0x02076878;	//1Pの座標

#define TIMER_RESET 0x40000000

#define LOG 0x02F00000
unsigned short* const p = (unsigned short*)LOG;

int* const monitor_RNG = (int*)0x023FE580;
short* const seed_advances = (short*)0x023FE57C;
short* const narrowed_seed_advances = (short*)0x023FE57E;
int* const show = (int*)0x02090DD8;	//自前で作った4桁の数値4つ

short* const options = (short*)0x023FDF08;



unsigned short prev;
void f(int pressed, int r1){

	//L使わないからタッチの入力の検知に使う
	unsigned int touch = (*(short*)0x027fffac) & 0x100;
	unsigned int held;
	asm volatile(
		"orr %0, r4, %1, lsl #1"
		: "+r"(held), "+r"(touch)
	);

	if(*monitor_RNG == 0 && *options & LEFT){

		//ログの更新
		if(*getPos != 0){
			unsigned int size = p[0];
			unsigned int back = p[-1];

			if(size == back+4){
			a:
				p[size/2] = (0xC << 11) | held;
				p[size/2+1] = 0;
				p[0] = size + 4;
			}else{
				unsigned int n = prev ^ held;
				if(n == 0){
					p[size/2 - 1]++;
				}else{
					int i = 0;
					while( ((n >> i) & 1) == 0 ){
						i++;
					}
					for(int j=i+1; j < 12; j++){
						if((n >> j) & 1){
							goto a;
						}
					}
					p[size/2] = i << 11;
					p[0] = size + 2;
				}
			}
			prev = held;
		}

		//記録完了
		if(*gameState == 0xB && (pressed & SELECT) && (held & DOWN)){
			*options ^= LEFT;
			int newSize = p[-2];
			p[-1] = newSize;
			p[0] = newSize;
			show[3] = newSize/2;
		}
	}

}