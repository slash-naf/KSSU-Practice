import { fileURLToPath } from "node:url";

import { CodeBuilder, insn, RamAllocator } from "./tools/scripts/ar.ts";
import { Game, type Cheat } from "./tools/scripts/formats/cheat.ts";
import { writeOutputs } from "./tools/scripts/output.ts";

const rootDir = fileURLToPath(new URL(".", import.meta.url));

// ゲーム内アドレス
const Symbols = {
	Randi: 0x0200b8a4,
	GameState: 0x0205b244,
	Buttons: 0x02041e68,
} as const;

// ゲーム内の状態 (GameState)
const STATE = {
	PLAY: 0,
	FLOOR_LOAD: 1,
	STAGE_CLEAR: 2,
	GAME_CLEAR: 3,
	DIE: 4,
	SPECIAL: 5,
	ARENA_PROCEED: 5,
	MAP: 6,
	ARENA_MATCH: 6,
	SWITCH: 7,
	SHORT_MOVIE: 9,
	PAUSE: 0xb,
} as const;

// ボタン入力 (Button)
const BUTTON = {
	A: 0x001,
	B: 0x002,
	SELECT: 0x004,
	START: 0x008,
	RIGHT: 0x010,
	LEFT: 0x020,
	UP: 0x040,
	DOWN: 0x080,
	R: 0x100,
	L: 0x200,
	X: 0x400,
	Y: 0x800,
} as const;

