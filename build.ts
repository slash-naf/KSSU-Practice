import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import { allocateRam, newCode } from "./tools/scripts/ar.ts";
import type { CodeBuilder } from "./tools/scripts/ar.ts";
import { writeDct } from "./tools/scripts/formats/dct.ts";
import { Game } from "./tools/scripts/formats/game.ts";
import type { GeneratedCheat } from "./tools/scripts/formats/game.ts";
import { writeUsrCheat } from "./tools/scripts/formats/usrcheat.ts";

interface Cheat extends GeneratedCheat {
	code: CodeBuilder;
	runtime: boolean;
}

const rootDir = fileURLToPath(new URL(".", import.meta.url));

/** 星のカービィ ウルトラスーパーデラックス (日本版) のチート一式を組み立てる */
function createKirbyCheats(): Cheat[] {
	// メモリ管理マネージャの作成 (コード開始, BSS開始, メモリ終端)
	const ram = allocateRam(rootDir, 0x022c0000, 0x022c2000, 0x02368000);
	const cheats: Cheat[] = [];

	// Mute (v3.3 の dct / usrcheat.dat に合わせて追加。Lua 実行時には適用しない)
	const mute = newCode().write8(0x0205e76c, 0);
	cheats.push({ name: "Mute", enabled: false, runtime: false, code: mute });

	// QSQL モジュール
	const qsqlMod = ram
		.createModule("QSQL.c")
		.hook("QS", 0x02001830, 0xe8bd8010, 0xe8bd8010) // ボタン入力処理の関数の return にフック
		.hook("QL", 0x02074ed8, 0xe92d4008) // ロードの進行状況の読み取りの直前にフック
		.hook("MixStep", 0x02111e68, 0xe2411001); // mix_cnt のカウントアップ
	const qsql = newCode().importModule(qsqlMod);

	// 格闘王系モードでの下画面のボスの表示を通常時に切り替える処理の、
	// ゲームモードに応じたリソースをロードする処理を上書き
	qsql.override(
		qsqlMod.symbols["ArenaImageSwitcher"],
		0x0206ce20,
		0xe3500007,
		0x0206cf68,
	);

	// Freeze RoMK Timer
	qsql
		.ifEq(0x0206b6a0, 0xa2400c21)
		.write32(0x0206b6a4, 0xe1a00000)
		.write32(0x0206b6bc, 0xe1a00000)
		.endIf();

	// 数値描画
	qsql.redirect(qsqlMod.symbols["DrawNumbers"], 0x02090d48, 0xe92d41f0);
	// スコア・ゴールドを消す
	qsql.disable(0x020904c8, 0xe92d4ff8);
	// タイマーを消す
	qsql.disable(0x020905a4, 0xe92d41f0);
	// vs～を消す
	qsql
		.ifEq(0x0208e7e4, 0xe59010c8)
		.write32(0x0208e7e4, 0xe3a01000) // ldr r1, [r0, #C8] -> mov r1, 0
		.endIf();

	cheats.push({ name: "QSQL", enabled: true, runtime: true, code: qsql });

	// 乱数監視 (Monitor RNG)
	const seedMod = ram
		.createModule("seed_advances.c")
		.hook("AddFromAdvanceSeed", 0x0200b88c, 0xe58204a4) // 定期乱数進み時に加算
		.hook("AddFromRandi", 0x0200b8d0, 0xe58314a4) // randi 時に加算 (8F周期を除外)
		.hook("UpdateRNG", 0x020b5804, 0xea000006, 0x020b5824); // ポピーブロスJr.自爆タイマー設定時に表示更新
	const monitorRng = newCode().importModule(seedMod);

	// QL 時に乱数リセット関数を呼び出すように関数ポインタを設定
	monitorRng.write32(qsqlMod.symbols["p_reset_rng"], seedMod.symbols["ResetRNG"]);
	// 表示先を QSQL の show 配列に設定
	monitorRng.write32(seedMod.symbols["p_show"], qsqlMod.symbols["show"]);

	cheats.push({ name: "Monitor RNG", enabled: false, runtime: true, code: monitorRng });

	// ログ出力 (Log Dump)
	const logMod = ram
		.createModule("log_dump.c")
		.hook("HookSave", 0x02026bd4, 0xea000005, 0x02026bf0); // セーブデータ書き込み処理をフック
	const logDump = newCode().importModule(logMod);

	// Monitor RNG と Log Dump の連携 (ポーズ中にセレクトでログ記録を有効化)
	logDump
		.ifEq(0x0205b244, 0x000b, 0x00ff) // ポーズ中 (gameState == STATE_PAUSE)
		.ifEq(0x02041e68, 0x0004, 0x0004) // セレクトボタン押下 (SELECT)
		.write32(seedMod.symbols["p_log_buffer"], logMod.symbols["log_buffer"]) // バッファ先頭アドレス (動的解決)
		.endIf();

	cheats.push({ name: "Log Dump", enabled: false, runtime: true, code: logDump });

	// ゴースト (Ghost)
	const ghostMod = ram.createModule("ghost.c");
	const ghost = newCode().importModule(ghostMod);

	// QSQL と Ghost の連携 (関数ポインタの設定)
	ghost.write32(qsqlMod.symbols["p_update_ghost"], ghostMod.symbols["UpdateGhost"]);
	ghost.write32(qsqlMod.symbols["p_reset_ghost"], ghostMod.symbols["ResetGhost"]);

	cheats.push({ name: "Ghost", enabled: false, runtime: true, code: ghost });

	// 特定乱数の検知チート群 (各呼び出し地点ごとに分割)
	function addRandiCheat(addr: number, name: string): void {
		const code = newCode().replaceCall(
			addr,
			0x0200b8a4,
			seedMod.symbols["RandiWithUpdate"],
		);
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

const distDir = path.join(rootDir, "dist");
const buildDir = path.join(rootDir, "build");
fs.mkdirSync(distDir, { recursive: true });
fs.mkdirSync(buildDir, { recursive: true });

const usrCheatPath = path.join(distDir, "usrcheat.dat");
const runtimePath = path.join(buildDir, "cheats.ar");

for (const game of games) {
	const dctPath = path.join(distDir, game.dctFileName);
	fs.writeFileSync(dctPath, writeDct(game));
	console.log(`Generated ${path.relative(rootDir, dctPath)}`);
}

fs.writeFileSync(usrCheatPath, writeUsrCheat(databaseName, games));

const runtimeCheats = games
	.flatMap((game) => game.cheats)
	.filter((cheat) => cheat.runtime);
fs.writeFileSync(
	runtimePath,
	runtimeCheats
		.map((cheat) => cheat.code.toString(cheat.name))
		.join(""),
);

for (const game of games) {
	console.log(`[${game.name}]`);
	for (const cheat of game.cheats) {
		console.log(`  ${cheat.name}: ${cheat.code.words.length / 2} code line(s)`);
	}
}
console.log(`Generated ${path.relative(rootDir, usrCheatPath)}`);
console.log(`Generated ${path.relative(rootDir, runtimePath)}`);
