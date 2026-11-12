import type { Game } from "./cheat.ts";

const hex8 = (value: number): string =>
	(value >>> 0).toString(16).toUpperCase().padStart(8, "0");

/** 1ゲーム分の DeSmuME 用チートファイル (.dct) を生成する */
export function writeDct(game: Game): string {
	const lines = [
		"; DeSmuME cheats file. VERSION 2.000",
		`Name=${game.name}`,
		`Serial=${game.serial}`,
		"",
		"; cheats list",
	];

	for (const cheat of game.cheats) {
		const words = cheat.code.words;
		const data: string[] = [];
		for (let i = 0; i < words.length; i += 2) {
			data.push(`${hex8(words[i])}${hex8(words[i + 1])}`);
		}
		lines.push(`AR ${cheat.enabled ? 1 : 0} ${data.join(",")} ;${cheat.name}`);
	}

	// 末尾に空行を 1 行入れる
	return `${lines.join("\r\n")}\r\n\r\n`;
}
