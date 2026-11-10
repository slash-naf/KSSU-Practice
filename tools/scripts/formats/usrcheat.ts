import type { GeneratedCheat } from "./types.ts";

const HEADER_SIZE = 0x100;
const GAME_ID = "YKWJ";
const GAME_CRC = 0x776dde8f;
const GAME_NAME = "KIRBY USDX J\n";
const DATABASE_NAME = "KSSU-Practice v3.3";
const GAME_ENABLED_FLAG = 0xf000;
const CHEAT_ENABLED_FLAG = 0x0100;

function padTo4(buffer: Buffer): Buffer {
	const remainder = buffer.length % 4;
	if (remainder === 0) return buffer;
	return Buffer.concat([buffer, Buffer.alloc(4 - remainder)]);
}

function writeString(value: string): Buffer {
	return padTo4(Buffer.concat([Buffer.from(value, "utf8"), Buffer.from([0])]));
}

function writeCheat(cheat: GeneratedCheat): Buffer[] {
	const nameAndComment = padTo4(
		Buffer.concat([
			Buffer.from(cheat.name, "utf8"),
			Buffer.from([0]), // name 終端
			Buffer.from([0]), // comment 終端 (空)
		]),
	);

	// アイテム全体の 4byte チャンク数 (ヘッダ 1 + 名前/コメント + コード)
	const chunks = nameAndComment.length / 4 + 1 + cheat.code.words.length;

	const itemHeader = Buffer.alloc(4);
	itemHeader.writeUInt16LE(chunks, 0);
	itemHeader.writeUInt16LE(cheat.enabled ? CHEAT_ENABLED_FLAG : 0, 2);

	const codeLength = Buffer.alloc(4);
	codeLength.writeUInt32LE(cheat.code.words.length, 0);

	const code = Buffer.alloc(cheat.code.words.length * 4);
	for (let i = 0; i < cheat.code.words.length; i++) {
		code.writeUInt32LE(cheat.code.words[i] >>> 0, i * 4);
	}

	return [itemHeader, nameAndComment, codeLength, code];
}

/** R4 形式の usrcheat.dat を生成する */
export function writeUsrCheat(cheats: readonly GeneratedCheat[]): Buffer {
	const header = Buffer.alloc(HEADER_SIZE);
	header.write("R4 CheatCode", 0, "ascii");
	header.writeUInt32LE(HEADER_SIZE, 0x0c);
	header.write(DATABASE_NAME, 0x10, "ascii");
	header.write("UsAY", 0x4c, "ascii"); // UTF-8
	header[0x50] = 1; // チート有効

	// ゲームポインタ + 16byte の終端ブロック
	const gameOffset = HEADER_SIZE + 0x10 + 0x10;
	const pointer = Buffer.alloc(0x10);
	pointer.write(GAME_ID, 0, "ascii");
	pointer.writeUInt32LE(GAME_CRC, 4);
	pointer.writeUInt32LE(gameOffset, 8);

	const gameHeader = Buffer.alloc(4);
	gameHeader.writeUInt16LE(cheats.length, 0);
	gameHeader.writeUInt16LE(GAME_ENABLED_FLAG, 2);

	const masterCode = Buffer.alloc(32);
	masterCode.writeUInt32LE(1, 4); // 既定値: 00000000 00000001 ...

	const gameParts: Buffer[] = [
		writeString(GAME_NAME),
		gameHeader,
		masterCode,
	];
	for (const cheat of cheats) {
		gameParts.push(...writeCheat(cheat));
	}

	return Buffer.concat([
		header,
		pointer,
		Buffer.alloc(0x10),
		...gameParts,
	]);
}
