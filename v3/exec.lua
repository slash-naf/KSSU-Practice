
require("ActionReplay")

ram = allocateRam(0x023FD100, 0x1000)

QSQL = make("QSQL", {
	ram.hook(0x02001830, 0xE8BD8010, "QSQL.c")	--ボタン入力処理の関数のreturnにフック
})

MixView = make("MixView", {
	ram.hook(0x02111E68, 0xE2411001, "MixView_Step.c"),	--mix_cntのカウントアップ
	ram.hook(0x02071730, 0xE19330D0, "MixView_View.c")	--結果の表示
})

gui.register(function()
	exec(QSQL)
	exec(MixView)
end)
