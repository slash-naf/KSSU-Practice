local ar = require("ActionReplay")

local ram = ar.allocateRam(0x022E0000, 0x022E1000, 0x022E8000)
local cheats = {}

-- QSQL モジュール
local qsqlMod = ram:createModule("QSQL.c")
	:hook("QS", 0x02001830, 0xE8BD8010, 0xE8BD8010)	--ボタン入力処理の関数のreturnにフック
	:hook("QL", 0x02074ED8, 0xE92D4008)	--ロードの進行状況の読み取りの直前にフック
	:hook("MixStep", 0x02111E68, 0xE2411001)	--mix_cntのカウントアップ
local QSQL = ar.newCode():import(qsqlMod)

--格闘王系モードでの下画面のボスの表示を通常時に切り替える処理の、ゲームモードに応じたリソースをロードする処理を上書き
QSQL:override(qsqlMod.symbols["ArenaImageSwitcher"], 0x0206CE20, 0xE3500007, 0x0206CF68)

--Freeze RoMK Timer
QSQL:if_eq(0x0206B6A0, 0xA2400C21)
:write32(0x0206B6A4, 0xE1A00000)
:write32(0x0206B6BC, 0xE1A00000)
:end_if()

--数値描画
QSQL:redirect(qsqlMod.symbols["DrawNumbers"], 0x02090D48, 0xE92D41F0)
--スコア・ゴールドを消す
QSQL:disable(0x020904C8, 0xE92D4FF8)
--タイマーを消す
QSQL:disable(0x020905A4, 0xE92D41F0)
--vs～を消す
QSQL:if_eq(0x0208E7E4, 0xE59010C8)
:write32(0x0208E7E4, 0xE3A01000)	--ldr r1, [r0, #C8]	->	mov r1, 0
:end_if()


print(QSQL:toString("QSQL"))
table.insert(cheats, QSQL)


-- 乱数監視 (Monitor RNG)
local seedMod = ram:createModule("seed_advances.c")
	:hook("AddFromAdvanceSeed", 0x0200B88C, 0xE58204A4)	--定期乱数進み時に加算
	:hook("AddFromRandi", 0x0200B8D0, 0xE58314A4)	--randi時に加算(8F周期を除外)
	:hook("UpdateRNG", 0x020B5804, 0xEA000006, 0x020B5824)	--ポピーブロスJr.自爆タイマー設定時に表示更新
local MonitorRNG = ar.newCode():import(seedMod)

--QL時に乱数カウンタをリセットするようにポインタを設定
MonitorRNG:write32(qsqlMod.symbols["p_seed_advances"], seedMod.symbols["advances"])
--表示先をQSQLのshow配列に設定
MonitorRNG:write32(seedMod.symbols["p_show"], qsqlMod.symbols["show"])


print(MonitorRNG:toString("Monitor RNG"))
table.insert(cheats, MonitorRNG)


-- 特定乱数の検知チート群 (各呼び出し地点ごとに分割)
local function set_randi(addr, title)
	local code = ar.newCode():replaceCall(addr, 0x0200B8A4, seedMod.symbols["RandiWithUpdate"])
	print(code:toString(title))
	table.insert(cheats, code)
	return code
end

set_randi(0x020C42A0, "Impact Star")
set_randi(0x020C5E4C, "Invincibility Star")
set_randi(0x0210B578, "Losing Ability")
set_randi(0x0216FC84, "Defeated Enemy Effect")
set_randi(0x020947D0, "Food Star")

set_randi(0x021A743C, "Whale Rolls or Splashes")
set_randi(0x021AA818, "Windows Attacks First")
set_randi(0x021A4D50, "Windows Copy Essences")
set_randi(0x021A89BC, "Windows Moves")

set_randi(0x021A40FC, "Lobster Walks or Dashes")
set_randi(0x021A41DC, "Lobster Jumps or Glides")


gui.register(function()
	for _, c in ipairs(cheats) do
		c:exec()
	end
end)
