import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

const U8_MAX = 0xFF;
const U16_MAX = 0xFFFF;
const U32_MAX = 0xFFFFFFFF;

// ARM 命令
const ARM_PUSH = 0xE92D5FFF; // stmdb r13!,{r0-r12,r14}
const ARM_POP = 0xE8BD5FFF; // ldmia r13!,{r0-r12,r14}
const ARM_RET = 0xE12FFF1E; // bx r14
const ARM_B = 0xEA000000;
const ARM_BL = 0xEB000000;
const BRANCH_OFFSET_MASK = 0x00FFFFFF;
const BRANCH_PC_BIAS = 2;

// Action Replay コードのプレフィックス
const AR_WRITE16 = 0x10000000;
const AR_WRITE8 = 0x20000000;
const AR_COND16 = 0x40000000;
const AR_END_IF = 0xD2000000;
const AR_PATCH = 0xE0000000;
const CONDITION_UNIT = 0x10000000;

// 条件コードの種類
const CMP_LT = 3;
const CMP_GT = 4;
const CMP_EQ = 5;
const CMP_NE = 6;

/** 32bit unsigned に丸める */
const u32 = (n: number): number => n >>> 0;

/** 16進数表記にする */
const hex = (value: number, width = 8): string =>
	value.toString(16).toUpperCase().padStart(width, "0");

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
	if (!Number.isInteger(value) || value < 0 || value > U32_MAX) {
		throw new Error(
			`${label} must be a 32bit unsigned integer: ${String(value)}`,
		);
	}
	return value;
}

function assertRange(value: number, max: number, label: string): number {
	if (!Number.isInteger(value) || value < 0 || value > max) {
		throw new Error(
			`${label} must be in 0x00000000..0x${hex(max)}: ${String(value)}`,
		);
	}
	return value;
}

function assertAligned(addr: number, alignment: number, label: string): void {
	if (addr % alignment !== 0) {
		throw new Error(
			`${label} must be ${alignment}-byte aligned: 0x${hex(addr)}`,
		);
	}
}

/** 分岐命令 (b / bl) を組み立てる */
function branch(opcode: number, from: number, to: number): number {
	const offset = u32((to - from) >>> 2);
	return u32(opcode + ((offset - BRANCH_PC_BIAS) & BRANCH_OFFSET_MASK));
}

const jump = (from: number, to: number): number => branch(ARM_B, from, to);
const call = (from: number, to: number): number => branch(ARM_BL, from, to);

/** シンボルを取得する。存在しなければ例外を投げる */
function resolveSymbol(
	symbols: Readonly<Record<string, number>>,
	name: string,
	source: string,
): number {
	const value = symbols[name];
	if (value === undefined) {
		const available = Object.keys(symbols).sort().join(", ");
		throw new Error(
			`Symbol "${name}" not found in ${source}. Available: ${available}`,
		);
	}
	return value;
}

interface BuildLibrary {
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

/** コンパイル済みの C モジュール */
export interface Module {
	path: string;
	bin: number[];
	symbols: Record<string, number>;
	origin: number;
	/** モジュールをゲームへ適用するフックコード */
	hooks: number[];
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
		`ADDR=0x${hex(origin)}`,
		`BSS=0x${hex(bss)}`,
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
	private readonly symbols: Readonly<Record<string, number>>;
	private readonly symbolSource: string;
	private openIf = false;

	/**
	 * @param build コード本体
	 * @param mod 含めるモジュール。本体とフックが先頭に追加される
	 */
	constructor(build?: (code: CodeBuilder) => void, mod?: Module) {
		this.symbols = mod?.symbols ?? {};
		this.symbolSource = mod?.path ?? "(no module)";

		if (mod) {
			// 配置先がまだ 0 のときだけモジュール本体を書き込む
			this.ifEq32(mod.origin, 0).patch(mod.origin, mod.bin).endAllIf();
			this.append(mod.hooks);
		}

		build?.(this);
	}

	/** モジュールのシンボルを取得する。存在しなければ例外を投げる */
	sym(name: string): number {
		return resolveSymbol(this.symbols, name, this.symbolSource);
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
		return this.append([addr, value]);
	}

	write16(addr: number, value: number): this {
		return this.append([
			u32(AR_WRITE16 + assertU32(addr, "write16 address")),
			assertRange(value, U16_MAX, "write16 value"),
		]);
	}

