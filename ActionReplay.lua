--- CodeObject クラス ---
local CodeObject = {}
CodeObject.__index = CodeObject

local function newCode()
	local self = setmetatable({}, CodeObject)
	self.codes = {}
	self.symbols = {}
	return self
end

-- コードを文字列化
function CodeObject:toString(name)
	local out = "[" .. name .. "]\r\n"
	local codes = self.codes
	for i=1, #codes, 2 do
		out = out .. string.format("%08X %08X\r\n", codes[i], codes[i+1])
	end
	return out
end

-- コードを追加
function CodeObject:append(c)
	if type(c) == "table" then
		for _, v in ipairs(c) do self:append(v) end
	else
		table.insert(self.codes, c)
	end
end

-- Action Replayコード
---メモリ書き込み
function CodeObject:write32(addr, val) self:append({addr, val}); return self end
function CodeObject:write16(addr, val) self:append({0x10000000 + addr, val}); return self end
function CodeObject:write8(addr, val)  self:append({0x20000000 + addr, val}); return self end

---条件分岐 (Primitives)
local function cmp(codetype, addr, val, mask)
	addr = codetype * 0x10000000 + addr
	--32ビット比較
	if mask == nil then
		return {addr, val}
	end
	--16ビット比較 + マスク
	if addr % 2 == 1 then
		addr = addr - 1
		mask = bit.lshift(mask, 8)
	end
	return {addr + 0x40000000, val + bit.lshift(bit.bnot(mask), 16)}
end

---条件分岐 (32bit / 16bit masked)
function CodeObject:if_gt(addr, val, mask) self:append(cmp(3, addr, val, mask)); return self end
function CodeObject:if_lt(addr, val, mask) self:append(cmp(4, addr, val, mask)); return self end
function CodeObject:if_eq(addr, val, mask) self:append(cmp(5, addr, val, mask)); return self end
function CodeObject:if_ne(addr, val, mask) self:append(cmp(6, addr, val, mask)); return self end
function CodeObject:end_if() self:append({0xD2000000, 0}); return self end

---一括書き込み
function CodeObject:patch(dest, codes)
	local len = #codes * 4
	if #codes % 2 == 1 then
		table.insert(codes, 0)
	end
	self:append({0xE0000000 + dest, len, codes})
	return self
end

-- モジュールのインポート
function CodeObject:import(mb)
	-- モジュールの配置先が0の場合(未初期化時)、データを書き込む
	self:if_eq(mb.origin, 0)
	:patch(mb.origin, mb.bin)
	:end_if()
	
	-- フックコードの追加
	self:append(mb.hooks.codes)
	
	-- シンボルの統合
	for name, addr in pairs(mb.symbols) do self.symbols[name] = addr end
	return self
end

-- ActionReplayコードをエミュレータ上で実行
-- nds-bootstrapのチートエンジンの仕様を基にしていて、DeSmuMeと違ってD0コードで直前の条件文だけでなく、D2コードと同じようにそれまでの全て条件文を終了させる
function CodeObject:exec()
	local codes = self.codes
	local execution_status = true
	local offset = 0
	local data = 0
	
	local i = 1
	while i <= #codes do
		local codetype = bit.rshift(codes[i], 28)
		local addr = bit.band(codes[i], 0x0FFFFFFF)
		local constant = codes[i+1]
		
		-- D0/D2 ロジック (条件終了/データクリア)
		if codetype == 0xD then
			local sub = bit.rshift(codes[i], 24)
			if sub == 0xD0 then execution_status = true end
			if sub == 0xD2 then offset=0; data=0; execution_status=true end
			-- Note: D3-DB等は必要に応じて実装
			codetype = sub
		end

		i = i + 2
		
		if execution_status then
			-- 書き込み系
			if codetype == 0x0 then memory.writedword(addr + offset, constant) end
			if codetype == 0x1 then memory.writeword(addr + offset, bit.band(constant, 0xFFFF)) end
			if codetype == 0x2 then memory.writebyte(addr + offset, bit.band(constant, 0xFF)) end
			
			-- 条件分岐 (32bit)
			if codetype == 0x3 then execution_status = memory.readdword(addr) > constant end
			if codetype == 0x4 then execution_status = memory.readdword(addr) < constant end
			if codetype == 0x5 then execution_status = memory.readdword(addr) == constant end
			if codetype == 0x6 then execution_status = memory.readdword(addr) ~= constant end
			
			-- 条件分岐 (16bit)
			if codetype >= 0x7 and codetype <= 0xA then
				local val = bit.band(constant, 0xFFFF)
				local mask = bit.bxor(bit.rshift(constant, 16), 0xFFFF)
				local mem = bit.band(memory.readword(addr), mask)
				if codetype == 0x7 then execution_status = mem > val end
				if codetype == 0x8 then execution_status = mem < val end
				if codetype == 0x9 then execution_status = mem == val end
				if codetype == 0xA then execution_status = mem ~= val end
			end
			
			-- 一括書き込み (Eコード)
			if codetype == 0xE then
				local len = constant
				local dest = addr + offset
				for k=0, len - 1 do
					local val = codes[i + bit.rshift(k, 2)]
					memory.writebyte(dest + k, bit.rshift(val, bit.band(k, 3) * 8))
				end
				i = i + math.ceil(len / 8) * 2
			end
		end
	end
