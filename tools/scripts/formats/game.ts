import type { GeneratedCheat } from "./cheat.ts";

export interface GameOptions<TCheat extends GeneratedCheat = GeneratedCheat> {
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
	cheats: readonly TCheat[];
}

/** 1ゲーム分のメタ情報とチート一覧 */
export class Game<TCheat extends GeneratedCheat = GeneratedCheat> {
	readonly id: string;
	readonly crc: number;
	readonly name: string;
	readonly serial: string;
	readonly dctFileName: string;
	readonly cheats: readonly TCheat[];

	constructor(options: GameOptions<TCheat>) {
		this.id = options.id;
		this.crc = options.crc;
		this.name = options.name;
		this.serial = options.serial;
		this.dctFileName = options.dctFileName;
		this.cheats = options.cheats;
	}
}
