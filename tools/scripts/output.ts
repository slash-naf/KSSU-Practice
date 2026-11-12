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

	const arPath = path.join(buildDir, "cheats.ar");
	const arCheats = games.flatMap((game) => game.cheats);
	fs.writeFileSync(
		arPath,
		arCheats.map((cheat) => cheat.code.toString(cheat.name)).join(""),
	);

	for (const game of games) {
		console.log(`[${game.name}]`);
		for (const cheat of game.cheats) {
			console.log(`  ${cheat.name}: ${cheat.code.words.length / 2} code line(s)`);
		}
	}
	console.log(`Generated ${path.relative(rootDir, usrCheatPath)}`);
	console.log(`Generated ${path.relative(rootDir, arPath)}`);
}
