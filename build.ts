import { fileURLToPath } from "node:url";

import { CodeBuilder, insn, RamAllocator } from "./tools/scripts/ar.ts";
import type { Cheat } from "./tools/scripts/formats/cheat.ts";
import { Game } from "./tools/scripts/formats/game.ts";
import { writeOutputs } from "./tools/scripts/output.ts";

const rootDir = fileURLToPath(new URL(".", import.meta.url));

/** 星のカービィ ウルトラスーパーデラックス (日本版) のチート一式を組み立てる */
function createKirbyCheats(): Cheat[] {
	// メモリ管理マネージャの作成 (コード開始, BSS開始, メモリ終端)
	const ram = new RamAllocator(rootDir, 0x022c0000, 0x022c2000, 0x02368000);
	const cheats: Cheat[] = [];

	// Mute (v3.3 の dct / usrcheat.dat に合わせて追加。Lua 実行時には適用しない)
	const mute = new CodeBuilder((code) => code.write8(0x0205e76c, 0));
	cheats.push({ name: "Mute", enabled: false, runtime: false, code: mute });

	// QSQL モジュール
	const qsqlMod = ram.createModule("QSQL.c", [
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
	]);
	const qsql = new CodeBuilder((code) => {
		code.include(qsqlMod);

		// 格闘王系モードでの下画面のボスの表示を通常時に切り替える処理の、
		// ゲームモードに応じたリソースをロードする処理を上書き
		code.replaceFunction(qsqlMod.sym("ArenaImageSwitcher"), {
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
		code.jumpToAt(qsqlMod.sym("DrawNumbers"), {
			at: 0x02090d48,
			expected: insn(0xe92d41f0, "stmdb sp!, {r4-r8, lr}"),
		});
		// スコア・ゴールドを消す
		code.earlyReturnAt({
			at: 0x020904c8,
			expected: insn(0xe92d4ff8, "stmdb sp!, {r3-r11, lr}"),
		});
		// タイマーを消す
		code.earlyReturnAt({
			at: 0x020905a4,
			expected: insn(0xe92d41f0, "stmdb sp!, {r4-r8, lr}"),
		});
		// vs～を消す
		code
			.ifEq32(0x0208e7e4, 0xe59010c8)
			.write32(0x0208e7e4, 0xe3a01000) // ldr r1, [r0, #C8] -> mov r1, 0
			.endAllIf();
	});

	cheats.push({ name: "QSQL", enabled: true, runtime: true, code: qsql });

	// 乱数監視 (Monitor RNG)
	const seedMod = ram.createModule("seed_advances.c", [
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
	]);
	const monitorRng = new CodeBuilder((code) => {
		code.include(seedMod);

		// QL 時に乱数リセット関数を呼び出すように関数ポインタを設定
		code.write32(qsqlMod.sym("p_reset_rng"), seedMod.sym("ResetRNG"));
		// 表示先を QSQL の show 配列に設定
		code.write32(seedMod.sym("p_show"), qsqlMod.sym("show"));
	});

	cheats.push({
		name: "Monitor RNG",
		enabled: false,
		runtime: true,
		code: monitorRng,
	});

	// ログ出力 (Log Dump)
	const logMod = ram.createModule("log_dump.c", [
		{
			// セーブデータ書き込み処理をフック
			symbol: "HookSave",
			at: 0x02026bd4,
			expected: insn(0xea000005, "b ..."),
			resumeAt: 0x02026bf0,
		},
	]);
	const logDump = new CodeBuilder((code) => {
		code.include(logMod);

		// Monitor RNG と Log Dump の連携 (ポーズ中にセレクトでログ記録を有効化)
		code
			.ifEq8(0x0205b244, 0x000b) // ポーズ中 (gameState == STATE_PAUSE)
			.ifAllBits16(0x02041e68, 0x0004) // セレクトボタン押下 (SELECT)
			.write32(seedMod.sym("p_log_buffer"), logMod.sym("log_buffer")) // バッファ先頭アドレス (動的解決)
			.endAllIf();
	});

	cheats.push({
		name: "Log Dump",
		enabled: false,
		runtime: true,
		code: logDump,
	});

	// ゴースト (Ghost)
	const ghostMod = ram.createModule("ghost.c");
	const ghost = new CodeBuilder((code) => {
		code.include(ghostMod);

		// QSQL と Ghost の連携 (関数ポインタの設定)
		code.write32(qsqlMod.sym("p_update_ghost"), ghostMod.sym("UpdateGhost"));
		code.write32(qsqlMod.sym("p_reset_ghost"), ghostMod.sym("ResetGhost"));
	});

	cheats.push({ name: "Ghost", enabled: false, runtime: true, code: ghost });

	// 特定乱数の検知チート群 (各呼び出し地点ごとに分割)
	function addRandiCheat(addr: number, name: string): void {
		const code = new CodeBuilder((c) => {
			c.retargetCallAt({
				at: addr,
				from: 0x0200b8a4,
				to: seedMod.sym("RandiWithUpdate"),
			});
		});
		cheats.push({ name, enabled: false, runtime: true, code });
	}

	addRandiCheat(0x020c42a0, "Impact Star");
	addRandiCheat(0x020c5e4c, "Invincibility Star");
	addRandiCheat(0x0210b578, "Losing Ability");
	addRandiCheat(0x0216fc84, "Defeated Enemy Effect");
	addRandiCheat(0x020947d0, "Food Star");

	addRandiCheat(0x021a743c, "Whale Rolls or Splashes");
	addRandiCheat(0x021aa818, "Windows Attacks First");
	addRandiCheat(0x021a4d50, "Windows Copy Essences");
	addRandiCheat(0x021a89bc, "Windows Moves");

	addRandiCheat(0x021a40fc, "Lobster Walks or Dashes");
	addRandiCheat(0x021a41dc, "Lobster Jumps or Glides");

	return cheats;
}

// --- 出力設定 ---

/** usrcheat.dat のデータベース名 */
const databaseName = "KSSU-Practice v3.3";

const games: Game<Cheat>[] = [
	new Game<Cheat>({
		id: "YKWJ",
		crc: 0x776dde8f,
		name: "KIRBY USDX J",
		serial: "NTR-YKWJ-JPN",
		dctFileName: "KIRBY_USDX_J_YKWJ01_00.dct",
		cheats: createKirbyCheats(),
	}),
];

writeOutputs({ rootDir, databaseName, games });