	write8(addr: number, value: number): this {
		return this.append([
			u32(AR_WRITE8 + assertU32(addr, "write8 address")),
			assertRange(value, U8_MAX, "write8 value"),
		]);
	}

	/** 32bit 比較コード */
	private cmp32(op: number, addr: number, value: number): [number, number] {
		assertAligned(addr, 4, "32bit condition address");
		return [
			u32(op * CONDITION_UNIT + assertU32(addr, "condition address")),
			assertU32(value, "condition value"),
		];
	}

	/**
	 * 16bit マスク比較コード。
	 * mask は比較するビット、value はマスク後の期待値。
	 */
	private cmp16(
		op: number,
		addr: number,
		value: number,
		mask: number,
	): [number, number] {
		assertAligned(addr, 2, "16bit condition address");
		const invertedMask = ~mask & U16_MAX;
		return [
			u32(
				op * CONDITION_UNIT +
					assertU32(addr, "condition address") +
					AR_COND16,
			),
			u32(value + (invertedMask << 16)),
		];
	}

	/** 条件コードを追加し、endAllIf() まで条件ブロックを開く */
	private condition(code: [number, number]): this {
		this.append(code);
		this.openIf = true;
		return this;
	}

	private if8(op: number, addr: number, value: number, mask = U8_MAX): this {
		const bits = assertRange(value, U8_MAX, "8bit condition value");
		const maskBits = assertRange(mask, U8_MAX, "8bit condition mask");
		const shift = (addr & 1) * 8;
		return this.condition(
			this.cmp16(op, addr & ~1, bits << shift, maskBits << shift),
		);
	}

	private if16(op: number, addr: number, value: number, mask = U16_MAX): this {
		return this.condition(
			this.cmp16(
				op,
				addr,
				assertRange(value, U16_MAX, "16bit condition value"),
				assertRange(mask, U16_MAX, "16bit condition mask"),
			),
		);
	}

	private if32(op: number, addr: number, value: number): this {
		return this.condition(this.cmp32(op, addr, value));
	}

	ifLt8(addr: number, value: number): this {
		return this.if8(CMP_LT, addr, value);
	}

	ifGt8(addr: number, value: number): this {
		return this.if8(CMP_GT, addr, value);
	}

	ifEq8(addr: number, value: number): this {
		return this.if8(CMP_EQ, addr, value);
	}

	ifNe8(addr: number, value: number): this {
		return this.if8(CMP_NE, addr, value);
	}

	ifLt16(addr: number, value: number): this {
		return this.if16(CMP_LT, addr, value);
	}

	ifGt16(addr: number, value: number): this {
		return this.if16(CMP_GT, addr, value);
	}

	ifEq16(addr: number, value: number): this {
		return this.if16(CMP_EQ, addr, value);
	}

	ifNe16(addr: number, value: number): this {
		return this.if16(CMP_NE, addr, value);
	}

	ifLt32(addr: number, value: number): this {
		return this.if32(CMP_LT, addr, value);
	}

	ifGt32(addr: number, value: number): this {
		return this.if32(CMP_GT, addr, value);
	}

	ifEq32(addr: number, value: number): this {
		return this.if32(CMP_EQ, addr, value);
	}

	ifNe32(addr: number, value: number): this {
		return this.if32(CMP_NE, addr, value);
	}

	/** (byte[addr] & mask) != 0 */
	ifAnyBit8(addr: number, mask: number): this {
		return this.if8(CMP_NE, addr, 0, mask);
	}

	/** (byte[addr] & mask) == mask */
	ifAllBits8(addr: number, mask: number): this {
		return this.if8(CMP_EQ, addr, mask, mask);
	}

	/** (half[addr] & mask) != 0 */
	ifAnyBit16(addr: number, mask: number): this {
		return this.if16(CMP_NE, addr, 0, mask);
	}

	/** (half[addr] & mask) == mask */
	ifAllBits16(addr: number, mask: number): this {
		return this.if16(CMP_EQ, addr, mask, mask);
	}

	/** 任意マスクの16bit比較。通常は ifAnyBit16 / ifAllBits16 を使う。 */
	ifEq16Masked(addr: number, value: number, mask: number): this {
		return this.if16(CMP_EQ, addr, value, mask);
	}

	/** 開いている条件をすべて閉じる */
	endAllIf(): this {
		if (!this.openIf) {
			throw new Error("endAllIf() called without an open condition");
		}
		this.openIf = false;
		return this.append([AR_END_IF, 0]);
	}

