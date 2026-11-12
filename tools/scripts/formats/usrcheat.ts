import type { GeneratedCheat } from "./cheat.ts";
import type { Game } from "./game.ts";

const HEADER_SIZE = 0x100;
const GAME_POINTER_SIZE = 0x10;
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

/** 1ゲーム分のチートデータブロックを生成する */
function writeGame(game: Game<GeneratedCheat>): Buffer {
	const gameHeader = Buffer.alloc(4);
	gameHeader.writeUInt16LE(game.cheats.length, 0);
	gameHeader.writeUInt16LE(GAME_ENABLED_FLAG, 2);

	const masterCode = Buffer.alloc(32);
	masterCode.writeUInt32LE(1, 4); // 既定値: 00000000 00000001 ...

	const parts: Buffer[] = [
		writeString(`${game.name}\n`),
		gameHeader,
		masterCode,
	];
	for (const cheat of game.cheats) {
		parts.push(...writeCheat(cheat));
	}
	return Buffer.concat(parts);
}

/** 複数ゲームを含む R4 形式の usrcheat.dat を生成する */
export function writeUsrCheat(
	databaseName: string,
	games: readonly Game<GeneratedCheat>[],
): Buffer {
	const header = Buffer.alloc(HEADER_SIZE);
	header.write("R4 CheatCode", 0, "ascii");
	header.writeUInt32LE(HEADER_SIZE, 0x0c);
	header.write(databaseName, 0x10, "ascii");
	header.write("UsAY", 0x4c, "ascii"); // UTF-8
	header[0x50] = 1; // チート有効

	// ゲームポインタの直後に 16byte の終端ブロックを置く
	const firstGameOffset = HEADER_SIZE + (games.length + 1) * GAME_POINTER_SIZE;

	const bodies = games.map(writeGame);
	const pointers: Buffer[] = [];
	let offset = firstGameOffset;
	for (let i = 0; i < games.length; i++) {
		const game = games[i];
		const body = bodies[i];

		const pointer = Buffer.alloc(GAME_POINTER_SIZE);
		pointer.write(game.id, 0, "ascii");
		pointer.writeUInt32LE(game.crc >>> 0, 4);
		pointer.writeUInt32LE(offset, 8);
		pointers.push(pointer);

		offset += body.length;
	}

	return Buffer.concat([
		header,
		...pointers,
		Buffer.alloc(GAME_POINTER_SIZE),
		...bodies,
	]);
}