end

-- ARM32機械語定数・生成関数
local push = 0xE92D5FFF -- stmdb r13!,{r0-r12,r14}; レジスタの退避
local pop = 0xE8BD5FFF  -- ldmia r13!,{r0-r12,r14}; レジスタの復元

local function jump(currentAddr, targetAddr)	-- startAddr: b targetAddr; ジャンプ処理
	return 0xEA000000 + bit.band(0x00FFFFFF, bit.rshift(targetAddr - currentAddr, 2) - 2)
end

local function call(currentAddr, targetAddr)	-- startAddr: bl targetAddr; サブルーチン呼び出し処理
	return 0xEB000000 + bit.band(0x00FFFFFF, bit.rshift(targetAddr - currentAddr, 2) - 2)
end

-- 内部関数: C言語のファイルをコンパイルして機械語とシンボルを抽出
local function cc(path, origin, bss)
	-- パスからファイル名(拡張子なし)を取得
	local name = string.match(path, "([^/]+)%.%w+$") or path

	-- makeコマンドを実行して機械語のバイナリとシンボル情報を生成 (失敗時はポーズする)
	local cmd = "make SRC=source/"..path
	if origin then
		cmd = cmd .. string.format(" ADDR=0x%08X", origin)
	end
	if bss then
		cmd = cmd .. string.format(" BSS=0x%08X", bss)
	end
	print(cmd)
	os.execute(cmd.." || pause")

	-- バイナリの読み込み
	local bin = {}
	local file = io.open("build/"..name..".bin", "rb")
	if file then
		local cur = file:seek()
		local size = file:seek("end")
		file:seek("set", cur)
		local data = file:read("*all")
		file:close()

		for i=1, size, 4 do
			table.insert(
				bin,
				string.byte(data, i) +
				bit.lshift(string.byte(data, i + 1), 8) +
				bit.lshift(string.byte(data, i + 2), 16) +
				bit.lshift(string.byte(data, i + 3), 24)
			)
		end
	else
		error("Warning: build/"..name..".bin not found")
	end

	-- シンボルの読み込み
	local symbols = {}
	local symFile = io.open("build/"..name..".txt", "r")
	if symFile then
		for line in symFile:lines() do
			-- "Address Type Name" (例: 023fe000 T _start)
			local addrStr, typeStr, symName = string.match(line, "(%x+)%s+(%a)%s+([%w_]+)")
			if addrStr and symName then
				symbols[symName] = tonumber(addrStr, 16)
			end
		end
		symFile:close()
	else
		error("Warning: build/"..name..".txt not found")
	end

	return { bin = bin, symbols = symbols }
end

