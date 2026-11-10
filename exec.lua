local ar = require("ActionReplay")

-- TypeScript でビルド・コード生成を行う
local build_command = "node --experimental-strip-types src/build.ts"
print(build_command)

local status = os.execute(build_command)
if status ~= 0 and status ~= true then
	error("Build failed (exit code: " .. tostring(status) .. ")")
end

-- 生成された Action Replay コードを読み込む
local cheats = ar.load("build/cheats.ar")
for _, cheat in ipairs(cheats) do
	print(string.format("Loaded %s (%d words)", cheat.name, #cheat.codes))
end

gui.register(function()
	for _, cheat in ipairs(cheats) do
		ar.exec(cheat)
	end
end)
