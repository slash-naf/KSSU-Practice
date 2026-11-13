import fs from "node:fs";
import path from "node:path";

import type { Game } from "./formats/cheat.ts";
import { writeDct } from "./formats/dct.ts";
import { writeUsrCheat } from "./formats/usrcheat.ts";

export interface OutputOptions {
	/** プロジェクトのルートディレクトリ */
	rootDir: string;
	/** usrcheat.dat のデータベース名 */
	databaseName: string;
	/** 出力するゲーム一覧 */
	games: readonly Game[];
}

/**
 * 既存ファイルと内容が異なる場合だけ backup フォルダへ退避してから書き込む。
 * 戻り値は書き込んだかどうか。
 */
function writeOutputFile(filePath: string, data: string | Buffer): boolean {
	const next = typeof data === "string" ? Buffer.from(data) : data;

	if (fs.existsSync(filePath)) {
		const existing = fs.readFileSync(filePath);
		if (existing.equals(next)) return false;

		const backupPath = path.join(
			path.dirname(filePath),
			"backup",
			path.basename(filePath),
		);
		fs.mkdirSync(path.dirname(backupPath), { recursive: true });
		fs.copyFileSync(filePath, backupPath);
	}

	fs.writeFileSync(filePath, data);
	return true;
}

/** チート一式を dist に出力する */
export function writeOutputs(options: OutputOptions): void {
	const { rootDir, databaseName, games } = options;
	const distDir = path.join(rootDir, "dist");

	fs.mkdirSync(distDir, { recursive: true });

	let updated = false;
	for (const game of games) {
		const dctPath = path.join(distDir, game.dctFileName);
		updated = writeOutputFile(dctPath, writeDct(game)) || updated;
	}

	const usrCheatPath = path.join(distDir, "usrcheat.dat");
	updated =
		writeOutputFile(usrCheatPath, writeUsrCheat(databaseName, games)) ||
		updated;

	const arContent = games
		.flatMap((game) => game.cheats)
		.map((cheat) => cheat.code.toString(cheat.name))
		.join("");

	const arPath = path.join(distDir, "cheats.ar");
	updated = writeOutputFile(arPath, arContent) || updated;

	console.log(updated ? "dist: updated" : "dist: up to date");
}
