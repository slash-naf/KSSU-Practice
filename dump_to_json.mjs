// @ts-check
import fs from 'fs';

/**
 * @typedef {Object} LogEntry
 * @property {number} w1 - 呼び出し元アドレスまたはQL情報
 * @property {number} seedTimer - 乱数更新タイマー (w2の上位16bit)
 * @property {number} seed - 乱数値 (w2の下位16bit)
 */

// 入出力パスの設定 (引数またはデフォルト)
const argv = process.argv;
const input = argv[2] ?? 'C:/Users/sla4naf/!/app/desmume-0.9.13-win64/Battery/KIRBY_USDX_J_YKWJ01_00.dsv';
const output = argv[3] ?? `${input.replace(/\.[^.]+$/, '')}_log.json`;

const buf = fs.readFileSync(input);
const wordCount = buf.readUInt32LE(0);
const entryCount = Math.min(Math.floor(wordCount / 2), Math.floor((buf.length - 4) / 8));

// ログエントリのパース (各エントリ 8 バイト: w1 = caller/gameState, w2 = timer & seed)
/** @type {LogEntry[]} */
const entries = [];
for (let i = 0; i < entryCount; i++) {
	const w1 = buf.readUInt32LE(4 + i * 8);
	const w2 = buf.readUInt32LE(8 + i * 8);

	entries.push({
		w1,
		seedTimer: (w2 >>> 16) & 0xffff,
		seed: w2 & 0xffff,
	});
}

fs.writeFileSync(output, JSON.stringify(entries));
console.log(`Saved ${entries.length} entries to ${output}`);
