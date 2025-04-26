
offset = 0
--メモリ書き込みとそのコードの出力
function write(addr, n)
	if bit.rshift(addr, 28) > 2 then
		error("byte lengths error; write("..addr..", "..n..")")
	end

	addr = bit.band(addr - offset, 0xFFFFFFFF)
	print(string.format("%08X ", addr)..string.format("%08X", n))
end
--配列で一括書き込み
function patch(addr, a)
	addr = bit.band(addr - offset, 0xFFFFFFFF)
	local size = #a * 4
	print("E"..string.format("%07X ", addr)..string.format("%08X", size))

	for i=1, #a, 2 do
		local x = a[i+1] or 0
		print(string.format("%08X ", a[i])..string.format("%08X", x))
	end
end
--メモリのコピー。1,2,4バイトの場合は加算もできる
function copy(n_addr, d_addr, m)
	len = bit.rshift(n_addr, 28)
	if len ~= bit.rshift(d_addr, 28) then
		error("different byte lengths")
	end
	n_addr = bit.band(n, 0xFFFFFFF)
	d_addr = bit.band(d, 0xFFFFFFF)

	if len < 3 then
		n_addr = string.format("%08X", bit.band(n_addr - offset, 0xFFFFFFFF))
		d_addr = string.format("%08X", bit.band(d_addr - offset, 0xFFFFFFFF))
		if m == nil then
			m = ""
		else
			m = "\nD4000000 "..string.format("%08X", bit.band(m, 0xFFFFFFFF))
		end

		if len == 0 then
			print("D9000000 "..n_addr..m)
			print("D6000000 "..d_addr)
			offset = offset + 4
		elseif len == 1 then
			print("DA000000 "..n_addr..m)
			print("D7000000 "..d_addr)
			offset = offset + 2
		elseif len == 2 then
			print("DA000000 "..n_addr..m)	--Action Replay DSではDBコードにバグあるらしいからDAを使う
			print("D8000000 "..d_addr)
			offset = offset + 1
		end
	else
		if offset ~= n_addr then
			offset = n_addr;
			print("D3000000 "..string.format("%08X", n_addr))
		end

		print("F"..string.format("%07X ", d_addr)..string.format("%08X", len))
	end
end
--条件分岐
function cmp(ins, addr, n, mask)	
	t = bit.rshift(addr, 28)
	local is_even = addr % 2 == 0
	addr = string.format("%07X ", bit.band(addr, 0xFFFFFFE))
	n = bit.band(n, 0xFFFFFFFF)

	if t == 0 then
		print( string.format("%01X", ins)..addr..string.format("%08X", n) )
	else
		ins = string.format("%01X", ins + 4)
		mask = bit.band(bit.bnot(mask or 0xFFFF), 0xFFFF)

		if t == 1 then
			mask = string.format("%02X", mask)
			n = string.format("%02X", n)
			if is_even then
				print(ins..addr.. "FF"..mask.. "00"..n)
			else
				print(ins..addr.. mask.."FF".. n.."00")
			end
		else
			print( ins..string.format("%07X ", addr)..string.format("%04X", mask)..string.format("%04X", n) )
		end
	end
end
function lt(addr, n, mask)
	cmp(3, addr, n, mask)
end
function gt(addr, n, mask)
	cmp(4, addr, n, mask)
end
function eq(addr, n, mask)
	cmp(5, addr, n, mask)
end
function ne(addr, n, mask)
	cmp(6, addr, n, mask)
end
function d2()
	offset = 0;
	print("D2000000 00000000");
end

