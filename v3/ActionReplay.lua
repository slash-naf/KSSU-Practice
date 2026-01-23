--ActionReplayコードの作成
---メモリ書き込み
function write32(addr, val)
	return {addr, val}
end
function write16(addr, val)
	return {0x10000000 + addr, val}
end
function write8(addr, val)
	return {0x20000000 + addr, val}
end
---条件分岐
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
function gt(addr, val, mask)
	return cmp(3, addr, val, mask)
end
function lt(addr, val, mask)
	return cmp(4, addr, val, mask)
end
function eq(addr, val, mask)
	return cmp(5, addr, val, mask)
end
function ne(addr, val, mask)
	return cmp(6, addr, val, mask)
end
function d2()
	return {0xD2000000, 0}
end
--定数を加算してメモリコピー
function add(src, dest, constant)
	return {
		0xD9000000, src,
		0xD4000000, constant,
		0xD6000000, dest,
		0xD3000000, 0
	}
end
---メモリコピー
function copy(src, dest, len)
	return {
		0xD3000000, src,
		0xF0000000 + dest, len,
		0xD3000000, 0
	}
end
---一括書き込み
function patch(dest, codes)
	local len = #codes * 4
	if #codes % 2 == 1 then
		table.insert(codes, 0)
	end
	return {0xE0000000 + dest, len, codes}
end


--コードのまとまりを作成
function make(name, codes)
	print("["..name.."]")

	--フラット化する
	local function flat(tbl, arr)
		for i=1, #arr do
			local x = arr[i]
			if type(x) == "number" then
				table.insert(tbl, x)
			else
				flat(tbl, x)
			end
		end
		return tbl
	end
	codes = flat({}, codes)

	--表示
	for i=1, #codes, 2 do
		print(string.format("%08X ", codes[i])..string.format("%08X", codes[i+1]))
	end
	print("")

	return codes
end