	/** E コードでバイト列（32bit ワード列）を書き込む */
	patch(dest: number, words: readonly number[]): this {
		const padded = [...words];
		if (padded.length % 2 === 1) padded.push(0);

		return this.append([
			u32(AR_PATCH + assertU32(dest, "patch destination")),
			words.length * 4,
		]).append(padded);
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

		return this.endAllIf();
	}

	/** 指定アドレスの命令を自作関数へのジャンプに置き換える */
	jumpToAt(
		targetFunc: number,
		options: { at: number; expected: Instruction },
	): this {
		assertAligned(options.at, 4, "jumpToAt address");
		return this.ifEq32(options.at, instructionCode(options.expected))
			.write32(options.at, jump(options.at, targetFunc))
			.endAllIf();
	}

	/** 関数の先頭で即座に return させる */
	earlyReturnAt(options: { at: number; expected: Instruction }): this {
		assertAligned(options.at, 4, "earlyReturnAt address");
		return this.ifEq32(options.at, instructionCode(options.expected))
			.write32(options.at, ARM_RET)
			.endAllIf();
	}

	/** 既存の bl 命令の呼び出し先だけを差し替える */
	retargetCallAt(options: { at: number; from: number; to: number }): this {
		assertAligned(options.at, 4, "retargetCallAt address");
		return this.ifEq32(options.at, call(options.at, options.from))
			.write32(options.at, call(options.at, options.to))
			.endAllIf();
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
			lines.push(`${hex(this.words[i])} ${hex(this.words[i + 1])}`);
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

	constructor(
		rootDir: string,
		codeAddr: number,
		bssAddr: number,
		endAddr: number,
	) {
		this.rootDir = rootDir;
		this.codeCursor = codeAddr;
		this.bssCursor = bssAddr;
		this.bssOrigin = bssAddr;
		this.endAddr = endAddr;
	}

	private allocate(size: number, context: string): void {
		this.codeCursor += size;
		if (this.codeCursor > this.bssOrigin) {
			throw new Error(
				`Code allocation for '${context}' overlaps BSS region.\n` +
					`Code limit: 0x${hex(this.codeCursor)} (size: 0x${hex(size)})\n` +
					`BSS start:  0x${hex(this.bssOrigin)}`,
			);
		}
	}

	createModule(filePath: string, hooks: readonly HookSpec[] = []): Module {
		const origin = this.codeCursor;
		const lib = compile(this.rootDir, filePath, origin, this.bssCursor);

		this.allocate(lib.bin.length * 4, `${filePath} (Main Body)`);

		const bssEnd = lib.symbols["__bss_end"];
		if (bssEnd !== undefined) {
			this.bssCursor = bssEnd;
			if (this.bssCursor > this.endAddr) {
				throw new Error(
					`BSS allocation for '${filePath}' exceeds memory limit.\n` +
						`BSS limit:  0x${hex(this.bssCursor)}\n` +
						`Memory End: 0x${hex(this.endAddr)}`,
				);
			}
		}

		const mod: Module = {
			path: filePath,
			bin: lib.bin,
			symbols: lib.symbols,
			origin,
			hooks: [],
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

		const target = resolveSymbol(mod.symbols, spec.symbol, mod.path);
		const expected = instructionCode(spec.expected);
		const trampolineAddr = this.codeCursor;

		// トランポリン: レジスタ退避 -> C 関数呼び出し -> 復帰
		const trampoline = [
			ARM_PUSH,
			call(trampolineAddr + 4, target),
			ARM_POP,
		];

		if (spec.returnWith !== undefined) {
			trampoline.push(instructionCode(spec.returnWith));
		} else if (spec.resumeAt !== undefined) {
			trampoline.push(
				jump(trampolineAddr + trampoline.length * 4, spec.resumeAt),
			);
		} else {
			trampoline.push(expected);
			trampoline.push(
				jump(trampolineAddr + trampoline.length * 4, spec.at + 4),
			);
		}

		mod.bin.push(...trampoline);

		const hook = new CodeBuilder();
		hook
			.ifEq32(spec.at, expected)
			.write32(spec.at, jump(spec.at, trampolineAddr))
			.endAllIf();
		mod.hooks.push(...hook.words);

		this.allocate(
			trampoline.length * 4,
			`${mod.path}::${spec.symbol} (Hook Trampoline)`,
		);
	}
}
