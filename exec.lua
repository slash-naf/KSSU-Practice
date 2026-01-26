require("ActionReplay")

ram = allocateRam(0x022E0000, 0x1000)

QSQL = createActionReplayCode()
:import(ram:createModule("QSQL.c")
	:hook("QS", 0x02001830, 0xE8BD8010)	--ボタン入力処理の関数のreturnにフック
	:hook("QL", 0x02074ED8, 0xE92D4008)	--ロードの進行状況の読み取りの直前にフック
	:hook("ArenaImageSwitcher", 0x0206CE00, 0xE5940040, 0xE8BD8010)	--格闘王系モードでの下画面のボスの表示を通常時に切り替える処理を上書き
)
print(QSQL:toString("QSQL"))

MixView = createActionReplayCode()
:import(ram:createModule("MixView.c")
	:hook("Step", 0x02111E68, 0xE2411001)	--mix_cntのカウントアップ
	:hook("View", 0x02071730, 0xE19330D0)	--結果の表示
)
print(MixView:toString("MixView"))

gui.register(function()
    QSQL:exec()
	MixView:exec()
end)
