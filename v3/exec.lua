
require("ActionReplay")

ram = allocateRam(0x023FE000, 0x1000)

test = make("test", {
	ram.hook(0x02001830, 0xE8BD8010, "test.c")	--ボタン入力処理の関数のreturnにフック
})

gui.register(function()
	exec(test)
end)