/** 星のカービィ ウルトラスーパーデラックス (日本版) のチート一式を組み立てる */
function createKirbyCheats(): Cheat[] {
	const ram = new RamAllocator(rootDir, 0x022c0000, 0x022c2000, 0x02368000);

	// Mute (v3.3 の dct / usrcheat.dat に合わせて追加。Lua 実行時には適用しない)
	const mute = new CodeBuilder((code) => code.write8(0x0205e76c, 0));

	// QSQL
	const qsql = new CodeBuilder(
		(code) => {
			// 格闘王系モードでの下画面のボスの表示を通常時に切り替える処理の、
			// ゲームモードに応じたリソースをロードする処理を上書き
			code.override(code.sym("ArenaImageSwitcher"), {
				at: 0x0206ce20,
				expected: insn(0xe3500007, "cmp r0, #7"),
				resumeAt: 0x0206cf68,
			});

			// Freeze RoMK Timer
			code
				.ifEq32(0x0206b6a0, 0xa2400c21)
				.write32(0x0206b6a4, 0xe1a00000)
				.write32(0x0206b6bc, 0xe1a00000)
				.endAllIf();

			// 数値描画
			code.redirectFunction(code.sym("DrawNumbers"), {
				at: 0x02090d48,
				expected: insn(0xe92d41f0, "stmdb sp!, {r4-r8, lr}"),
			});
			// スコア・ゴールドを消す
			code.disableFunction({
				at: 0x020904c8,
				expected: insn(0xe92d4ff8, "stmdb sp!, {r3-r11, lr}"),
			});
			// タイマーを消す
			code.disableFunction({
				at: 0x020905a4,
				expected: insn(0xe92d41f0, "stmdb sp!, {r4-r8, lr}"),
			});
			// vs～を消す
			code
				.ifEq32(0x0208e7e4, 0xe59010c8)
				.write32(0x0208e7e4, 0xe3a01000) // ldr r1, [r0, #C8] -> mov r1, 0
				.endAllIf();
		},
		ram.createModule("QSQL.c", [
			{
				// ボタン入力処理の関数の return にフック
				symbol: "QS",
				at: 0x02001830,
				expected: insn(0xe8bd8010, "ldmia sp!, {r4, pc}"),
				returnWith: insn(0xe8bd8010, "ldmia sp!, {r4, pc}"),
			},
			{
				// ロードの進行状況の読み取りの直前にフック
				symbol: "QL",
				at: 0x02074ed8,
				expected: insn(0xe92d4008, "stmdb sp!, {r3, lr}"),
			},
			{
				// mix_cnt のカウントアップ
				symbol: "MixStep",
				at: 0x02111e68,
				expected: insn(0xe2411001, "sub r1, r1, #1"),
			},
		]),
	);

	// 乱数監視 (Monitor RNG)
	const monitorRng = new CodeBuilder(
		(code) => {
			// QL 時に乱数リセット関数を呼び出すように関数ポインタを設定
			code.write32(qsql.sym("p_reset_rng"), code.sym("ResetRNG"));
			// 表示先を QSQL の show 配列に設定
			code.write32(code.sym("p_show"), qsql.sym("show"));
		},
		ram.createModule("seed_advances.c", [
			{
				// 定期乱数進み時に加算
				symbol: "AddFromAdvanceSeed",
				at: 0x0200b88c,
				expected: insn(0xe58204a4, "str r0, [r2, #0x4a4]"),
			},
			{
				// randi 時に加算 (8F周期を除外)
				symbol: "AddFromRandi",
				at: 0x0200b8d0,
				expected: insn(0xe58314a4, "str r1, [r3, #0x4a4]"),
			},
			{
				// ポピーブロスJr.自爆タイマー設定時に表示更新
				symbol: "UpdateRNG",
				at: 0x020b5804,
				expected: insn(0xea000006, "b ..."),
				resumeAt: 0x020b5824,
			},
		]),
	);

	// ログ出力 (Log Dump)
	const logDump = new CodeBuilder(
		(code) => {
			// Monitor RNG と Log Dump の連携 (ポーズ中にセレクトでログ記録を有効化)
			code
				.ifEq8(Symbols.GameState, STATE.PAUSE)
				.ifAllBits16(Symbols.Buttons, BUTTON.SELECT)
				.write32(monitorRng.sym("p_log_buffer"), code.sym("log_buffer"))
				.endAllIf();
		},
		ram.createModule("log_dump.c", [
			{
				// セーブデータ書き込み処理をフック
				symbol: "HookSave",
				at: 0x02026bd4,
				expected: insn(0xea000005, "b ..."),
				resumeAt: 0x02026bf0,
			},
		]),
	);

	// ゴースト (Ghost)
	const ghost = new CodeBuilder(
		(code) => {
			// QSQL と Ghost の連携 (関数ポインタの設定)
			code.write32(qsql.sym("p_update_ghost"), code.sym("UpdateGhost"));
			code.write32(qsql.sym("p_reset_ghost"), code.sym("ResetGhost"));
		},
		ram.createModule("ghost.c"),
	);

	// 特定乱数の検知チート群 (各呼び出し地点ごとに分割)
	const randiCallSites = [
		["Impact Star", 0x020c42a0],
		["Invincibility Star", 0x020c5e4c],
		["Losing Ability", 0x0210b578],
		["Defeated Enemy Effect", 0x0216fc84],
		["Food Star", 0x020947d0],
		["Whale Rolls or Splashes", 0x021a743c],
		["Windows Attacks First", 0x021aa818],
		["Windows Copy Essences", 0x021a4d50],
		["Windows Moves", 0x021a89bc],
		["Lobster Walks or Dashes", 0x021a40fc],
		["Lobster Jumps or Glides", 0x021a41dc],
	] as const;

	const randiCheats: Cheat[] = randiCallSites.map(([name, at]) => ({
		name,
		enabled: false,
		code: new CodeBuilder((code) => {
			code.retargetCall(at, Symbols.Randi, monitorRng.sym("RandiWithUpdate"));
		}),
	}));

	return [
		{ name: "Mute", enabled: false, code: mute },
		{ name: "QSQL", enabled: true, code: qsql },
		{ name: "Monitor RNG", enabled: false, code: monitorRng },
		{ name: "Log Dump", enabled: false, code: logDump },
		{ name: "Ghost", enabled: false, code: ghost },
		...randiCheats,
	];
}

// --- 出力設定 ---

/** usrcheat.dat のデータベース名 */
const databaseName = "KSSU-Practice v3.3";

const games: Game[] = [
	new Game({
		id: "YKWJ",
		crc: 0x776dde8f,
		name: "KIRBY USDX J",
		serial: "NTR-YKWJ-JPN",
		dctFileName: "KIRBY_USDX_J_YKWJ01_00.dct",
		cheats: createKirbyCheats(),
	}),
];

writeOutputs({ rootDir, databaseName, games });
