copyAddr = 0x023FE000	--プログラムのコピー先
ar = ""	--ARコードを入れる

--バイナリファイルのデータから4byte読み込み
function binDword(s, i)
	return string.byte(s, i+1) +
	string.byte(s, i+2) * 0x100 +
	string.byte(s, i+3) * 0x10000 +
	string.byte(s, i+4) * 0x1000000
end

function set(addr, n)	--メモリ4byte書き込み
	memory.writedword(addr, n)
	ar = ar.."0"..string.format("%07X ", addr)..string.format("%08X", n).."\r\n"
end

function call(addr, target)	--関数呼び出し処理を書き込み
	set(addr, 0xEB000000 + (target - addr - 8)/4)
end

function add(n)	--処理を書き込み次のアドレスにずらす
	set(copyAddr, n)
	copyAddr = copyAddr + 4
end

function OToAR(path)	--オブジェクトファイルを読み込んで処理を書き込み
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

		local varAddr = #a * 4 + copyAddr

		for i=1, #a do
			if a[i] == 0 then
				print("0:"..string.format("%08X ", copyAddr))
				add(varAddr+a[i])
			elseif a[i] < 0x400 then
				print("1:"..string.format("%08X ", copyAddr))
				add(a[i]+0x023FE000)
			else
				add(a[i])
			end
		end

	else
		ar = ar.."ファイル無い\r\n"
	end
end


--ボタン入力処理に割り込ませる
set(0x020017C0, 0xE92D5FFE)	--cmp r4,#0x0	->	stmdb  r13!,{r1-r12, lr}	;レジスタの退避
call(0x020017C4, copyAddr)	--eor  r0,r2,r0	->	bl copyAddr	;関数呼び出し
set(0x020017C8, 0xE8BD5FFE)	--and  r0,r0,r4	->	ldmia  r13!,{r1-r12, lr}	;レジスタの復元
set(0x020017CC, 0xE3540000)	--strh r0,[r1, #+0xe8]	->	cmp r4,#0x0

print("520017C0 E3540000")
print(ar)
print("D2000000 00000000")

ar = ""

--押されたボタンの情報が引数になった状態で関数に入る
OToAR("QSQL.o")


print("523FE000 00000000")
print(ar)
print("D2000000 00000000")



