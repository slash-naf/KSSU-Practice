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
function read_ELF(addr, path, bss_addr)	--ELFを読み込む
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
	if bss_addr == nil then
		bss_addr = addr + #codes*4
	end
	for i=1, #rel_text_symbol_bss do
		local n = rel_text_symbol_bss[i] / 4 + 1
		codes[n] = codes[n] + bss_addr
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
	local bssAddr = 0x023FDF00	--変数のアドレス

	local codes = read_ELF(copyAddr, "QSQL.o", bssAddr)
	if codes == nil then
		return
	end

	local RoMK_positions = {0x00690034, 0x008102F4, 0x0099051E, 0x00180030, 0x002400D4, 0x009C002C}
	for i=#RoMK_positions, 1, -1 do
		codes[#codes+1] = RoMK_positions[i]
	end
	local n = codes.rel["RoMK_positions"] / 4 + 1
	codes[n] = codes[n] + copyAddr + codes.size + 4 * #RoMK_positions

	--割り込ませる処理
	if_eq(copyAddr, 0)

	for i=1, #codes do
		local n = (codes[i] % 0x10000000) - (codes[i] % 0x2000)
		local cond = codes[i] - (codes[i] % 0x10000000)

		if n == 0x092D4000 then	--stmdb sp!, {lr}
			--print(string.format("%04X\t", (i-1)*4) .. string.format("%08X", codes[i]))

			codes[i] = 0x092D5FFE + cond	--stmdb sp!, {r1-r12, lr}	レジスタの退避

		elseif n == 0x08BD8000 then	--ldmia sp!, {pc}	レジスタの復元とリターン
			--print(string.format("%04X\t", (i-1)*4) .. string.format("%08X", codes[i]))

			codes[i] = jump(copyAddr + (i-1) * 4, 0x020017C8) - 0xE0000000 + cond	--元のコードへのジャンプ

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

function seed_advances()

	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c seed_advances.c -o seed_advances.o -O3 & pause]])

	local copyAddr = 0x023FE5A4	--コードのコピー先

	local codes = read_ELF(copyAddr, "seed_advances.o", bssAddr)
	if codes == nil then
		return
	end

	codes[#codes+1] = 0x02041D3C	--seed
	codes[#codes+1] = 0x02090DD8	--show

	local add_from_advance_seed = copyAddr
	local add_from_randi = 0
	local update_func = 0

	for i=1, #codes do
		if codes[i] == 0x01A00000 then	--moveq r0, r0	->	b
			codes[i] = jump(0, 0x14) - 0xE0000000

		elseif i < #codes - 5 and codes[i] == ret then
			if add_from_randi == 0 then
				add_from_randi = copyAddr + i*4
			elseif update_func == 0 then
				update_func = copyAddr + i*4
			end

		else
			local n = codes[i] - codes[i] % 0x10000
			if n == 0xE15F0000 or n == 0xE14F0000 then
				n = codes[i] % 0x1000

				if n == 0x1B4 then	--seed_advances = (short*)0x023FE57C;
					local ofs = (copyAddr + i*4 + 4) - 0x023FE57C
					local a = ofs % 0x10
					codes[i] = codes[i] - n + (ofs - a) * 0x10 + 0x0b0 + a
				elseif n == 0x1B2 then	--narrowed_seed_advances = (short*)0x023FE57E;
					local ofs = (copyAddr + i*4 + 4) - 0x023FE57E
					local a = ofs % 0x10
					codes[i] = codes[i] - n + (ofs - a) * 0x10 + 0x0b0 + a
				end
			end
		end
	end
	
	--print(string.format("%08X", update_func))
	local copyAddr2 = 0x023FE580
	local codes2 = {}

	local randi_func = 0x0200B8A4
	local stmdb = 0xE92D41F0	--stmdb sp!, {r4-r8,lr}
	local ldmia = 0xE8BD41F0	--ldmia sp!, {r4-r8,lr}


	local randi_with_update = copyAddr2

	codes2[#codes2+1] = stmdb
	codes2[#codes2+1] = call(copyAddr2 + #codes2*4, randi_func)
	codes2[#codes2+1] = call(copyAddr2 + #codes2*4, update_func)
	codes2[#codes2+1] = ldmia
	codes2[#codes2+1] = ret

	local update_on_setting_destruction_timer = copyAddr2 + #codes2 * 4

	codes2[#codes2+1] = stmdb
	codes2[#codes2+1] = call(copyAddr2 + #codes2*4, update_func)
	codes2[#codes2+1] = ldmia
	codes2[#codes2+1] = jump(copyAddr2 + #codes2*4, 0x020b5824)

	for i=1, #codes do
		codes2[#codes2+1] = codes[i]
	end




	--割り込ませる処理
	if_eq(copyAddr2, 0)

	patch(copyAddr2, codes2)

	d2()

	local addr = 0

	--
	addr = 0x0200B88C
	if_eq(addr, 0xE58204A4)
	writedword(addr, jump(addr, add_from_advance_seed))
	d2()

	--
	addr = 0x0200B8D0
	if_eq(addr, 0xE58314A4)
	writedword(addr, jump(addr, add_from_randi))
	d2()

	--update_on_setting_destruction_timer
	addr = 0x020B5804
	if_eq(addr, 0xEA000006)
	writedword(addr, jump(addr, update_on_setting_destruction_timer))
	d2()

end

function set_randi(addr, title)
	local s = function()
		print("["..title.."]")

		local randi_func = 0x0200B8A4
		local randi_with_update = 0x023FE580
	
		if_eq(addr, call(addr, randi_func))
		writedword(addr,  call(addr, randi_with_update))
		d2()
	
		print("")
	end

	s(0x020c42a0, "Impact Star")
	s(0x020c5e4c, "Invincibility Star")
	s(0x0210b578, "Losing Ability")
	s(0x0216fc84, "Defeated Enemy Effect")
	s(0x020947d0, "Food Star")

	s(0x021a743c, "Whale Rolls or Splashes")
	s(0x021aa818, "Windows Attacks First")
	s(0x021a4d50, "Windows Copy Essences")
	s(0x021a89bc, "Windows Moves")

	s(0x021a40fc, "Lobster Walks or Dashes")
	s(0x021a41dc, "Lobster Jumps or Glides")

end

function showForDSTT()
	for i=0x02090D48, 0x02090E3C, 4 do
		--memory.writedword(i, 0)
	end
	memory.writedword(0x02090D48, ret)


	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c for_DSTT\show.c -o for_DSTT\show.o & pause]])


	local copyAddr = 0x02090D48	--コードのコピー先(残機表示関数)

	local codes = read_ELF(copyAddr, [[for_DSTT\show.o]])
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

		if codes[i] == 0xE0070597 then
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
end

function mix_view()
	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c mix_view.c -o mix_view.o -Oz & pause]])

	local copyAddr = 0x023FE680	--コードのコピー先

	local codes = read_ELF(copyAddr, "mix_view.o")
	if codes == nil then
		return
	end

	copyAddr2 = copyAddr + 0x1C

	codes[7] = jump(copyAddr + 4*6, 0x02111E6C)

	tmpcode = codes[8]
	codes[8] = codes[9]
	codes[9] = tmpcode

	for i=1, #codes do
		if codes[i] == ret then
			codes[i] = jump(copyAddr + 4*(i-1), 0x02071764)
		end
	end


	if_eq(copyAddr, 0)
	patch(copyAddr, codes)
	d2()

	local addr = 0

	--割り込ませる
	addr = 0x02111E68
	if_eq(addr, 0xE2411001)
	writedword(addr, jump(addr, copyAddr))
	d2()

	addr = 0x02071734
	if_eq(addr, 0xEA00000A)
	writedword(addr, jump(addr, copyAddr2))
	d2()

end


function input_log()
	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c input_log.c -o input_log.o -O3 & pause]])


	
	local copyAddr = 0x023FE700	--コードのコピー先
	local bssAddr = 0x023FDF80	--変数のアドレス

	local codes = read_ELF(copyAddr, "input_log.o")
	if codes == nil then
		return
	end


	table.insert(codes, 1, 0xE0000004)


	for i=1, #codes do
		local c = bit.band(codes[i], 0xF0000000)
		local n = bit.band(codes[i], 0x0FFFF000)
		if n == 0x08BD8000 then
			codes[i] = c + 0x08BD801F
		elseif n == 0x092D4000 then
			codes[i] = c + 0x092D401F
		elseif codes[i] == 0 then
			codes[i] = bssAddr
		end
	end




	if_eq(copyAddr, 0)
	patch(copyAddr, codes)
	d2()

	--割り込ませる
	addr = 0x023FE00C
	if_eq(addr, 0xE0000004)
	writedword(addr, call(addr, copyAddr))
	d2()

end

function log_dump()
	--コンパイル
	os.execute([[clang -target armv5-none-none-eabi -c log_dump.c -o log_dump.o -O3 & pause]])
	
	local copyAddr = 0x023FDFA0	--コードのコピー先

	local codes = read_ELF(copyAddr, "log_dump.o")
	if codes == nil then
		return
	end



	for i=1, #codes do
		if codes[i] == ret then
			codes[i] = jump(copyAddr + 4*(i-1), 0x02026BF0)
		end
	end




	if_eq(0x023FDF30, 0x06010301)	--水晶の畑のセーブ部屋でQSなら
	print("92041E68 00000004")	--セレクトボタン押したら
	
	patch(copyAddr, codes)

	--割り込ませる
	addr = 0x02026BD4
	writedword(addr, jump(addr, copyAddr))

	--
	print("DA000000 02F00000")
	print("D7000000 02EFFFF8")

	d2()

end


log_dump()