--定数
Button = {
	A      = 0x001,
	B      = 0x002,
	SELECT = 0x004,
	START  = 0x008,
	RIGHT  = 0x010,
	LEFT   = 0x020,
	UP     = 0x040,
	DOWN   = 0x080,
	R      = 0x100,
	L      = 0x200,
	X      = 0x400,
	Y      = 0x800,
}
GameState = {
	STATE_PLAY         = 0,
	STATE_FLOOR_LOAD   = 1,
	STATE_STAGE_CLEAR  = 2,
	STATE_GAME_CLEAR   = 3,
	STATE_DIE          = 4,
	STATE_SPECIAL      = 5,
	STATE_ARENA_PROCEED= 5,
	STATE_MAP          = 6,
	STATE_ARENA_MATCH  = 6,
	STATE_SWITCH       = 7,
	STATE_SHORT_MOVIE  = 9,
	STATE_PAUSE        = 0xB,
}
GameMode = {
	SPRING_BREEZE = 0,
	DYNA_BLADE    = 1,
	GOURMET_RACE  = 2,
	GCO           = 3,
	RoMK          = 4,
	MWW           = 5,
	RotK          = 6,
	THE_ARENA     = 7,
	MKU           = 8,
	HELPER_TO_HERO= 9,
	THE_TRUE_ARENA= 0xA,
	BEGINNERS_ROOM= 0xB,
}
Music = {
	Music_MUTE = 0xFFFFFC19,
}
Ability = {
	NORMAL  = 1,
	CUTTER  = 2,
	MIRROR  = 3,
	BEAM    = 4,
	FIGHTER = 5,
	SUPLEX  = 6,
	YOYO    = 7,
	WHEEL   = 8,
	BOMB    = 9,
	ICE     = 0xA,
	FIRE    = 0xB,
	PLASMA  = 0xC,
	NINJA   = 0xD,
	STONE   = 0xE,
	WING    = 0xF,
	JET     = 0x10,
	COPY    = 0x11,
	HAMMER  = 0x12,
	SWORD   = 0x13,
	PARASOL = 0x14,
	PAINT   = 0x15,
	MIKE    = 0x16,
	CRASH   = 0x17,
	COOK    = 0x18,
	SLEEP   = 0x19,
}

--メモリ
held_buttons = 0x12041e64
pressed_buttons = 0x12041e68

seed  = 0x02041D3C	--乱数
timer = 0x02041D60	--タイマー

music = 0x020485C4	--曲。0xFFFFFC19がミュートだけどフロア遷移時に入れても曲が最初からになるだけ

gameStates=  0x0205B244
gameState = 0x2205B244
gameMode  = 0x2205B245
stage     = 0x2205B246
room      = 0x2205B247

playerMode = 0x0205B248	--ワープスターに乗っているかやゴールゲーム中かなど
setPos      = 0x0205B24C	--フロア遷移時の初期座標の設定

consumedItems = 0x0205B270	--キャンディや1upなどの復活しないアイテムが取られるとこのアドレスから列挙されていく。0を入れれば復活

score =  0x0205B3C0	--スコア
lives = 0x2205B3C4	--残機
mkuPt = 0x2205B3C5	--MKUのPt

db_switches = 0x2206BDEA	--ダイナのスイッチを押したか。1ビット目が「おためし部屋１」、2ビット目が「おためし部屋２」。0を入れればスイッチ復活

gco_treasures    = 0x0206E100	--洞窟のお宝を取得済みか60ビットで記録される。0でリセット
gco_gold         = 0x0206E108	--洞窟のゴールド
gco_bosses       =0x2206E10E	--ボスを倒したか
gco_treasuresCnt =0x2206E112	--お宝所持数

arena_idx = 0x2206FC62	--格闘王系で何戦目か
arena_bosses = 0x2206FC66	--格闘王系でのボスの並びが記憶されている配列

mww_abilities               =  0x02070A40	--銀河の開放済み能力
mww_abilitiesByStage        = 0x22070A47	--ステージごとの開放済み能力の数を記憶した長さ8の配列
mww_selectedAbility         = 0x22070A5C	--銀河の選択能力。能力自体の値とは別
mww_changingSelectedAbility = 0x22070A5E	--選択能力が遷移中なら1

getPos = 0x02076878	--1Pの座標

playerHP    = 0x22076A94	--1PのHP
playerMaxHP = 0x22076A96	--1Pの最大HP
helperHP    = 0x22076CD8	--2PのHP
helperMaxHP = 0x22076CDA	--2Pの最大HP

displayMode = 0x0209ECC4	--スコア・ゴールドの所に何が表示されるか。0ならスコア・ゴールドを表示

playerStates = 0x020BA318	--1Pの能力・状態
playerAbility = 0x220BA31B	--1Pの能力
playerRiding =0x220BA31D	--ウィリーライダーなら2
playerInvincibility = 0x120BA5CC	--1Pのむてきキャンディ/1Pと2pのメタクイックの残り時間

helperStates = 0x020BAB34	--2Pの能力・状態
helperRode   =0x220BAB39	--ウィリーライダーなら2
helperInvincibility = 0x120BADE8	--2Pのむてきキャンディの残り時間。メタクイックは1Pのが参照され、こっちは使われない

menuPageIdx =0x221983CA	--ポーズのメニューのページ番号


--処理

--キャンディや1upなどの復活しないアイテムを復活させる
write(consumedItems, 0)




