import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

/** 32bit unsigned に丸める */
const u32 = (n: number): number => n >>> 0;

const ARM_PUSH = 0xE92D5FFF; // stmdb r13!,{r0-r12,r14}
const ARM_POP = 0xE8BD5FFF; // ldmia r13!,{r0-r12,r14}
const ARM_RET = 0xE12FFF1E; // bx r14

/** 命令コード。text はリスティング用の表示名。 */
export type Instruction =
	| number
	| { readonly code: number; readonly text: string };

/** 表示名付きの命令を作る */
export function insn(code: number, text: string): Instruction {
	return { code, text };
}

/** Instruction から 32bit 命令コードを取り出す */
export function instructionCode(instruction: Instruction): number {
	return typeof instruction === "number" ? instruction : instruction.code;
}

function assertU32(value: number, label: string): number {
	if (!Number.isInteger(value) || value < 0 || value > 0xFFFFFFFF) {
		throw new Error(
			`${label} must be a 32bit unsigned integer: ${String(value)}`,
		);
	}
	return value;
}

function assertRange(value: number, max: number, label: string): number {
	if (!Number.isInteger(value) || value < 0 || value > max) {
		throw new Error(
			`${label} must be in 0x00000000..0x${max
				.toString(16)
				.toUpperCase()
				.padStart(8, "0")}: ${String(value)}`,
		);
	}
	return value;
}

function assertAligned(addr: number, alignment: number, label: string): void {
	if (addr % alignment !== 0) {
		throw new Error(
			`${label} must be ${alignment}-byte aligned: 0x${addr
				.toString(16)
				.toUpperCase()}`,
		);
	}
}

/** 現在地から targetAddr への b 命令 */
function jump(currentAddr: number, targetAddr: number): number {
	const offset = u32((targetAddr - currentAddr) >>> 2);
	return u32(0xEA000000 + ((offset - 2) & 0x00FFFFFF));
}

/** 現在地から targetAddr への bl 命令 */
function call(currentAddr: number, targetAddr: number): number {
	const offset = u32((targetAddr - currentAddr) >>> 2);
	return u32(0xEB000000 + ((offset - 2) & 0x00FFFFFF));
}

export interface BuildLibrary {
	bin: number[];
	symbols: Record<string, number>;
}

/** C モジュールの関数をゲームコードにフックする定義 */
export interface HookSpec {
	/** モジュール内の関数シンボル名 */
	symbol: string;
	/** フックするゲーム側のアドレス */
	at: number;
	/** 上書きされる元の命令。一致したときだけフックする */
	expected: Instruction;
	/** フック後に実行する命令 (通常は return 命令) */
	returnWith?: Instruction;
	/** フック後にジャンプするアドレス。returnWith とは併用不可 */
	resumeAt?: number;
}

export interface Module {
	path: string;
	bin: number[];
	symbols: Record<string, number>;
	origin: number;
	hooks: CodeBuilder;
	ram: RamAllocator;
	/** シンボルを取得する。存在しなければ例外を投げる */
	sym(name: string): number;
}

function moduleName(filePath: string): string {
	return path.basename(filePath).replace(/\.[^.]+$/, "");
}

/**
 * make を実行して C ソースをコンパイルし、フラットバイナリとシンボルを読み込む。
 */
function compile(
	rootDir: string,
	filePath: string,
	origin: number,
	bss: number,
): BuildLibrary {
	const name = moduleName(filePath);
	const cmd = [
		"make",
		`SRC=source/${filePath}`,
		`ADDR=0x${origin.toString(16).padStart(8, "0")}`,
		`BSS=0x${bss.toString(16).padStart(8, "0")}`,
	].join(" ");

	console.log(cmd);
	execSync(cmd, { cwd: rootDir, stdio: "inherit" });

	const binPath = path.join(rootDir, "build", `${name}.bin`);
	const symPath = path.join(rootDir, "build", `${name}.txt`);

	const data = fs.readFileSync(binPath);
	const bin: number[] = [];
	for (let i = 0; i < data.length; i += 4) {
		bin.push(
			u32(
				(data[i] ?? 0) |
					((data[i + 1] ?? 0) << 8) |
					((data[i + 2] ?? 0) << 16) |
					((data[i + 3] ?? 0) << 24),
			),
		);
	}

	const symbols: Record<string, number> = {};
	const symbolText = fs.readFileSync(symPath, "utf8");
	for (const line of symbolText.split(/\r?\n/)) {
		const match = line.match(/^\s*([0-9a-fA-F]+)\s+\w\s+(\S+)/);
		if (match) symbols[match[2]] = Number.parseInt(match[1], 16);
	}

	return { bin, symbols };
}

