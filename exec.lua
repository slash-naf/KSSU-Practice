local ar = dofile("tools/desmume/ActionReplay.lua")

-- DeSmuME 上で実行するチート (コメントを外したチートだけを実行する)
local runtime_cheat_names = {
	-- "Mute",
	"QSQL",
	-- "Monitor RNG",
	-- "Log Dump",
	"Ghost",
	-- "Impact Star",
	-- "Invincibility Star",
	-- "Losing Ability",
	-- "Defeated Enemy Effect",
	-- "Food Star",
	-- "Whale Rolls or Splashes",
	-- "Windows Attacks First",
	-- "Windows Copy Essences",
	-- "Windows Moves",
	-- "Lobster Walks or Dashes",
	-- "Lobster Jumps or Glides",
}

-- ビルド・コード生成を行う
local build_command = "make"
print(build_command)

local status = os.execute(build_command)
if status ~= 0 and status ~= true then
	error("Build failed (exit code: " .. tostring(status) .. ")")
end

-- 実行するチートを読み込む
local runtime_cheats = ar.load("dist/cheats.ar", runtime_cheat_names)
for _, cheat in ipairs(runtime_cheats) do
	print(string.format("%s (%d words)", cheat.name, #cheat.codes))
end

gui.register(function()
	for _, cheat in ipairs(runtime_cheats) do
		ar.exec(cheat)
	end
end)
