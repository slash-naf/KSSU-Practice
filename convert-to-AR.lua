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




--バイナリファイルのデータから4byte読み込み
function binDword(s, i)
	return string.byte(s, i+1) +
	string.byte(s, i+2) * 0x100 +
	string.byte(s, i+3) * 0x10000 +
	string.byte(s, i+4) * 0x1000000
end

function set(addr, n)	--メモリ4byte書き込み
	memory.writedword(addr, n)
	print("0"..string.format("%07X ", addr)..string.format("%08X", n))
end

function call(addr, target)	--関数呼び出し処理を返す
	return 0xEB000000 + (target - addr - 8) / 4
end

function patch(addr, a)	--Eコードで addr から 配列 a を一括書き込み
	local size = #a * 4
	print("E"..string.format("%07X ", addr)..string.format("%08X", size))

	for i=1, #a, 2 do
		memory.writedword(addr + (i-1) * 4, a[i])

		local x = a[i+1]
		if x == nil then
			x = 0
		end

		memory.writedword(addr + i * 4, x)
		print(string.format("%08X ", a[i])..string.format("%08X", x))

	end
end

function patchFromFile(addr, path)
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

	patch(addr, codes)
end

copyAddr = 0x023FE000	--プログラムのコピー先

--関数を書く
print("5"..string.format("%07X ", copyAddr).."00000000")
patchFromFile(copyAddr ,"QSQL.o")
print("D2000000 00000000")

--ボタン入力処理に割り込ませる


print("520017C0 E3540000")

patch(0x020017C0, {
	0xE92D5FFE,	--020017C0:	cmp r4,#0x0	->	stmdb  r13!,{r1-r12, lr}	;レジスタの退避
	call(0x020017C4, copyAddr),	--020017C4:	eor  r0,r2,r0	->	bl copyAddr	;関数呼び出し
	0xE8BD5FFE,	--020017C8:	and  r0,r0,r4	->	ldmia  r13!,{r1-r12, lr}	;レジスタの復元
	0xE3540000	--020017CC:	strh r0,[r1, #+0xe8]	->	cmp r4,#0x0
})

print("D2000000 00000000")