--ActionReplayコードを実行
--たぶん欠陥がかなりあるけどallocateRam関連のはたぶん問題ない
--nds-bootstrapのチートエンジンの仕様を基にしていて、DeSmuMeと違ってD0コードで直前の条件文だけでなく、D2コードと同じようにそれまでの全て条件文を終了させる
--ループのコードとNitroHaxの拡張コードは未実装(詳しい仕様をちゃんと調べていない)
function exec(codes)
	local offset = 0
	local data = 0
	local execution_status = true

	local i = 1;
	while i <= #codes do
		local codetype = bit.rshift(codes[i], 28)
		local addr = bit.band(codes[i], 0x0FFFFFFF)
		local constant = codes[i+1]
		if codetype == 0xD then
			codetype = bit.rshift(codes[i], 24)
		end

		i = i + 2

		--ターミネータコード
		if codetype == 0xD0 then --条件文終了
			execution_status = true
		elseif codetype == 0xD2 then --条件文終了と初期化
			offset = 0
			data = 0
			execution_status = true
		end

		if execution_status then
			-- 書き込み
			if codetype < 0x3 then
				if codetype == 0x0 then -- 32ビット書き込み
					-- 0XXXXXXX YYYYYYYY	[XXXXXXX+offset] に YYYYYYYY を32ビット書き込む
					memory.writedword(addr + offset, constant)
				elseif codetype == 0x1 then -- 16ビット書き込み
					-- 1XXXXXXX 0000YYYY	[XXXXXXX+offset] に YYYY を16ビット書き込む
					memory.writeword(addr + offset, bit.band(constant, 0xFFFF))
				elseif codetype == 0x2 then -- 8ビット書き込み
					-- 2XXXXXXX 000000YY	[XXXXXXX+offset] に YY を8ビット書き込む
					memory.writebyte(addr + offset, bit.band(constant, 0xFF))
				end

			-- 条件分岐 (32ビット)
			elseif codetype < 0x7 then
				local x = memory.readdword(addr)
				if codetype == 0x3 then
					-- 3XXXXXXX YYYYYYYY	Checks if YYYYYYYY > (word at [XXXXXXX])
					execution_status = constant > x
				elseif codetype == 0x4 then
					-- 4XXXXXXX YYYYYYYY	Checks if YYYYYYYY < (word at [XXXXXXX])
					execution_status = constant < x
				elseif codetype == 0x5 then
					-- 5XXXXXXX YYYYYYYY	Checks if YYYYYYYY == (word at [XXXXXXX])
					execution_status = constant == x
				elseif codetype == 0x6 then
					-- 6XXXXXXX YYYYYYYY	Checks if YYYYYYYY != (word at [XXXXXXX])
					execution_status = constant ~= x
				end

			-- 条件分岐 (16ビット + マスク)
			elseif codetype < 0xB then
				local x = bit.band(bit.band(bit.bnot(bit.rshift(constant, 16)), 0xFFFF), memory.readword(addr))
				constant = bit.band(constant, 0xFFFF)
				if codetype == 0x7 then
					-- 7XXXXXXX ZZZZYYYY	Checks if (YYYY) > (not (ZZZZ) & halfword at [XXXX]).
					execution_status = constant > x
				elseif codetype == 0x8 then
					-- 8XXXXXXX ZZZZYYYY	Checks if (YYYY) < (not (ZZZZ) & halfword at [XXXXXXX]).
					execution_status = constant < x
				elseif codetype == 0x9 then
					-- 9XXXXXXX ZZZZYYYY	Checks if (YYYY) == (not (ZZZZ) & halfword at [XXXXXXX]).
					execution_status = constant == x
				elseif codetype == 0xA then
					-- AXXXXXXX ZZZZYYYY	Checks if (YYYY) != (not (ZZZZ) & halfword at [XXXXXXX]).
					execution_status = constant ~= x
				end

			-- オフセット/データレジスタ
			elseif codetype >= 0xD0 then
				if codetype == 0xB then -- オフセット32ビット読み込み
					offset = memory.readdword(addr + offset)

				elseif codetype == 0xD3 then -- オフセット設定
					offset = constant
				elseif codetype == 0xDC then -- オフセット加算
					offset = offset + constant
				
				elseif codetype == 0xD4 then -- データ加算
					data = data + constant
				elseif codetype == 0xD5 then -- データ設定
					data = constant
				
				elseif codetype == 0xD6 then -- 32ビット書き込み (オフセット加算)
					memory.writedword(addr + offset, data)
					offset = offset + 4
				elseif codetype == 0xD7 then -- 16ビット書き込み (オフセット加算)
					memory.writeword(addr + offset, bit.band(data, 0xFFFF))
					offset = offset + 2
				elseif codetype == 0xD8 then -- 8ビット書き込み (オフセット加算)
					memory.writebyte(addr + offset, bit.band(data, 0xFF))
					offset = offset + 1
					
				elseif codetype == 0xD9 then -- 32ビット読み込み
					data = memory.readdword(addr + offset)
				elseif codetype == 0xDA then -- 16ビット読み込み
					data = memory.readword(addr + offset)
				elseif codetype == 0xDB then -- 8ビット読み込み
					data = memory.readbyte(addr + offset)
				end

			-- パッチ
			elseif codetype == 0xE then
				-- EXXXXXXX YYYYYYYY	コピー元 (現在のコード位置 + 8) から [XXXXXXXX + offset] へ YYYYYYYY バイトコピー
				local len = constant
				local dest = addr + offset
				for k=0, len - 1 do
					local val = codes[i + bit.rshift(k, 2)]
					memory.writebyte(dest + k, bit.rshift(val, bit.band(k, 3) * 8))
				end
				i = i + math.ceil(len / 8) * 2

			-- メモリコピー
			elseif codetype == 0xF then
				-- FXXXXXXX YYYYYYYY	オフセットからXへYバイトコピーする。オフセットを設定しておく必要がある。
				local len = constant
				local dest = addr
				local src = offset
				for k=0, len - 1 do
					memory.writebyte(dest + k, memory.readbyte(src + k))
				end
			end
		end
	end
end


