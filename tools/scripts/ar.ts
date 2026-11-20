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

/** 16進数表記にする */
const hex = (value: number, width = 8): string => value.toString(16).toUpperCase().padStart(width, "0");

/** ARコードの2ワード。prefix はコード種別、addr はアドレス、value は値 */
const arCode = (prefix: number, addr: number, value: number): [number, number] => [(prefix * 0x10000000 + addr) >>> 0, value >>> 0];

/** 命令コード。text はリスティング用の表示名。 */
export type Instruction = number | { readonly code: number; readonly text: string };

/** 書き換え対象。expected を省略すると words[0] と異なるときだけ書き込む。 */
export interface RewriteTarget {
	/** 書き換えるアドレス */
	readonly at: number;
	/** 書き換え前の命令 */
	readonly expected?: Instruction;
}

/** フック／上書き後の戻り方。returnWith と resumeAt は併用不可 */
export interface Continuation {
	/** 戻り先で実行する命令 (通常は return 命令) */
	returnWith?: Instruction;
	/** 戻り先アドレス */
	resumeAt?: number;
}

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
const branch = (opcode: number) => (from: number, to: number) => opcode + ((((to - from) >>> 2) - 2) & 0x00ffffff);
const jump = branch(0xea000000); // b
const call = branch(0xeb000000); // bl

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
export interface HookSpec extends Required<RewriteTarget>, Continuation {
	/** モジュール内の関数シンボル名 */
	symbol: string;
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
		"--no-print-directory",
		"module",
		`SRC=source/${filePath}`,
		`ADDR=0x${hex(origin)}`,
		`BSS=0x${hex(bss)}`,
	].join(" ");

	try {
		execSync(cmd, { cwd: rootDir, stdio: "pipe" });
	} catch (error) {
		// 失敗時だけコンパイラの出力を見せる
		const { stdout, stderr } = error as { stdout?: Buffer; stderr?: Buffer };
		const output = `${stdout ?? ""}${stderr ?? ""}`.trim();
		if (output) console.error(output);
		throw error;
	}

	const binPath = path.join(rootDir, "build", `${name}.bin`);
	const symPath = path.join(rootDir, "build", `${name}.txt`);

	const data = fs.readFileSync(binPath);
	const bin: number[] = [];
	for (let i = 0; i < data.length; i += 4) bin.push(data.readUInt32LE(i));

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
			// 未配置時だけモジュール本体を書き込む
			this.patch({ at: mod.origin }, mod.bin);
			this.append(mod.hooks);
		}

		build?.(this);
	}

	/** モジュールのシンボルを取得する。存在しなければ例外を投げる */
	sym(name: string): number {
		return resolveSymbol(this.symbols, name, this.symbolSource);
	}

	append(values: readonly number[]): this {
		for (const value of values) this.words.push(assertU32(value, "code word"));
		return this;
	}

	/** 書き込みコード (prefix: 0=32bit, 1=16bit, 2=8bit) */
	private write(prefix: 0 | 1 | 2) {
		return (addr: number, value: number): this =>
			this.append(
				arCode(
					prefix,
					assertU32(addr, "write address"),
					assertRange(value, [U32_MAX, U16_MAX, U8_MAX][prefix], "write value"),
				),
			);
	}

	write32 = this.write(0);
	write16 = this.write(1);
	write8 = this.write(2);

	/**
	 * 条件コード (op: 3=LT, 4=GT, 5=EQ, 6=NE)。
	 * 8bit は 16bit 条件の該当バイトに寄せる。
	 */
	private cmp(
		bits: 8 | 16 | 32,
		op: number,
		addr: number,
		value: number,
		mask = bits === 8 ? U8_MAX : U16_MAX,
	): [number, number] {
		assertAligned(addr, bits / 8, `${bits}bit condition address`);
		const base = assertU32(addr, "condition address");
		if (bits === 32) {
			return arCode(op, base, assertU32(value, "condition value"));
		}
		const shift = (addr & 1) * 8;
		const max = bits === 8 ? U8_MAX : U16_MAX;
		const m = assertRange(mask, max, `${bits}bit condition mask`) << shift;
		const v = assertRange(value, max, `${bits}bit condition value`) << shift;
		return arCode(op + 4, base & ~1, v + ((~m & U16_MAX) << 16));
	}

	/** 条件コードを追加し、endAllIf() まで条件ブロックを開く */
	private condition(code: [number, number]): this {
		this.append(code);
		this.openIf = true;
		return this;
	}

	/** 8/16bit 比較。mask は比較するビット */
	private cond(bits: 8 | 16, op: number) {
		return (addr: number, value: number, mask?: number): this =>
			this.condition(this.cmp(bits, op, addr, value, mask));
	}

	/** 32bit 比較 */
	private cond32(op: number) {
		return (addr: number, value: number): this =>
			this.condition(this.cmp(32, op, addr, value));
	}

	/** ビット判定 (all=false: いずれか、all=true: すべて) */
	private bit(bits: 8 | 16, all: boolean) {
		return (addr: number, mask: number): this =>
			this.cond(bits, all ? 5 : 6)(addr, all ? mask : 0, mask);
	}

	ifLt8 = this.cond(8, 3);
	ifGt8 = this.cond(8, 4);
	ifEq8 = this.cond(8, 5);
	ifNe8 = this.cond(8, 6);
	ifLt16 = this.cond(16, 3);
	ifGt16 = this.cond(16, 4);
	ifEq16 = this.cond(16, 5);
	ifNe16 = this.cond(16, 6);
	ifLt32 = this.cond32(3);
	ifGt32 = this.cond32(4);
	ifEq32 = this.cond32(5);
	ifNe32 = this.cond32(6);

	ifAnyBit8 = this.bit(8, false);
	ifAllBits8 = this.bit(8, true);
	ifAnyBit16 = this.bit(16, false);
	ifAllBits16 = this.bit(16, true);

	/** 開いている条件をすべて閉じる */
	endAllIf(): this {
		if (!this.openIf) {
			throw new Error("endAllIf() called without an open condition");
		}
		this.openIf = false;
		return this.append([0xd2000000, 0]);
	}

	/**
	 * expected と一致したとき words を書き込む。
	 * expected 省略時は words[0] と異なるときだけ書き込む。
	 * 3 ワード以下は write32、それ以上は E コードを使う。
	 */
	patch({ at, expected }: RewriteTarget, words: readonly number[]): this {
		if (words.length == 0) throw new Error("patch: words is empty");
		if (expected === undefined) this.ifNe32(at, words[0]);
		else this.ifEq32(at, instructionCode(expected));

		if (words.length > 3) {
			const padded = words.length % 2 === 1 ? [...words, 0] : words;
			this.append([
				...arCode(0xe, assertU32(at, "patch destination"), words.length * 4),
				...padded,
			]);
		} else {
			words.forEach((word, i) => this.write32(at + i * 4, word));
		}

		return this.endAllIf();
	}

	/**
	 * at の命令を callee への bl に置き換える。
	 * callee を終えると resumeAt へのジャンプか、returnWith の実行。
	 */
	override(
		callee: number,
		{
			at,
			expected,
			resumeAt,
			returnWith,
		}: Required<RewriteTarget> & Continuation,
	): this {
		if (resumeAt !== undefined && returnWith !== undefined) {
			throw new Error(
				"override: resumeAt and returnWith cannot be used together",
			);
		}
		const words = [call(at, callee)];
		if (resumeAt !== undefined) words.push(jump(at + 4, resumeAt));
		else if (returnWith !== undefined) {
			words.push(instructionCode(returnWith));
		}
		return this.patch({ at, expected }, words);
	}

	/** 関数先頭の命令を target への b に置き換える。*/
	redirectFunction(target: number, options: Required<RewriteTarget>): this {
		return this.patch(options, [jump(options.at, target)]);
	}

	/** 関数先頭に bx lr を書き込み、即座に return させる。*/
	disableFunction(options: Required<RewriteTarget>): this {
		return this.patch(options, [ARM_RET]);
	}

	/** at の bl oldTarget を bl newTarget に差し替える */
	retargetCall(at: number, oldTarget: number, newTarget: number): this {
		return this.patch({ at, expected: call(at, oldTarget) }, [
			call(at, newTarget),
		]);
	}

	/** at の b oldTarget を b newTarget に差し替える */
	retargetJump(at: number, oldTarget: number, newTarget: number): this {
		return this.patch({ at, expected: jump(at, oldTarget) }, [
			jump(at, newTarget),
		]);
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
		hook.patch({ at: spec.at, expected }, [
			jump(spec.at, trampolineAddr),
		]);
		mod.hooks.push(...hook.words);

		this.allocate(
			trampoline.length * 4,
			`${mod.path}::${spec.symbol} (Hook Trampoline)`,
		);
	}
}