/** Action Replay コード生成器 */
export class CodeBuilder {
	readonly words: number[] = [];
	readonly symbols: Record<string, number> = {};
	private openIf = false;

	constructor(build?: (code: CodeBuilder) => void) {
		build?.(this);
	}

	append(values: number | readonly number[]): this {
		if (typeof values === "number") {
			this.words.push(assertU32(values, "code word"));
		} else {
			for (const value of values) {
				this.words.push(assertU32(value, "code word"));
			}
		}
		return this;
	}

	write32(addr: number, value: number): this {
		this.append([addr, value]);
		return this;
	}

	write16(addr: number, value: number): this {
		this.append([
			u32(0x10000000 + assertU32(addr, "write16 address")),
			assertRange(value, 0xFFFF, "write16 value"),
		]);
		return this;
	}

	write8(addr: number, value: number): this {
		this.append([
			u32(0x20000000 + assertU32(addr, "write8 address")),
			assertRange(value, 0xFF, "write8 value"),
		]);
		return this;
	}

	/** 32bit 比較コード */
	private cmp32(type: number, addr: number, value: number): [number, number] {
		assertAligned(addr, 4, "32bit condition address");
		return [
			u32(type * 0x10000000 + assertU32(addr, "condition address")),
			assertU32(value, "condition value"),
		];
	}

	/**
	 * 16bit マスク比較コード。
	 * mask は比較するビット、value はマスク後の期待値。
	 */
	private cmp16(
		type: number,
		addr: number,
		value: number,
		mask: number,
	): [number, number] {
		assertAligned(addr, 2, "16bit condition address");
		const expected = assertRange(value, 0xFFFF, "condition value");
		const bits = assertRange(mask, 0xFFFF, "condition mask");
		const invertedMask = (~bits) & 0xFFFF;

		return [
			u32(
				type * 0x10000000 +
					assertU32(addr, "condition address") +
					0x40000000,
			),
			u32(expected + ((invertedMask << 16) >>> 0)),
		];
	}

	/** 8bit 比較を、そのバイトを含む16bit halfwordのマスク比較で表現する */
	private cmp8(
		type: number,
		addr: number,
		value: number,
		mask: number,
	): [number, number] {
		const shift = (addr & 1) * 8;
		return this.cmp16(type, addr & ~1, value << shift, mask << shift);
	}

	/** 条件コードを追加し、endAllIf() まで条件ブロックを開く */
	private condition(code: [number, number]): this {
		this.append(code);
		this.openIf = true;
		return this;
	}

	ifLt8(addr: number, value: number): this {
		this.condition(
			this.cmp8(3, addr, assertRange(value, 0xFF, "ifLt8 value"), 0xFF),
		);
		return this;
	}

	ifGt8(addr: number, value: number): this {
		this.condition(
			this.cmp8(4, addr, assertRange(value, 0xFF, "ifGt8 value"), 0xFF),
		);
		return this;
	}

	ifEq8(addr: number, value: number): this {
		this.condition(
			this.cmp8(5, addr, assertRange(value, 0xFF, "ifEq8 value"), 0xFF),
		);
		return this;
	}

	ifNe8(addr: number, value: number): this {
		this.condition(
			this.cmp8(6, addr, assertRange(value, 0xFF, "ifNe8 value"), 0xFF),
		);
		return this;
	}

	ifLt16(addr: number, value: number): this {
		this.condition(
			this.cmp16(3, addr, assertRange(value, 0xFFFF, "ifLt16 value"), 0xFFFF),
		);
		return this;
	}

	ifGt16(addr: number, value: number): this {
		this.condition(
			this.cmp16(4, addr, assertRange(value, 0xFFFF, "ifGt16 value"), 0xFFFF),
		);
		return this;
	}

	ifEq16(addr: number, value: number): this {
		this.condition(
			this.cmp16(5, addr, assertRange(value, 0xFFFF, "ifEq16 value"), 0xFFFF),
		);
		return this;
	}

	ifNe16(addr: number, value: number): this {
		this.condition(
			this.cmp16(6, addr, assertRange(value, 0xFFFF, "ifNe16 value"), 0xFFFF),
		);
		return this;
	}

	ifLt32(addr: number, value: number): this {
		this.condition(this.cmp32(3, addr, value));
		return this;
	}

	ifGt32(addr: number, value: number): this {
		this.condition(this.cmp32(4, addr, value));
		return this;
	}