-- メモリ管理マネージャの作成
-- codeAddr: コード配置開始アドレス
-- bssAddr: BSSセクション配置開始アドレス
-- endAddr: 使用可能最終アドレス (この直前まで使用可能)
local function allocateRam(codeAddr, bssAddr, endAddr)
	local ram = {
		codeCursor = codeAddr,    -- 現在のコード配置位置 (上方向に成長)
		bssCursor = bssAddr,      -- 現在のBSS配置位置 (上方向に成長)
		bssOrigin = bssAddr,      -- BSS領域の開始位置 (コード領域の終端チェック用)
		endAddr = endAddr,        -- メモリ領域の終端 (BSS領域の終端チェック用)
	}

	-- コード領域にメモリを割り当てる
	function ram:allocateCode(size, context)
		self.codeCursor = self.codeCursor + size
		if self.codeCursor > self.bssOrigin then
			error(string.format(
				"Error: Code allocation for '%s' overlaps BSS region.\nCode limit: 0x%08X (size: 0x%X)\nBSS start:  0x%08X",
				context, self.codeCursor, size, self.bssOrigin
			))
		end
	end

	-- C言語のソースコードからモジュールを作成
	function ram:createModule(path)
		local origin = self.codeCursor

		-- 現在のカーソル位置でコンパイル
		local lib = cc(path, origin, self.bssCursor)

		-- モジュール本体のサイズ分、コード用カーソルを進める
		self:allocateCode(#lib.bin * 4, path .. " (Main Body)")

		-- __bss_end シンボルがあれば BSS用カーソルを更新
		if lib.symbols["__bss_end"] then
			self.bssCursor = lib.symbols["__bss_end"]
			if self.bssCursor > self.endAddr then
				error(string.format(
					"Error: BSS allocation for '%s' exceeds memory limit.\nBSS limit:  0x%08X\nMemory End: 0x%08X",
					path, self.bssCursor, self.endAddr
				))
			end
		end

		-- モジュールオブジェクトの構築
		local mb = {}
		mb.path = path
		mb.bin = lib.bin
		mb.symbols = lib.symbols
		mb.origin = origin
		mb.hooks = newCode()	-- フック用コードは別オブジェクトとして管理
		mb.ram = self -- 親のRAMマネージャへの参照

		-- フックの登録メソッド
		-- funcName: モジュール内の関数名
		-- hookAddr: フックを挿入するゲーム側のメモリアドレス
		-- originalCode: フック等の上書きで消えてしまう元の命令
		-- ret: フック後の戻り先 (nilなら直後へ, アドレスならそこへジャンプ, 命令ならそれを実行)
		function mb:hook(funcName, hookAddr, originalCode, ret)
			--関数のアドレス
			local targetAddr = self.symbols[funcName]
			if not targetAddr then error("Symbol not found: " .. funcName) end

			-- トランポリンコード (レジスタ保存 -> 関数呼び出し -> 復帰) の作成
			-- トランポリンはモジュール本体の後ろに順次追加される
			local trampolineAddr = self.ram.codeCursor
			local trampoline = {
				push,
				call(trampolineAddr + 4, targetAddr),
				pop
			}
			
			-- 戻り処理の追加
			if ret then
				if ret < 0x10000000 then	-- アドレス指定の場合: そのアドレスへジャンプ
					table.insert(trampoline, jump(trampolineAddr + #trampoline * 4, ret))
				else	-- 命令指定の場合: その命令を実行
					table.insert(trampoline, ret)
				end
			else
				-- 指定なしの場合: 元の命令を実行してから、フック地点の次の命令へ戻る
				table.insert(trampoline, originalCode)
				table.insert(trampoline, jump(trampolineAddr + #trampoline * 4, hookAddr + 4))
			end

			-- トランポリンコードをコード配列に追加
			for _, c in ipairs(trampoline) do table.insert(self.bin, c) end

			-- ゲーム側のフック地点を書き換えるARコードを生成
			-- 条件: 元のコードが変更されていない(メモリズレ対策)場合のみ書き換え
			self.hooks:if_eq(hookAddr, originalCode)
			:write32(hookAddr, jump(hookAddr, trampolineAddr))
			:end_if()

			-- トランポリン分のサイズをRAM管理に反映
			self.ram:allocateCode(#trampoline * 4, self.path .. "::" .. funcName .. " (Hook Trampoline)")

			return self
		end
		return mb
	end
	return ram
end

return {
	newCode=newCode,
	allocateRam=allocateRam,
}