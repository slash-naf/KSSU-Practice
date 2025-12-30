
require("ActionReplay")

ram = allocateRam(0x023FD100, 0x1000)

QSQL = make("QSQL", {
	ram.hook(0x02001830, 0xE8BD8010, "QSQL.c")	--ボタン入力処理の関数のreturnにフック
})

MixView = make("MixView", {
	ram.hook(0x02111E68, 0xE2411001, "MixView_Step.c"),	--mix_cntのカウントアップ
	ram.hook(0x02071730, 0xE19330D0, "MixView_View.c")	--結果の表示
})

--エンディングへ遷移させる値が設定される所を、フロア遷移の値にする
gameStates = 0x0205B244
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

gui.register(function()
	exec(QSQL)
	exec(MixView)
	exec(PreventEnding)
end)