--ARM32の機械語
local nop = 0xE1A00000 -- nop(mov r0,r0);
local ret = 0xE12FFF1E -- bx r14;
local push = 0xE92D5FFF -- stmdb r13!,{r0-r12,r14}; レジスタの退避
local pop = 0xE8BD5FFF -- ldmia r13!,{r0-r12,r14}; レジスタの復元
function jump(current_addr, target_addr)	--ジャンプ
	local n = bit.rshift(target_addr - current_addr, 2) - 2
	return 0xEA000000 + bit.band(0x00FFFFFF, n)
end
function call(current_addr, target_addr)	--サブルーチン呼び出し
	local n = bit.rshift(target_addr - current_addr, 2) - 2
	return 0xEB000000 + bit.band(0x00FFFFFF, n)
end

--C言語のファイルをコンパイルして機械語のバイナリとシンボルを抽出
function cc(path, origin)
	--makeコマンドを実行して機械語のバイナリとシンボル情報を生成
	local origin_hex = string.format("%08X", origin)
	local cmd = "make clean && make ADDR=0x"..origin_hex.." SRC=source/"..path.." & pause"
	print(cmd)
	os.execute(cmd)

	--バイナリの読み込み
	local codes = {}
	local file = io.open("build/payload.bin", "rb")
	if file then
		local cur = file:seek()
		local size = file:seek("end")
		file:seek("set", cur)
		local data = file:read("*all")
		file:close()

		for i=1, size, 4 do
			table.insert(
				codes,
				string.byte(data, i) +
				bit.lshift(string.byte(data, i + 1), 8) +
				bit.lshift(string.byte(data, i + 2), 16) +
				bit.lshift(string.byte(data, i + 3), 24)
			)
		end
	else
		error("Warning: payload.bin not found")
	end

	--シンボルの読み込み
	local symbols = {}
	local symFile = io.open("build/symbols.txt", "r")
	if symFile then
		for line in symFile:lines() do
			-- "Address Type Name" (例: 023fe000 T _start)
			local addrStr, typeStr, name = string.match(line, "(%x+)%s+(%a)%s+([%w_]+)")
			if addrStr and name then
				symbols[name] = tonumber(addrStr, 16)
			end
		end
		symFile:close()
	else
		error("Warning: symbols.txt not found")
	end

	return { codes = codes, symbols = symbols }
end
--プログラムを常駐させるためのメモリ領域を作る
function allocateRam(origin, length)
	local obj = {origin=origin, length=length}

	--プログラムを常駐させる
	obj.put = function(codes)
		if obj.length < #codes then
			error("not fit in ram")
		end

		local len = #codes * 4

		local arCodes = {
			eq(obj.origin, 0),
				patch(obj.origin, codes),
			d2()
		}

		obj.origin = obj.origin + len
		obj.length = obj.length - len
		return arCodes
	end

	--ライブラリ(複数の関数を含むCコード)のロード
	obj.loadLibrary = function(path)
		local lib = cc(path, obj.origin)
		local arCodes = obj.put(lib.codes)
		return { symbols = lib.symbols, codes = arCodes }
	end

	--ロード済みライブラリ内の関数へのフック
	obj.hookLink = function(hookAddr, originalCode, targetAddr, retCode, retAddr)
		--常駐させるコードの作成
		local codes = {
			push,	--レジスタの退避
			call(obj.origin + 4, targetAddr),	--サブルーチン呼び出し
			pop,	--レジスタの復元
		}

		--元の処理とリターン
		if retCode then
			table.insert(codes, retCode)
		elseif retAddr then
			table.insert(codes, jump(obj.origin + #codes * 4, retAddr))
		else
			table.insert(codes, originalCode)	--元の処理を行う
			table.insert(codes, jump(obj.origin + #codes * 4, hookAddr + 4))	--元の場所にジャンプ
		end

		--フックとコードの配置
		local arCodes = {
			eq(hookAddr, originalCode),
				write32(hookAddr, jump(hookAddr, obj.origin)),
			d2()
		}
		table.insert(arCodes, obj.put(codes))
		return arCodes
	end

	--サブルーチン呼び出しの上書き
	obj.overwriteCall = function(hookAddr, originalAddr, targetAddr)
		return {
			eq(hookAddr, call(hookAddr, originalAddr)),
				write32(hookAddr, call(hookAddr, targetAddr)),
			d2()
		}
	end

	return obj
end
