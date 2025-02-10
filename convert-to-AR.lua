
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

	local file = io.open( path, "rb" )
	
	if file ~= nil then
		-- 全読込み
		local data = file:read("*all")
		file:close()

		--プログラムの部分を読込み
		local i = 0x34
		local a = {}
		local val = binDword(data, i)
		i = i + 4
		local nextVal = binDword(data, i)
		while not(val == 0 and nextVal == 1) do
			a[#a+1] = val
			val = nextVal
			i = i + 4
			nextVal = binDword(data, i)
		end
		local varAddr = #a * 4 + addr
		for i=1, #a do
			if a[i] == 0 then
				a[i] = varAddr
			elseif a[i] < 0x400 then
				a[i] = a[i] + addr
			end	
		end

		patch(addr, a)

	else
		print("ファイル無い")
	end
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



