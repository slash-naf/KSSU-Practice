import type { CodeBuilder } from "../ar.ts";

/** ビルド時に組み立てるチート定義 */
export interface Cheat {
	/** チート名 */
	name: string;
	/** 初期状態で有効にするか */
	enabled: boolean;
	/** Action Replay コード */
	code: CodeBuilder;
}

export interface GameOptions {
	/** ゲームID (4文字) */
	id: string;
	/** ゲームコードのCRC32 */
	crc: number;
	/** ゲーム名 */
	name: string;
	/** シリアル (例: NTR-YKWJ-JPN) */
	serial: string;
	/** DeSmuME用チートファイル名 (.dct) */
	dctFileName: string;
	/** チート一覧 */
	cheats: readonly Cheat[];
}

/** 1ゲーム分のメタ情報とチート一覧 */
export class Game {
	readonly id: string;
	readonly crc: number;
	readonly name: string;
	readonly serial: string;
	readonly dctFileName: string;
	readonly cheats: readonly Cheat[];

	constructor(options: GameOptions) {
		this.id = options.id;
		this.crc = options.crc;
		this.name = options.name;
		this.serial = options.serial;
		this.dctFileName = options.dctFileName;
		this.cheats = options.cheats;
	}
}
