import type { CodeBuilder } from "../ar.ts";

/** 出力フォーマットが必要とするチートの最小情報 */
export interface GeneratedCheat {
	name: string;
	enabled: boolean;
	code: {
		readonly words: readonly number[];
	};
}

/** ビルド時に組み立てるチート定義 */
export interface Cheat extends GeneratedCheat {
	code: CodeBuilder;
	runtime: boolean;
}
