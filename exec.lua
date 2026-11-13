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

-- TypeScript でビルド・コード生成を行う
local build_command = "make"
print(build_command)

local status = os.execute(build_command)
if status ~= 0 and status ~= true then
	error("Build failed (exit code: " .. tostring(status) .. ")")
end

-- 生成された Action Replay コードを読み込む
local loaded_cheats = ar.load("dist/cheats.ar")
local cheats_by_name = {}
for _, cheat in ipairs(loaded_cheats) do
	cheats_by_name[cheat.name] = cheat
end

-- 実行するチートだけを取り出す
local runtime_cheats = {}
for _, name in ipairs(runtime_cheat_names) do
	local cheat = cheats_by_name[name]
	if not cheat then
		error("Cheat not found: " .. name)
	end
	table.insert(runtime_cheats, cheat)
	print(string.format("%s (%d words)", cheat.name, #cheat.codes))
end

gui.register(function()
	for _, cheat in ipairs(runtime_cheats) do
		ar.exec(cheat)
	end
end)
