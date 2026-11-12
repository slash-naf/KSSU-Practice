import fs from "node:fs";
import path from "node:path";

import type { Cheat } from "./formats/cheat.ts";
import { writeDct } from "./formats/dct.ts";
import type { Game } from "./formats/game.ts";
import { writeUsrCheat } from "./formats/usrcheat.ts";

export interface OutputOptions {
	/** プロジェクトのルートディレクトリ */
	rootDir: string;
	/** usrcheat.dat のデータベース名 */
	databaseName: string;
	/** 出力するゲーム一覧 */
	games: readonly Game<Cheat>[];
}

/** チート一式を dist / build に出力する */
export function writeOutputs(options: OutputOptions): void {
	const { rootDir, databaseName, games } = options;
	const distDir = path.join(rootDir, "dist");
	const buildDir = path.join(rootDir, "build");

	fs.mkdirSync(distDir, { recursive: true });
	fs.mkdirSync(buildDir, { recursive: true });

	for (const game of games) {
		const dctPath = path.join(distDir, game.dctFileName);
		fs.writeFileSync(dctPath, writeDct(game));
		console.log(`Generated ${path.relative(rootDir, dctPath)}`);
	}

	const usrCheatPath = path.join(distDir, "usrcheat.dat");
	fs.writeFileSync(usrCheatPath, writeUsrCheat(databaseName, games));

	const runtimePath = path.join(buildDir, "cheats.ar");
	const runtimeCheats = games
		.flatMap((game) => game.cheats)
		.filter((cheat) => cheat.runtime);
	fs.writeFileSync(
		runtimePath,
		runtimeCheats.map((cheat) => cheat.code.toString(cheat.name)).join(""),
	);

	for (const game of games) {
		console.log(`[${game.name}]`);
		for (const cheat of game.cheats) {
			console.log(`  ${cheat.name}: ${cheat.code.words.length / 2} code line(s)`);
		}
	}
	console.log(`Generated ${path.relative(rootDir, usrCheatPath)}`);
	console.log(`Generated ${path.relative(rootDir, runtimePath)}`);
}
