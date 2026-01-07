
require("ActionReplay")

--symbols
gameStates = 0x0205B244
GameState = {
	STATE_PLAY         = 0,
	STATE_FLOOR_LOAD   = 1,
	STATE_STAGE_CLEAR  = 2,
	STATE_GAME_CLEAR   = 3,
	STATE_DIE          = 4,
	STATE_SPECIAL      = 5,
	STATE_ARENA_PROCEED= 5,
	STATE_MAP          = 6,
	STATE_ARENA_MATCH  = 6,
	STATE_SWITCH       = 7,
	STATE_SHORT_MOVIE  = 9,
	STATE_PAUSE        = 0xB,
}
buttons = 0x04000130
heldButtons = 0x02041E64
pressedButtons = 0x02041E68
Button = {
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
}

--エンディングへ遷移させる値が設定される所を、フロア遷移の値にする
PreventEnding = make("PreventEnding", {
	--ダイナブレイド 021A4464: mov r1, #3 -> mov r1, #1
	eq(gameStates, 0x02040100),
	eq(0x021A4464, 0xE3A01003),
	write8(0x021A4464, 1),
	d2(),

	--洞窟大作戦 0217D4F0: mov r1, #3 -> mov r1, #1
	eq(gameStates, 0x14030300),
	eq(0x0217D4F0, 0xE3A01003),
	write8(0x0217D4F0, 1),
	d2(),

	--メタナイトの逆襲 021A51C4: mov r0, #3 -> mov r0, #1
	eq(gameStates, 0x01070400),
	eq(0x021A51C4, 0xE3A00003),
	write8(0x021A51C4, 1),
	d2(),

	--銀河にねがいを 021A6C38: mov r1, #3 -> mov r1, #1
	eq(gameStates, 0x02080500),
	eq(0x021A6C38, 0xE3A01003),
	write8(0x021A6C38, 1),
	d2(),

	--メタナイトでゴー 021A9BF4: mov r1, #3 -> mov r1, #1
	eq(gameStates, 0x3B040800),
	eq(0x021A9BF4, 0xE3A01003),
	write8(0x021A9BF4, 1),
	d2()
})

--R+STARTでいつでもポーズ
PauseAnytime = make("PauseAnytime", {
	eq(buttons, 0, Button.R + Button.START),
	write8(gameStates, GameState.STATE_PAUSE),
	d2()
})

--Rを押しながらSELECTで死ぬ
DieAnytime =  make("DieAnytime", {
	eq(heldButtons, Button.R + Button.SELECT, 0xFFFF),
	ne(pressedButtons, 0, Button.SELECT),
	write8(gameStates, GameState.STATE_DIE),
	d2()
})

--ステージ・フロアを自由に遷移する
NavigateFloor = make("NavigateFloor", {
	--Rと右を押しながらSELECTで次のフロアへ
	eq(heldButtons, Button.R + Button.RIGHT + Button.SELECT, 0xFFFF),
	ne(pressedButtons, 0, Button.SELECT),
	eq(gameStates, 0, 0xFF),
	add(gameStates, gameStates, 0x01000000 + 1),
	d2(),
	--Rと左を押しながらSELECTで前のフロアへ
	eq(heldButtons, Button.R + Button.LEFT + Button.SELECT, 0xFFFF),
	ne(pressedButtons, 0, Button.SELECT),
	eq(gameStates, 0, 0xFF),
	ne(gameStates+3, 0, 0xFF),	--フロアが0でなければ
	add(gameStates, gameStates, -0x01000000 + 1),
	d2(),
	--Rと上を押しながらSELECTで次のステージへ
	eq(heldButtons, Button.R + Button.UP + Button.SELECT, 0xFFFF),
	ne(pressedButtons, 0, Button.SELECT),
	eq(gameStates, 0, 0xFF),
	write8(gameStates+3, 0),	--フロアを0に
	add(gameStates, gameStates, 0x010000 + 1),
	d2(),
	--Rと下を押しながらSELECTで前のステージへ
	eq(heldButtons, Button.R + Button.DOWN + Button.SELECT, 0xFFFF),
	ne(pressedButtons, 0, Button.SELECT),
	eq(gameStates, 0, 0xFF),
	ne(gameStates+2, 0, 0xFF),	--ステージが0でなければ
	write8(gameStates+3, 0),	--フロアを0に
	add(gameStates, gameStates, -0x010000 + 1),
	d2(),
})