	ifEq32(addr: number, value: number): this {
		this.condition(this.cmp32(5, addr, value));
		return this;
	}

	ifNe32(addr: number, value: number): this {
		this.condition(this.cmp32(6, addr, value));
		return this;
	}

	/** (byte[addr] & mask) != 0 */
	ifAnyBit8(addr: number, mask: number): this {
		this.condition(
			this.cmp8(6, addr, 0, assertRange(mask, 0xFF, "ifAnyBit8 mask")),
		);
		return this;
	}

	/** (byte[addr] & mask) == mask */
	ifAllBits8(addr: number, mask: number): this {
		const bits = assertRange(mask, 0xFF, "ifAllBits8 mask");
		this.condition(this.cmp8(5, addr, bits, bits));
		return this;
	}

	/** (half[addr] & mask) != 0 */
	ifAnyBit16(addr: number, mask: number): this {
		this.condition(
			this.cmp16(6, addr, 0, assertRange(mask, 0xFFFF, "ifAnyBit16 mask")),
		);
		return this;
	}

	/** (half[addr] & mask) == mask */
	ifAllBits16(addr: number, mask: number): this {
		const bits = assertRange(mask, 0xFFFF, "ifAllBits16 mask");
		this.condition(this.cmp16(5, addr, bits, bits));
		return this;
	}

	/** 任意マスクの16bit比較。通常は ifAnyBit16 / ifAllBits16 を使う。 */
	ifEq16Masked(addr: number, value: number, mask: number): this {
		this.condition(this.cmp16(5, addr, value, mask));
		return this;
	}

	/** 開いている条件をすべて閉じる */
	endAllIf(): this {
		if (!this.openIf) {
			throw new Error("endAllIf() called without an open condition");
		}
		this.append([0xD2000000, 0]);
		this.openIf = false;
		return this;
	}

	/** E コードでバイト列（32bit ワード列）を書き込む */
	patch(dest: number, words: readonly number[]): this {
		const byteLength = words.length * 4;
		const padded = words.slice();
		if (padded.length % 2 === 1) padded.push(0);

		this.append([
			u32(0xE0000000 + assertU32(dest, "patch destination")),
			assertU32(byteLength, "patch length"),
		]);
		this.append(padded);
		return this;
	}

	/** モジュール本体とフックをこのコードに含める */
	include(mod: Module): this {
		if (this.openIf) {
			throw new Error("include() must be called before conditions");
		}
		if (this.words.length > 0) {
			throw new Error("include() must be called before other code");
		}

		// 配置先がまだ 0 のときだけコードを書き込む
		this.ifEq32(mod.origin, 0);
		this.patch(mod.origin, mod.bin);
		this.endAllIf();

		this.append(mod.hooks.words);
		Object.assign(this.symbols, mod.symbols);
		return this;
	}

	/** 関数を丸ごと差し替える */
	replaceFunction(
		targetFunc: number,
		options: { at: number; expected: Instruction; resumeAt?: number },
	): this {
		assertAligned(options.at, 4, "replaceFunction address");
		this.ifEq32(options.at, instructionCode(options.expected));
		this.write32(options.at, call(options.at, targetFunc));

		if (options.resumeAt !== undefined) {
			const addr = options.at + 4;
			this.write32(addr, jump(addr, options.resumeAt));
		}

		this.endAllIf();
		return this;
	}

	/** 指定アドレスの命令を自作関数へのジャンプに置き換える */
	jumpToAt(
		targetFunc: number,
		options: { at: number; expected: Instruction },
	): this {
		assertAligned(options.at, 4, "jumpToAt address");
		this.ifEq32(options.at, instructionCode(options.expected));
		this.write32(options.at, jump(options.at, targetFunc));
		this.endAllIf();
		return this;
	}

	/** 関数の先頭で即座に return させる */
	earlyReturnAt(options: { at: number; expected: Instruction }): this {
		assertAligned(options.at, 4, "earlyReturnAt address");
		this.ifEq32(options.at, instructionCode(options.expected));
		this.write32(options.at, ARM_RET);
		this.endAllIf();
		return this;
	}

	/** 既存の bl 命令の呼び出し先だけを差し替える */
	retargetCallAt(options: { at: number; from: number; to: number }): this {
		assertAligned(options.at, 4, "retargetCallAt address");
		const expected = call(options.at, options.from);
		this.ifEq32(options.at, expected);
		this.write32(options.at, call(options.at, options.to));
		this.endAllIf();
		return this;
	}

