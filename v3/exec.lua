require("ActionReplay")

ram = allocateRam(0x023FD000, 0x1000)

QSQL_Mod = ram.createModule("QSQL.c")
QSQL_Mod.hook("QS", 0x02001830, 0xE8BD8010)	--ボタン入力処理の関数のreturnにフック
QSQL_Mod.hook("QL", 0x02074ED8, 0xE92D4008)	--ロードフラグの読み取り(?)の直前にフック
QSQL_Mod.hook("ArenaImageSwitcher", 0x0206CE00, 0xE5940040, 0xE8BD8010)	--格闘王での下画面のボスの表示のState2の処理を上書き
QSQL = make("QSQL", QSQL_Mod.build())

MixView_Mod = ram.createModule("MixView.c")
MixView_Mod.hook("Step", 0x02111E68, 0xE2411001)	--mix_cntのカウントアップ
MixView_Mod.hook("View", 0x02071730, 0xE19330D0)	--結果の表示
MixView = make("MixView", MixView_Mod.build())

gui.register(function()
	exec(QSQL)
	exec(MixView)
end)
