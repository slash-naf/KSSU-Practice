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
function gt(addr, val, mask)
	if mask == nil then
		return {0x30000000 + addr, val}
	end
	return {0x70000000 + addr, val + bit.lshift(bit.bnot(mask), 16)}
end
function lt(addr, val, mask)
	if mask == nil then
		return {0x40000000 + addr, val}
	end
	return {0x80000000 + addr, val + bit.lshift(bit.bnot(mask), 16)}
end
function eq(addr, val, mask)
	if mask == nil then
		return {0x50000000 + addr, val}
	end
	return {0x90000000 + addr, val + bit.lshift(bit.bnot(mask), 16)}
end
function ne(addr, val, mask)
	if mask == nil then
		return {0x60000000 + addr, val}
	end
	return {0xA0000000 + addr, val + bit.lshift(bit.bnot(mask), 16)}
end
function d2()
	return {0xD2000000, 0}
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
				constant = bit.band(constant, 0xFFFF)
				local x = bit.band(bit.bnot(bit.rshift(constant, 16)), memory.readword(addr))
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
			elseif codetype < 0xE then
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

--C言語のファイルをコンパイルしてバイナリを抽出
function cc(path)
	--機械語のバイナリ取得
	os.execute("make clean & make SRC=source/"..path.." & pause")

	local file = io.open("build/payload.bin", "rb")
	if file == nil then
		error(path)
	end

	local cur = file:seek()
	local size = file:seek("end")
	file:seek("set", cur)
	local data = file:read("*all")
	file:close()

	os.execute("make clean")

	--コードの作成
	local codes = {}
	for i=1, size, 4 do
		table.insert(
			codes,
			string.byte(data, i) +
			bit.lshift(string.byte(data, i + 1), 8) +
			bit.lshift(string.byte(data, i + 2), 16) +
			bit.lshift(string.byte(data, i + 3), 24)
		)
	end
	return codes
end
--プログラムを常駐させるためのメモリ領域を作る
function allocateRam(origin, length)
	local obj = {origin=origin, length=length}

	--プログラムを常駐させる
	obj.put = function(codes)
		if obj.length < #codes then
			error("not fit in ram")
		end

		local arCodes = {
			eq(obj.origin, 0),
				patch(obj.origin, codes),
			d2()
		}

		--サブルーチンの呼び出しを上書きする
		arCodes.overwriteCall = function(addr)
			local addr = arCodes[0][0]
			local code = call(addr, targetAddr)
			return {
				ne(addr, code),
					write32(addr, code),
				d2()
			}
		end

		obj.origin = obj.origin + #codes * 4
		obj.length = obj.length - #codes * 4
		return arCodes
	end

	--C言語のファイルをコンパイルしてバイナリを抽出し、そのコードの配置とフックをするARコードを作成
	obj.hook = function(hookAddr, originalCode, path)
		--常駐させるコードの作成
		local codes = {
			push,	--レジスタの退避
			0xE1A0000D,	--mov r0,sp; 退避したレジスタを第一引数に渡す
			call(8, 24),
			pop,	--レジスタの復元
			originalCode,	--元の処理を行う
			jump(obj.origin + 20, hookAddr + 4)	--元の場所に戻る
		}
		local cc_codes = cc(path)
		for i=1, #cc_codes do
			table.insert(codes, cc_codes[i])
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

	return obj
end
