--文字列を分割して処理し配列にする
function split(text, delimiter, func)
	func = func or function(m) return m end
	local result = {}
	local pattern = string.format("([^%s]+)", delimiter)
	for v in text:gmatch(pattern) do
		result[#result + 1] = func(v)
	end
	return result
end

--コマンドを実行して結果を取得する
function execute_cmd(cmd)
	local handle = io.popen(cmd)
	local result = handle:read('*a')
	handle:close()
	return result
end

--バイナリファイルを読み込み
function read_file_bytes(path)
	local file = io.open(path, "rb")

	if file == nil then
		return nil
	end
	
	-- ファイルサイズ取得
	local cur = file:seek()
	local size = file:seek("end")
	file:seek("set", cur)

	-- 全読込み
	local data = file:read("*all")
	file:close()

	return data
end

--メモリ書き込みとそのARコードの出力
function writedword(addr, n)	--メモリ4byte書き込み
	memory.writedword(addr, n)
	print("0"..string.format("%07X ", addr)..string.format("%08X", n))
end
function writeword(addr, n)	--メモリ2byte書き込み
	memory.writeword(addr, n)
	print("1"..string.format("%07X ", addr)..string.format("%08X", n))
end
function writebyte(addr, n)	--メモリ1byte書き込み
	memory.writebyte(addr, n)
	print("2"..string.format("%07X ", addr)..string.format("%08X", n))
end
function patch(addr, a)	--配列で一括書き込み
	local size = #a * 4
	print("E"..string.format("%07X ", addr)..string.format("%08X", size))

	for i=1, #a, 2 do
		memory.writedword(addr + (i-1) * 4, a[i])

		local x = a[i+1] or 0

		if i+1 <= #a then
			memory.writedword(addr + i * 4, x)
		end

		print(string.format("%08X ", a[i])..string.format("%08X", x))

	end
end

--ARコードの出力
function if_lt(addr, val)	--if(*(int*)addr < val)
	print("3"..string.format("%07X ", addr)..string.format("%08X", val))
end
function if_gt(addr, val)	--if(*(int*)addr > val)
	print("4"..string.format("%07X ", addr)..string.format("%08X", val))
end
function if_eq(addr, val)	--if(*(int*)addr == val)
	print("5"..string.format("%07X ", addr)..string.format("%08X", val))
end
function if_ne(addr, val)	--if(*(int*)addr != val)
	print("6"..string.format("%07X ", addr)..string.format("%08X", val))
end
function d2()
	print("D2000000 00000000")
end

--ARMの機械語を生成
function read_ELF(addr, path, arr)	--ELFを読み込む
	local data = read_file_bytes(path)
	if data == nil then
		return nil
	end

	--readelfを使って解析
	local readelf_data = execute_cmd([[llvm-readelf -S -r ]]..path)

	local section_text_offset = 0
	local section_text_size = 0
	local rel_text_symbol_text = {}
	local rel_text_symbol_bss = {}

	local rel = {}
	
	local cond = ""
	split(readelf_data, "\r\n", function(row)
		if string.sub(row, string.len(row)) == ":" then	--タイトルを判別
			if row == "Section Headers:" then
				cond = "Section Headers"
			elseif string.find(row, "Relocation section '.rel.text'") ~= nil then
				cond = ".rel.text"
			else
				cond = ""
			end
		elseif cond == "Section Headers" then
			local fields = split(string.gsub(row, "%[", ""), " ")
			if fields[2] == ".text" then
				section_text_offset = tonumber(fields[5], 16)
				section_text_size = tonumber(fields[6], 16)
			end
		elseif cond == ".rel.text" then
			local fields = split(row, " ")
			if fields[5] == ".text" then
				table.insert(rel_text_symbol_text, tonumber(fields[1], 16))
			elseif fields[5] == ".bss" then
				table.insert(rel_text_symbol_bss, tonumber(fields[1], 16))
			else
				rel[fields[5]] = tonumber(fields[1], 16)
				print(fields[5])
			end
		end
	end)

	--コードの部分を読み込む
	local codes = {}
	for i=1, section_text_size, 4 do
		codes[#codes+1] = 
		string.byte(data, i + section_text_offset) +
		string.byte(data, i + 1 + section_text_offset) * 0x100 +
		string.byte(data, i + 2 + section_text_offset) * 0x10000 +
		string.byte(data, i + 3 + section_text_offset) * 0x1000000
	end
	--再配置
	for i=1, #rel_text_symbol_text do
		local n = rel_text_symbol_text[i] / 4 + 1
		codes[n] = codes[n] + addr
	end
	if arr ~= nil then
		for i=1, #arr do
			codes[#codes + 1] = arr[i]
		end
	end
	for i=1, #rel_text_symbol_bss do
		local n = rel_text_symbol_bss[i] / 4 + 1
		codes[n] = codes[n] + addr + #codes*4
	end

	codes.size = section_text_size
	codes.rel = rel
	return codes
end
function jump(addr, target)	--ジャンプ処理を返す
	return tonumber("EA"..string.sub(string.format("%08X", (target - addr - 8) / 4), 3), 16)
end
function call(addr, target)	--関数呼び出し処理を返す
	return tonumber("EB"..string.sub(string.format("%08X", (target - addr - 8) / 4), 3), 16)
end
nop = 0xE1A00000 --nop(mov r0,r0)
ret = 0xE12FFF1E --bx r14


function show()
	for i=0x02090D48, 0x02090E3C, 4 do
		--memory.writedword(i, 0)
	end
	memory.writedword(0x02090D48, ret)


	--コンパイル
	--os.execute([[clang -target armv5-none-none-eabi -c show.c -o show.o -Oz & pause]])
	os.execute([[clang -target armv5-none-none-eabi -c show.c -o show.o & pause]])


	local copyAddr = 0x02090D48	--コードのコピー先(残機表示関数)

	local codes = read_ELF(copyAddr, "show.o")
	if codes == nil then
		return
	end


	table.remove(codes, 1)
	table.remove(codes, 1)
	table.remove(codes, 1)
	table.remove(codes, 1)
	table.remove(codes, 1)

	table.remove(codes, #codes)
	table.remove(codes, #codes)

	local draw = 0x0200FE64;	--描画の関数
	local number_images_addr = 0x021e2668;
	codes[#codes + 1] = number_images_addr

	local numbers_loop = 0
	local divide_loop = 0
	local digit_loop = 0
	local dd = 0

	for i=1, #codes do
		--if codes[i] == 0xE59F80C0 then
		--	print(string.format("%08X", (#codes - i - 2) * 4))
		--end

		--if codes[i] == 0xE3A050D0 then
		--	codes[i] = 0xE3A05000 + (#codes - i) * 4	--次の行で使う
		--	print("show_numbers = "..string.format("%08X", codes[i]))
		--end

		if codes[i] == 0xE1A00000 then
			codes[i] = call(copyAddr + (i-1) * 4, draw)
		end

		if codes[i] == 0xE79F6005 then
			numbers_loop = i
		elseif codes[i] == 0x11A01001 then
			codes[i] = jump(i * 4, numbers_loop * 4) - 0xE0000000 + 0x10000000
		end

		if codes[i] == 0xE1560007 then
			divide_loop = i
		elseif codes[i] == 0x21A00000 then
			codes[i] = jump(i * 4, divide_loop * 4) - 0xE0000000 + 0x20000000
		end

		if codes[i] == 0xE0070997 then
			digit_loop = i
		elseif codes[i] == 0x11A00000 then
			codes[i] = jump(i * 4, digit_loop * 4) - 0xE0000000 + 0x10000000
		end

		if codes[i] == 0xE1560007 then
			dd = i
		elseif codes[i] == 0x21A01001 then
			codes[i] = jump(i * 4, dd * 4) - 0xE0000000 + 0x20000000
		end
	end



	print("show_numbers = "..string.format("%08X", copyAddr + #codes * 4))



	if_eq(copyAddr, 0xE92D41F0)

	patch(copyAddr, codes)

	d2()





	--スコア・ゴールドを消す
	copyAddr = 0x020904C8
	if_eq(copyAddr, 0xE92D4FF8)
	writedword(copyAddr, ret)
	d2()

	--タイマーを消す
	copyAddr = 0x020905A4
	if_eq(copyAddr, 0xE92D41F0)
	writedword(copyAddr, ret)
	d2()

	--vs～を消す
	copyAddr = 0x0208E7E4
	if_eq(copyAddr, 0xE59010C8)
	writedword(copyAddr, 0xE3A01000)	--ldr r1, [r0, #C8]	->	mov r1, 0
	d2()

end

function QSQL()
	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c QSQL.c -o QSQL.o -O3 & pause]])

	local copyAddr = 0x023FE000	--コードのコピー先

	local codes = read_ELF(copyAddr, "QSQL.o", {0, 0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C})
	if codes == nil then
		return
	end

	local n = codes.rel["RoMK_positions"] / 4 + 1
	codes[n] = codes[n] + copyAddr + codes.size

	--割り込ませる処理
	if_eq(copyAddr, 0)

	for i=1, #codes do
		local n = codes[i] - (codes[i] % 0x2000)
		if n == 0xE92D4000 then
			codes[i] = 0xE92D5FFE	--レジスタの退避
		elseif n == 0xE8BD8000 then
			codes[i] = jump(copyAddr + (i-1) * 4, 0x020017C8)	--元のコードへのジャンプ
		end
	end

	patch(copyAddr, codes)

	d2()



	--ボタン入力処理に割り込ませる
	if_eq(0x020017C0, 0xE3540000)

	patch(0x020017C0, {
		0xE0220000,	--:020017C0 E3540000 cmp r4,#0x0	->	E0220000 eor r0,r2,r0
		jump(0x020017C4, copyAddr),	--:020017C4 eor r0,r2,r0	->	b copyAddr	;割り込ませる処理へのジャンプ
		0xE8BD5FFE,	--:020017C8	and  r0,r0,r4	->	ldmia  r13!,{r1-r12, lr}	;レジスタの復元
		0xE3540000	--:020017CC	strh r0,[r1, #+0xe8]		->	E3540000 cmp r4,#0x0
	})

	d2()
end

QSQL()


