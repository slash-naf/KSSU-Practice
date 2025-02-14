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
	
	-- ファイルサイズ取得
	local cur = file:seek()
	local size = file:seek("end")
	file:seek("set", cur)

	-- 全読込み
	local data = file:read("*all")
	file:close()

	return data
end


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

		memory.writedword(addr + i * 4, x)
		print(string.format("%08X ", a[i])..string.format("%08X", x))

	end
end


function read_ELF(addr, path)	--ELFを読み込む
	--readelfを使って解析
	local readelf_data = execute_cmd([[llvm-readelf -S -r ]]..path)

	local section_text_offset = 0
	local section_text_size = 0
	local rel_text_symbol_text = {}
	local rel_text_symbol_bss = {}
	
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
			end
		end
	end)

	--コードの部分を読み込む
	local data = read_file_bytes(path)
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
	for i=1, #rel_text_symbol_bss do
		local n = rel_text_symbol_bss[i] / 4 + 1
		codes[n] = codes[n] + addr + section_text_size
	end

	return codes
end
function jump(addr, target)	--ジャンプ処理を返す
	return tonumber("EA"..string.sub(string.format("%08X", (target - addr - 8) / 4), 3), 16)
end
function call(addr, target)	--関数呼び出し処理を返す
	return tonumber("EB"..string.sub(string.format("%08X", (target - addr - 8) / 4), 3), 16)
end

--コンパイル
os.execute([[clang -target armv5-none-none-eabi -c QSQL.c -o QSQL.o -O3 & pause]])


local copyAddr = 0x023FE000	--コードのコピー先

--割り込ませる処理
print("5"..string.format("%07X ", copyAddr).."00000000")

local codes = read_ELF(copyAddr, "QSQL.o")

for i=1, #codes do
	local n = codes[i] - (codes[i] % 0x2000)
	if n == 0xE92D4000 then
		codes[i] = 0xE92D5FFE	--レジスタの退避
	elseif n == 0xE8BD8000 then
		codes[i] = jump(copyAddr + (i-1) * 4, 0x020017C8)	--元のコードへのジャンプ
	end
end

patch(copyAddr, codes)

print("D2000000 00000000")



--ボタン入力処理に割り込ませる
print("520017C0 E3540000")

patch(0x020017C0, {
	0xE0220000,	--:020017C0 E3540000 cmp r4,#0x0	->	E0220000 eor r0,r2,r0
	jump(0x020017C4, copyAddr),	--:020017C4 eor r0,r2,r0	->	b copyAddr	;割り込ませる処理へのジャンプ
	0xE8BD5FFE,	--:020017C8	and  r0,r0,r4	->	ldmia  r13!,{r1-r12, lr}	;レジスタの復元
	0xE3540000	--:020017CC	strh r0,[r1, #+0xe8]		->	E3540000 cmp r4,#0x0
})

print("D2000000 00000000")

