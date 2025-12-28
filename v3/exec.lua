
require("ActionReplay")

ram = allocateRam(0x023FD100, 0x1000)

QSQL = make("QSQL", {
	ram.hook(0x02001830, 0xE8BD8010, "QSQL.c")	--ボタン入力処理の関数のreturnにフック
})

gui.register(function()
	exec(QSQL)
end)
