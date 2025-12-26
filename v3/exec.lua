
require("ActionReplay")

test = make("test", {
	hook(0x020017C8, 0xE0000004, "test.c")
})

gui.register(function()
	exec(test)
end)
