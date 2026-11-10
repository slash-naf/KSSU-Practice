--- ActionReplay コードの読み込みと実行
-- ビルド・コード生成は TypeScript (build.ts / tools/scripts) が行い、
-- Lua 側は生成されたコードを読み込んで DeSmuME 上で実行するだけにしている。

local M = {}

local function read_codes(path)
	local cheats = {}
	local current = nil
	local file, err = io.open(path, "r")
	if not file then
		error("Cannot open Action Replay file: " .. tostring(path) .. " (" .. tostring(err) .. ")")
	end

	for line in file:lines() do
		local name = line:match("^%[([^%]]+)%]%s*$")
		if name then
			current = { name = name, codes = {} }
			table.insert(cheats, current)
		elseif current then
			local a, b = line:match("^%s*(%x%x%x%x%x%x%x%x)%s+(%x%x%x%x%x%x%x%x)")
			if a and b then
				table.insert(current.codes, tonumber(a, 16))
				table.insert(current.codes, tonumber(b, 16))
			end
		end
	end

	file:close()
	return cheats
end

local function execute(codes)
	local execution_status = true
	local offset = 0
	local data = 0

	local i = 1
	while i <= #codes do
		local word = codes[i]
		local codetype = bit.rshift(word, 28)
		local addr = bit.band(word, 0x0FFFFFFF)
		local constant = codes[i + 1]
		i = i + 2

		if codetype == 0xD then
			local sub = bit.rshift(word, 24)
			if sub == 0xD0 then
				-- 直前の if 文を閉じる (nds-bootstrap 同様、全条件を閉じる)
				execution_status = true
			elseif sub == 0xD1 then
				-- ループ実行 (生成コードでは未使用)
				execution_status = true
			elseif sub == 0xD2 then
				-- ループ実行 + レジスタクリア
				execution_status = true
				offset = 0
				data = 0
			elseif sub == 0xD3 then
				offset = constant
			elseif sub == 0xD4 then
				data = bit.band(data + constant, 0xFFFFFFFF)
			elseif sub == 0xD5 then
				data = constant
			elseif sub == 0xD6 then
				memory.writedword(bit.band(constant + offset, 0xFFFFFFFF), data)
				offset = bit.band(offset + 4, 0xFFFFFFFF)
			elseif sub == 0xD7 then
				memory.writeword(bit.band(constant + offset, 0xFFFFFFFF), bit.band(data, 0xFFFF))
				offset = bit.band(offset + 2, 0xFFFFFFFF)
			elseif sub == 0xD8 then
				memory.writebyte(bit.band(constant + offset, 0xFFFFFFFF), bit.band(data, 0xFF))
				offset = bit.band(offset + 1, 0xFFFFFFFF)
			elseif sub == 0xD9 then
				data = memory.readdword(bit.band(constant + offset, 0xFFFFFFFF))
			elseif sub == 0xDA then
				data = memory.readword(bit.band(constant + offset, 0xFFFFFFFF))
			elseif sub == 0xDB then
				data = memory.readbyte(bit.band(constant + offset, 0xFFFFFFFF))
			end
		elseif codetype == 0xE then
			-- E コードのデータ部分は条件に関係なく読み飛ばす
			local length = constant
			if execution_status then
				local dest = bit.band(addr + offset, 0xFFFFFFFF)
				for k = 0, length - 1 do
					local value = codes[i + bit.rshift(k, 2)]
					memory.writebyte(dest + k, bit.band(bit.rshift(value, bit.band(k, 3) * 8), 0xFF))
				end
			end
			i = i + math.ceil(length / 8) * 2
		elseif execution_status then
			-- 書き込み
			if codetype == 0x0 then
				memory.writedword(bit.band(addr + offset, 0xFFFFFFFF), constant)
			elseif codetype == 0x1 then
				memory.writeword(bit.band(addr + offset, 0xFFFFFFFF), bit.band(constant, 0xFFFF))
			elseif codetype == 0x2 then
				memory.writebyte(bit.band(addr + offset, 0xFFFFFFFF), bit.band(constant, 0xFF))
			-- 条件分岐 (32bit)
			elseif codetype == 0x3 then
				execution_status = memory.readdword(bit.band(addr + offset, 0xFFFFFFFF)) < constant
			elseif codetype == 0x4 then
				execution_status = memory.readdword(bit.band(addr + offset, 0xFFFFFFFF)) > constant
			elseif codetype == 0x5 then
				execution_status = memory.readdword(bit.band(addr + offset, 0xFFFFFFFF)) == constant
			elseif codetype == 0x6 then
				execution_status = memory.readdword(bit.band(addr + offset, 0xFFFFFFFF)) ~= constant
			-- 条件分岐 (16bit + マスク)
			elseif codetype >= 0x7 and codetype <= 0xA then
				local value = bit.band(constant, 0xFFFF)
				local mask = bit.bxor(bit.rshift(constant, 16), 0xFFFF)
				local mem = bit.band(memory.readword(bit.band(addr + offset, 0xFFFFFFFF)), mask)
				if codetype == 0x7 then
					execution_status = mem < value
				elseif codetype == 0x8 then
					execution_status = mem > value
				elseif codetype == 0x9 then
					execution_status = mem == value
				elseif codetype == 0xA then
					execution_status = mem ~= value
				end
			-- メモリコピー
			elseif codetype == 0xF then
				local dest = bit.band(addr + offset, 0xFFFFFFFF)
				for k = 0, constant - 1 do
					memory.writebyte(dest + k, memory.readbyte(offset + k))
				end
			end
		end
	end
end

--- 生成済み AR ファイルを読み込む
---@param path string
---@return table[]
function M.load(path)
	return read_codes(path)
end

--- チート 1 件を実行する
---@param cheat table
function M.exec(cheat)
	execute(cheat.codes)
end

--- AR コード列を直接実行する
---@param codes number[]
function M.execCodes(codes)
	execute(codes)
end

return M