	toString(name: string): string {
		if (this.openIf) {
			throw new Error(`Unclosed condition in "${name}": call endAllIf()`);
		}
		if (this.words.length % 2 !== 0) {
			throw new Error(`Odd code word count in "${name}"`);
		}

		const lines = [`[${name}]`];
		for (let i = 0; i < this.words.length; i += 2) {
			lines.push(
				`${this.words[i].toString(16).toUpperCase().padStart(8, "0")} ${this.words[
					i + 1
				]
					.toString(16)
					.toUpperCase()
					.padStart(8, "0")}`,
			);
		}
		return `${lines.join("\r\n")}\r\n`;
	}
}

/** コード／BSS の配置を管理する */
export class RamAllocator {
	codeCursor: number;
	bssCursor: number;
	readonly bssOrigin: number;
	readonly endAddr: number;
	private readonly rootDir: string;

	constructor(rootDir: string, codeAddr: number, bssAddr: number, endAddr: number) {
		this.rootDir = rootDir;
		this.codeCursor = codeAddr;
		this.bssCursor = bssAddr;
		this.bssOrigin = bssAddr;
		this.endAddr = endAddr;
	}

	allocateCode(size: number, context: string): void {
		this.codeCursor += size;
		if (this.codeCursor > this.bssOrigin) {
			throw new Error(
				`Code allocation for '${context}' overlaps BSS region.\n` +
					`Code limit: 0x${this.codeCursor.toString(16).toUpperCase()} (size: 0x${size.toString(16).toUpperCase()})\n` +
					`BSS start:  0x${this.bssOrigin.toString(16).toUpperCase()}`,
			);
		}
	}

	createModule(filePath: string, hooks: readonly HookSpec[] = []): Module {
		const origin = this.codeCursor;
		const lib = compile(this.rootDir, filePath, origin, this.bssCursor);

		this.allocateCode(lib.bin.length * 4, `${filePath} (Main Body)`);

		const bssEnd = lib.symbols["__bss_end"];
		if (bssEnd !== undefined) {
			this.bssCursor = bssEnd;
			if (this.bssCursor > this.endAddr) {
				throw new Error(
					`BSS allocation for '${filePath}' exceeds memory limit.\n` +
						`BSS limit:  0x${this.bssCursor.toString(16).toUpperCase()}\n` +
						`Memory End: 0x${this.endAddr.toString(16).toUpperCase()}`,
				);
			}
		}

		const mod: Module = {
			path: filePath,
			bin: lib.bin,
			symbols: lib.symbols,
			origin,
			hooks: new CodeBuilder(),
			ram: this,
			sym(name) {
				const value = mod.symbols[name];
				if (value === undefined) {
					const available = Object.keys(mod.symbols).sort().join(", ");
					throw new Error(
						`Symbol "${name}" not found in ${filePath}. Available: ${available}`,
					);
				}
				return value;
			},
		};

		for (const spec of hooks) {
			this.addHook(mod, spec);
		}

		return mod;
	}

	private addHook(mod: Module, spec: HookSpec): void {
		if (spec.returnWith !== undefined && spec.resumeAt !== undefined) {
			throw new Error(
				`Hook "${spec.symbol}": returnWith and resumeAt cannot be used together`,
			);
		}
		assertAligned(spec.at, 4, `Hook "${spec.symbol}" address`);

		const targetAddr = mod.sym(spec.symbol);
		const originalCode = instructionCode(spec.expected);
		const trampolineAddr = this.codeCursor;

		// トランポリン: レジスタ退避 -> C 関数呼び出し -> 復帰
		const trampoline = [
			ARM_PUSH,
			call(trampolineAddr + 4, targetAddr),
			ARM_POP,
		];

		if (spec.returnWith !== undefined) {
			trampoline.push(instructionCode(spec.returnWith));
		} else if (spec.resumeAt !== undefined) {
			trampoline.push(
				jump(trampolineAddr + trampoline.length * 4, spec.resumeAt),
			);
		} else {
			trampoline.push(originalCode);
			trampoline.push(
				jump(trampolineAddr + trampoline.length * 4, spec.at + 4),
			);
		}

		mod.bin.push(...trampoline);

		mod.hooks
			.ifEq32(spec.at, originalCode)
			.write32(spec.at, jump(spec.at, trampolineAddr))
			.endAllIf();

		this.allocateCode(
			trampoline.length * 4,
			`${mod.path}::${spec.symbol} (Hook Trampoline)`,
		);
	}
}
