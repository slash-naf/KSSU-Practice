require("ActionReplay")

ram = allocateRam(0x023FD000, 0x1000)

-- ライブラリのコンパイルと配置準備
QSQL_Lib = ram.loadLibrary("QSQL.c")
MixView_Lib = ram.loadLibrary("MixView.c")

QSQL = make("QSQL", {
	QSQL_Lib.codes,	--ライブラリ本体の書き込み
	ram.hookLink(0x02001830, 0xE8BD8010, QSQL_Lib.symbols.QS),	--ボタン入力処理の関数のreturnにフック
	ram.hookLink(0x02074ED8, 0xE92D4008, QSQL_Lib.symbols.QL),	--ロードフラグの読み取り(?)の直前にフック
    ram.hookLink(0x0206CE00, 0xE5940040, QSQL_Lib.symbols.ArenaImageSwitcher, 0xE8BD8010),	--格闘王での下画面のボスの表示のState2の処理を上書き
})

MixView = make("MixView", {
	MixView_Lib.codes,	--ライブラリ本体の書き込み
	ram.hookLink(0x02111E68, 0xE2411001, MixView_Lib.symbols.Step),	--mix_cntのカウントアップ
	ram.hookLink(0x02071730, 0xE19330D0, MixView_Lib.symbols.View),	--結果の表示
})

gui.register(function()
	exec(QSQL)
	exec(MixView)
end)
