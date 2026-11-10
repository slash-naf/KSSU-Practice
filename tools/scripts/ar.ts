import fs from "node:fs";
import path from "node:path";
import { execSync } from "node:child_process";

/** 32bit unsigned に丸める */
const u32 = (n: number): number => n >>> 0;

const ARM_PUSH = 0xE92D5FFF; // stmdb r13!,{r0-r12,r14}
const ARM_POP = 0xE8BD5FFF; // ldmia r13!,{r0-r12,r14}
const ARM_RET = 0xE12FFF1E; // bx r14

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

export interface Module {
	path: string;
	bin: number[];
	symbols: Record<string, number>;
	origin: number;
	hooks: CodeBuilder;
	ram: RamAllocator;
	hook(
		funcName: string,
		hookAddr: number,
		originalCode: number,
		retInfo?: number,
	): Module;
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

	append(values: number | number[]): this {
		if (Array.isArray(values)) {
			for (const value of values) this.words.push(u32(value));
		} else {
			this.words.push(u32(values));
		}
		return this;
	}

	write32(addr: number, value: number): this {
		this.append([addr, value]);
		return this;
	}

	write16(addr: number, value: number): this {
		this.append([u32(0x10000000 + addr), value & 0xFFFF]);
		return this;
	}

	write8(addr: number, value: number): this {
		this.append([u32(0x20000000 + addr), value & 0xFF]);
		return this;
	}

	/**
	 * 条件コード。mask を指定すると 16bit マスク比較になる。
	 * type: 3=lt, 4=gt, 5=eq, 6=ne
	 */
	private cmp(
		type: number,
		addr: number,
		value: number,
		mask?: number,
	): [number, number] {
		let codeAddr = u32(type * 0x10000000 + addr);

		if (mask === undefined) {
			return [codeAddr, u32(value)];
		}

		// 8bit アドレスの場合は 16bit 境界に揃える
		if (codeAddr % 2 === 1) {
			codeAddr -= 1;
			mask = (mask << 8) & 0xFFFF;
		}

		const invertedMask = (~mask) >>> 0;
		return [
			u32(codeAddr + 0x40000000),
			u32(value + ((invertedMask << 16) >>> 0)),
		];
	}

	ifLt(addr: number, value: number, mask?: number): this {
		this.append(this.cmp(3, addr, value, mask));
		return this;
	}

	ifGt(addr: number, value: number, mask?: number): this {
		this.append(this.cmp(4, addr, value, mask));
		return this;
	}

	ifEq(addr: number, value: number, mask?: number): this {
		this.append(this.cmp(5, addr, value, mask));
		return this;
	}

	ifNe(addr: number, value: number, mask?: number): this {
		this.append(this.cmp(6, addr, value, mask));
		return this;
	}

	endIf(): this {
		this.append([0xD2000000, 0]);
		return this;
	}

	/** E コードでバイト列（32bit ワード列）を書き込む */
	patch(dest: number, words: number[]): this {
		const byteLength = words.length * 4;
		const padded = words.slice();
		if (padded.length % 2 === 1) padded.push(0);

		this.append([u32(0xE0000000 + dest), byteLength]);
		this.append(padded);
		return this;
	}

	importModule(mod: Module): this {
		// 配置先がまだ 0 のときだけコードを書き込む
		this.ifEq(mod.origin, 0);
		this.patch(mod.origin, mod.bin);
		this.endIf();

		this.append(mod.hooks.words);
		Object.assign(this.symbols, mod.symbols);
		return this;
	}

	override(
		targetFunc: number,
		originalAddr: number,
		originalCode: number,
		retInfo?: number,
	): this {
		this.ifEq(originalAddr, originalCode);
		this.write32(originalAddr, call(originalAddr, targetFunc));

		if (retInfo !== undefined) {
			const addr = originalAddr + 4;
			if (retInfo < 0x10000000) {
				this.write32(addr, jump(addr, retInfo));
			} else {
				this.write32(addr, retInfo);
			}
		}

		this.endIf();
		return this;
	}

	redirect(targetFunc: number, originalAddr: number, originalCode: number): this {
		this.ifEq(originalAddr, originalCode);
		this.write32(originalAddr, jump(originalAddr, targetFunc));
		this.endIf();
		return this;
	}

	disable(originalAddr: number, originalCode: number): this {
		this.ifEq(originalAddr, originalCode);
		this.write32(originalAddr, ARM_RET);
		this.endIf();
		return this;
	}

	replaceCall(originalAddr: number, oldTarget: number, newTarget: number): this {
		this.ifEq(originalAddr, call(originalAddr, oldTarget));
		this.write32(originalAddr, call(originalAddr, newTarget));
		this.endIf();
		return this;
	}

	toString(name: string): string {
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

	createModule(filePath: string): Module {
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
			hook(funcName, hookAddr, originalCode, retInfo) {
				const targetAddr = mod.symbols[funcName];
				if (targetAddr === undefined) throw new Error(`Symbol not found: ${funcName}`);

				// トランポリン: レジスタ退避 -> C 関数呼び出し -> 復帰
				const trampolineAddr = this.ram.codeCursor;
				const trampoline = [
					ARM_PUSH,
					call(trampolineAddr + 4, targetAddr),
					ARM_POP,
				];

				if (retInfo !== undefined) {
					if (retInfo < 0x10000000) {
						trampoline.push(jump(trampolineAddr + trampoline.length * 4, retInfo));
					} else {
						trampoline.push(retInfo);
					}
				} else {
					trampoline.push(originalCode);
					trampoline.push(
						jump(trampolineAddr + trampoline.length * 4, hookAddr + 4),
					);
				}

				this.bin.push(...trampoline);

				this.hooks
					.ifEq(hookAddr, originalCode)
					.write32(hookAddr, jump(hookAddr, trampolineAddr))
					.endIf();

				this.ram.allocateCode(
					trampoline.length * 4,
					`${this.path}::${funcName} (Hook Trampoline)`,
				);

				return this;
			},
		};

		return mod;
	}
}

/** 分配開始アドレス・BSS 開始アドレス・メモリ終端を指定して RAM マネージャを作る */
export function allocateRam(
	rootDir: string,
	codeAddr: number,
	bssAddr: number,
	endAddr: number,
): RamAllocator {
	return new RamAllocator(rootDir, codeAddr, bssAddr, endAddr);
}

export function newCode(): CodeBuilder {
	return new CodeBuilder();
}
