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
		local n = binDword(data, i)
		local varPtrAddr
		while true do
			i = i + 4
			local nextVal = binDword(data, i)

			if n == 0 then
				if nextVal == 1 then
					--グローバル変数のアドレスを設定
					if varPtrAddr == nil then
						add(copyAddr + 4)
					else
						set(varPtrAddr, copyAddr)
					end
					break
				else
					varPtrAddr = copyAddr
					copyAddr = copyAddr + 4
				end
			else
				add(n)
			end

			n = nextVal
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

--処理を割り込ませるために潰した処理を行う
add(0xE0220000)	--eor  r0,r2,r0
add(0xE0000004)	--and  r0,r0,r4
add(0xE1C10EB8)	--strh r0,[r1, #+0xe8]

--押されたボタンの情報が引数になった状態で関数に入る
OToAR("QSQL.o")



print(ar)



