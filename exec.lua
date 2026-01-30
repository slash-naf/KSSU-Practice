local ar = require("ActionReplay")

local ram = ar.allocateRam(0x022E0000, 0x022E0A00, 0x022E8000)

local QSQL = ar.newCode()
:import(ram:createModule("QSQL.c")
	:hook("QS", 0x02001830, 0xE8BD8010, 0xE8BD8010)	--ボタン入力処理の関数のreturnにフック
	:hook("QL", 0x02074ED8, 0xE92D4008)	--ロードの進行状況の読み取りの直前にフック
	:hook("MixStep", 0x02111E68, 0xE2411001)	--mix_cntのカウントアップ
)

--格闘王系モードでの下画面のボスの表示を通常時に切り替える処理の、ゲームモードに応じたリソースをロードする処理を上書き
QSQL:override(QSQL.symbols["ArenaImageSwitcher"], 0x0206CE20, 0xE3500007, 0x0206CF68)

--Freeze RoMK Timer
QSQL:if_eq(0x0206B6A0, 0xA2400C21)
:write32(0x0206B6A4, 0xE1A00000)
:write32(0x0206B6BC, 0xE1A00000)
:end_if()

print(QSQL:toString("QSQL"))

gui.register(function()
    QSQL:exec()
end)
