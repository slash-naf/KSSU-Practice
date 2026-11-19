# C言語によるDSの改造コード開発

## 環境構築

必要なものは主に3つ：
- **devkitPro**: DS用のプログラムをコンパイルするためのツールチェーン。
- **Node.js 24以降**: CコードのビルドとAction Replayコードの生成を行うTypeScriptを実行するためのランタイム。
- **Luaを導入済みのDeSmuME**: 生成したコードをゲームに適用し、動作確認するためのエミュレータ。

---

### devkitPro のインストール

devkitProは、任天堂ハードウェア向けの非公式開発ツールセット。今回はコンパイルしたいだけなので、別の方法で普通にコンパイラだけインストールするだけでもよい。

#### Windows の場合

[devkitProのGitHubリリースページ](https://github.com/devkitPro/installer/releases/latest) から、最新のインストーラ (`devkitProUpdater-x.x.x.exe`) をダウンロードして実行。「Check components」で「NDS Development」にだけチェック。

#### macOS / Linux の場合

[公式サイト](https://devkitpro.org/wiki/Getting_Started)の手順に従い、パッケージマネージャ経由でインストール。
共通して、以下のコマンドで `nds-dev` グループをインストール。

```bash
sudo dkp-pacman -S nds-dev
```

#### arm-none-eabi-gcc を使用できるようにする

環境変数に `C:\devkitPro\devkitARM\bin` を追加。
ターミナルを開き、以下のコマンドを実行してバージョンが表示されれば成功。

```bash
arm-none-eabi-gcc --version
```

---

### Node.js のインストール

TypeScriptをビルドスクリプトとして直接実行するため、**Node.js 24以降**をインストールする。
[Node.js 公式サイト](https://nodejs.org/)からインストーラをダウンロードするか、パッケージマネージャ経由で導入する。

ターミナルを開き、以下のコマンドでバージョンが表示されれば成功。

```bash
node --version
```

プロジェクトのルートで依存パッケージをインストールする。

```bash
npm install
```

---

### DeSmuMEのインストールとLuaの導入

Action Replayコードの即時実行には、Luaスクリプト機能を備えた **DeSmuME** エミュレータを使用。

1. **ダウンロード**
   [DeSmuME 公式サイト](http://desmume.org/download/) または [GitHub Releases](https://github.com/TASEmulators/desmume/releases) から最新のビルドをダウンロード。

2. **Luaスクリプトの導入**
   [Luaの公式サイト](https://luabinaries.sourceforge.net/download.html)から`LuaBinaries 5.1.5 - Release 1`の`lua5_1_5_Win64_dll8_lib.zip`をクリックしてSOURCEFORGEに飛び、`5.1.5`→`Windows Libraries`→`Dynamic`へ移動し、`lua-5.1.5_Win64_dll17_lib.zip`をダウンロードして解凍。`lua5.1.dll`をDeSmuMeがあるフォルダに置き、`lua51.dll`にリネーム。

3. **Luaウィンドウの確認**
   DeSmuMEを起動し、メニューバーの `Tools` > `Lua Scripting` > `New Lua Script Window` が開けることを確認。ここから `.lua` ファイルをロードして使用。


## C言語のコードをAction Replayコードに変換する仕組み

ビルドとAction Replayコードの生成は **TypeScript** (`build.ts` / `tools/scripts/`) が担当する。
Lua (`exec.lua` / `tools/desmume/ActionReplay.lua`) はTypeScriptが生成したARコードを読み込み、DeSmuME上で実行するだけにしている。

### コンパイルとリンク

C言語で書いたコードを実行可能な形にするまでの流れ。

1. **コンパイル (.c → .o)**: ソースコードを機械語に変換。
2. **リンク (.o → .elf)**: 複数のファイルをまとめ、**リンカスクリプト** (`linker.ld`)によってメモリ上の配置を決定。
3. **バイナリ抽出 (.elf → .bin)**: ELFファイルには実行に不要な管理情報が含まれているため、純粋な機械語部分だけを切り出す。
この `.bin` ファイルの中身を16進数文字列に変換し、これをメモリに書き込むAction Replayコードとして整形。

### フックとジャンプ

コードをメモリに置いただけでは実行されない。ゲームの処理の一部を書き換え（フック）、自作コードへジャンプさせる必要がある。

```text
【フック前】
020017C0: E3540000  ; 元の命令 (cmp r4, #0)

【フック後】
020017C0: EAXXXXXX  ; ジャンプ命令 (b 023FE000)

【自作コード】
XXXXXXXX: E92D5FFF  ; stmdb r13!,{r0-r12,r14}; レジスタの退避(状態を保存する)
          ...       ; 自作コード
          E8BD5FFF  ; ldmia r13!,{r0-r12,r14}; レジスタの復元(元の状態に戻す)
          E3540000  ; 元の命令を実行 (cmp r4, #0)
          EAXXXXXX  ; 元の場所に戻る (b 02001830)
```

## プロジェクト構造

プロジェクトに含まれる各ファイルの役割を解説。

### ディレクトリ構成

```text
KSSU-Practice/
├── build.ts             # ビルド設定・チート一覧
├── exec.lua             # ユーザ用：ビルド実行＆実行設定スクリプト
├── makefile             # コンパイル設定ファイル
├── linker.ld            # メモリ配置設定ファイル
├── dump_to_json.mjs     # ログのJSON変換ツール
├── source/              # C言語のソースコードを入れる場所
│   ├── QSQL.c           # クイックセーブ・クイックロード機能
│   ├── ghost.c          # ゴースト機能
│   ├── seed_advances.c  # 乱数監視機能
│   ├── log_dump.c       # 乱数ログ記録機能
│   └── symbols.h        # ゲーム内アドレス・定数の定義
├── tools/               # 開発用の内部ファイル
│   ├── scripts/         # ビルド＆ARコード生成エンジン (TypeScript)
│   │   ├── ar.ts        # モジュール配置・フック・ARコード生成
│   │   ├── output.ts    # dist / build への出力
│   │   └── formats/     # チート・ゲーム情報と出力フォーマット
│   └── desmume/         # DeSmuME 用の Lua モジュール・API定義
│       ├── ActionReplay.lua  # 生成済みARコードの読み込みと実行
│       └── desmume_api.lua   # Lua Language Server 用のAPI定義
├── dist/                # 生成物 (Git管理外)
│   ├── KIRBY_USDX_J_YKWJ01_00.dct
│   ├── usrcheat.dat
│   └── cheats.ar
├── build/               # 中間ファイル (Git管理外)
├── package.json         # npm スクリプト・依存パッケージ
├── tsconfig.json        # TypeScript 設定
└── compile_flags.txt    # clangd 用コンパイル設定
```

### 各ファイルの役割

#### `source/` ディレクトリ
C言語のプログラム (`.c`) およびヘッダ (`.h`) をこの中に保存。
コンパイル対象となるソースコードは、スクリプトからファイル名指定で呼び出される。

#### `source/symbols.h`
ゲーム内の既存の変数アドレス、定数、マクロ定義を記述するヘッダファイル。

#### `exec.lua`
DeSmuME上で実行するメインLuaスクリプト。
TypeScriptのビルドを実行し、生成されたARコードを読み込んで毎フレーム適用する。
どのチートをDeSmuME上で実行するかは `runtime_cheat_names` に記述する。

#### `build.ts`
ビルド設定とチートの一覧を記述するメインスクリプト。
メモリ配置、モジュールの読み込み、フックの設定、各チートの生成を行う。
`.dct` / `usrcheat.dat` / `cheats.ar` の出力は `writeOutputs` に任せる。

ゲームごとのメタ情報（ゲームID、CRC、ゲーム名、シリアル、`.dct` ファイル名）とチート一覧は `Game` クラスで定義し、`games` 配列に追加する。
`games` に複数のゲームを追加すると、ゲームごとに `.dct` が出力され、すべてのゲームが `usrcheat.dat` に含まれる。

```ts
import { Game } from "./tools/scripts/formats/cheat.ts";
import { writeOutputs } from "./tools/scripts/output.ts";

/** usrcheat.dat のデータベース名 */
const databaseName = "KSSU-Practice v3.3";

const games: Game[] = [
	new Game({
		id: "YKWJ",                          // ゲームID
		crc: 0x776dde8f,                     // ゲームコードのCRC32
		name: "KIRBY USDX J",                // ゲーム名
		serial: "NTR-YKWJ-JPN",              // シリアル
		dctFileName: "KIRBY_USDX_J_YKWJ01_00.dct",
		cheats: createKirbyCheats(),         // チート一覧
	}),
];

writeOutputs({ rootDir, databaseName, games });
```

チートは `{ name, enabled, code }` の形で管理する。
- `enabled`: チートを初期状態で有効にするか。
- DeSmuME上で実行するチートは `exec.lua` の `runtime_cheat_names` で指定する。

#### `tools/scripts/ar.ts`
TypeScript版のビルド＆ARコード生成エンジン。
- **コマンドの実行**: `make` コマンドを呼び出し、C言語ファイルをコンパイル・リンクさせる。
- **バイナリの抽出**: 生成された `.bin` ファイルとシンボル情報を読み込む。
- **ARコード生成**: バイナリデータをAction Replayの形式 (Eコードなど) に変換。

#### `tools/scripts/output.ts`
`writeOutputs({ rootDir, databaseName, games })` で以下をまとめて出力する。
- ゲームごとの `.dct`
- 全ゲームを含む `usrcheat.dat`
- 全チートの AR コード (`dist/cheats.ar`。Lua で実行するものは `exec.lua` で選択)

出力先に既存ファイルがあり、生成結果がそれと一致しない場合は、上書き前に `dist/backup/` へバックアップが作成される。内容が同じファイルは書き換えない。ビルド結果が既存ファイルと一致したかどうかは `dist: up to date` / `dist: updated` の1行で表示する。

#### `tools/scripts/formats/`
チート・ゲーム情報と出力フォーマットの実装。
- `cheat.ts`: チートの `Cheat` インターフェースと、ゲームのメタ情報（ID、CRC、ゲーム名、シリアル、`.dct` ファイル名）・チート一覧を保持する `Game` クラス。
- `dct.ts`: `writeDct(game)` で1ゲーム分の DeSmuME用チートファイル (`.dct`) を生成。
- `usrcheat.ts`: `writeUsrCheat(databaseName, games)` で複数ゲームを含むR4用チートデータベース (`usrcheat.dat`) を生成。

#### `tools/desmume/ActionReplay.lua`
生成済みARコードの読み込みと実行のみを行うモジュール。
- **ARコードの読み込み**: `dist/cheats.ar` を解析してチートごとのコード列にする。
- **エミュレータへの注入**: 読み込んだコードを DeSmuME のメモリに直接書き込み、効果を発揮させる。

#### `tools/desmume/desmume_api.lua`
Lua Language Server 向けのDeSmuME Lua API定義。編集ツールの補完用であり、実行時には使用しない。

#### `linker.ld`
リンカスクリプト。各セクション（`.text`, `.rodata`, `.data`, `.bss`）のメモリ配置設定を行うほか、ゲームの既存の関数のアドレスはここに書く。

- **既存関数の定義構文**:
  `PROVIDE(シンボル名 = アドレス);` の形式で定義する。
  ```ld
  /* linker.ld */
  PROVIDE(draw_image  = 0x0200FE64);
  PROVIDE(advance_RNG = 0x0200B860);
  PROVIDE(randi       = 0x0200B8A4);
  ```
- **C言語ソースからの呼び出し方**:
  C側でプロトタイプ宣言（外部参照宣言）を行えば、通常の C関数と同様に直接呼び出せる。
  ```c
  // Cソースコード側
  extern void draw_image(uint32_t img_id, int x, int y);
  extern uint32_t randi(uint32_t max);

  void MyFunction(void) {
      draw_image(10, 100, 50); // ゲーム内関数を直接実行
  }
  ```

#### `makefile`
通常は編集する必要はない。
`make`（または `make all`）で `build.ts` を実行して `dist/` にチート一式を出力する。
`tools/scripts/ar.ts` からは `make module SRC=... ADDR=... BSS=...` のようにモジュール指定で呼び出され、指定されたソースコードを指定されたアドレス向けにビルドするように設計されている。

## ベアメタル

本環境はCランタイムやOSが存在しないベアメタル環境である。通常のPC向けC言語とは異なる以下の制約に注意する必要がある。

### 標準ライブラリ（libc）の不在 (`-nostdlib`)
`printf`, `malloc`, `free`, `memcpy`, `memset` などの標準ライブラリ関数は一切存在しない。
- メモリの動的確保は行わず、大域配列として静的に確保する。

### 整数除算命令の不在 (ARMv5TE)
ニンテンドーDSの ARM946E-S はハードウェア除算命令を持たない。
C言語で `/` や `%` を使用すると、コンパイラが暗黙に `__aeabi_uidiv` 等のランタイム関数を要求し、未定義シンボルエラーでビルドが失敗する。

### セクション管理（.data の最小化と .bss の活用）
- **初期値を持つ大域変数** は `.data` に入り、バイナリサイズ（ARコード行数）を肥大化させる。
- **初期値を持たない大域変数** は `.bss` に入り、バイナリサイズには影響しない。
- 巨大な配列やバッファには初期化子を付けず、`.bss` に配置したほうがよい。初期化が必要なポインタ配列のみ `.data` に置く。


## 開発ワークフロー

C言語でコードを書き、それをゲーム内で実行するまでの一連の流れ（開発サイクル）を解説。
前提として、`build.ts`、`exec.lua`、`tools/`、`makefile`、`linker.ld`、`package.json` を作業フォルダに配置し、`npm install` を実行しておく必要がある。

### コーディング

`source` フォルダ内に `.c` ファイルを作成し、実行したい処理の関数を記述する。
第1引数にはフック時にレジスタを退避したメモリへのポインタ（`int32_t* r`）が渡される。`r0` から `r12` はそのまま `r[0]` から `r[12]`、`r14`（戻り先アドレス lr）は `r[13]` に対応しており、元のレジスタの値を参照したり書き換えたりできる。
例として `source/MyCode.c` を作成する場合：

```c
// source/MyCode.c
#include <stdint.h>

void RunMyCode(int32_t* r) {
	// ここに処理を書く
	*(int32_t*)0x0205B3C0 = 9999999;
	r[0] = 9999999; // 元の r0 レジスタの値を書き換える
}
```

### フックとパッチ設定

`build.ts` を開き、作成したファイルを読み込んでフックする設定を記述する。

#### モジュールの読み込みとフック

`RamAllocator` がコード領域と BSS 領域を管理する。`createModule` で C ソースをコンパイルし、`CodeBuilder` の第2引数に渡すと、モジュール本体とフックが自動的にコードの先頭へ追加される。

```ts
const ram = new RamAllocator(rootDir, 0x022c0000, 0x022c2000, 0x02368000);

const myCheat = new CodeBuilder(
	(code) => {
		// フックだけでは完結しない処理はここに書く
		code.write32(0x022c1000, 0x12345678);
		code.write16(0x0205b3c0, 9999);
		code.write8(0x0205e76c, 0);
	},
	ram.createModule("MyCode.c", [
		{
			symbol: "RunMyCode",                       // 呼び出す C 関数のシンボル名
			at: 0x02001830,                            // フックを挿入するアドレス
			expected: insn(0xe8bd8010, "ldmia sp!, {r4, pc}"), // 上書きされる元の命令
			returnWith: insn(0xe8bd8010, "ldmia sp!, {r4, pc}"), // フック後の命令
		},
	]),
);
```

- `expected`: フック対象の命令。実際の命令と一致したときだけフックが適用される（バージョン違いの事故防止）。
- `returnWith` / `resumeAt`: フック後の動作。`returnWith` は指定された命令を実行し、`resumeAt` は指定アドレスへジャンプする。どちらも省略すると、元の場所から再開する。

トランポリンコード（レジスタ退避 → C 関数呼び出し → 復帰）は自動生成される。

モジュールのシンボルはビルダーの `sym()` で取得する（存在しなければ例外）。`code.sym(...)` は自分のモジュール、`otherCheat.sym(...)` は別のチートのモジュールを参照する。

```ts
code.write32(otherCheat.sym("p_show"), code.sym("show"));
```

#### 条件コード

AR の条件分岐は `if*` メソッドで積み重ね、`endAllIf()` でまとめて閉じる。条件は AND で評価される。

```ts
code
	.ifEq32(0x0206b6a0, 0xa2400c21)
	.write32(0x0206b6a4, 0xe1a00000)
	.endAllIf();

code
	.ifEq8(0x0205b244, 0x000b)              // 8bit
	.ifAllBits16(0x02041e68, 0x0004)        // 16bit の全ビット
	.write32(0x022c2000, 0x022c2e30)
	.endAllIf();
```

- `ifLt8` / `ifGt8` / `ifEq8` / `ifNe8`: 8bit 比較。奇数アドレスもそのバイトだけを比較する。
- `ifLt16` / `ifGt16` / `ifEq16` / `ifNe16`: 16bit 比較（2バイト境界）。
- `ifLt32` / `ifGt32` / `ifEq32` / `ifNe32`: 32bit 比較（4バイト境界）。
- `ifAnyBit8` / `ifAnyBit16`: マスクしたビットのいずれかが立っている。
- `ifAllBits8` / `ifAllBits16`: マスクしたビットがすべて立っている。
- `ifEq16Masked`: 任意マスクの 16bit 比較。通常は上記のビット判定を使う。

`if*` を呼んだら、必ず `endAllIf()` で閉じること。閉じ忘れは `toString()` がエラーにする。

#### 関数・命令の書き換え

フックではなく、ゲーム側の命令を直接書き換える場合は以下のメソッドを使う。

| メソッド | 用途 |
| --- | --- |
| `override(callee, { at, expected, resumeAt?, returnWith? })` | `at` の命令を自作関数への `bl` に置き換え、`resumeAt` / `returnWith` で後続を制御する |
| `redirectFunction(target, { at, expected })` | 関数先頭の命令を自作関数への `b` に置き換える（戻らない） |
| `disableFunction({ at, expected })` | 関数先頭に `bx lr` を書き込み、即座に return させる |
| `retargetCall(at, oldTarget, newTarget)` | 既存の `bl` 命令の呼び出し先だけを差し替える |
| `retargetJump(at, oldTarget, newTarget)` | 既存の `b` 命令の飛び先だけを差し替える |

`redirectFunction` / `disableFunction` は関数先頭での使用を想定している。`override` は `lr` が退避済みの任意の命令位置で使える。

```ts
code.override(code.sym("ArenaImageSwitcher"), {
	at: 0x0206ce20,
	expected: insn(0xe3500007, "cmp r0, #7"),
	resumeAt: 0x0206cf68,
});

code.redirectFunction(code.sym("DrawNumbers"), {
	at: 0x02090d48,
	expected: insn(0xe92d41f0, "stmdb sp!, {r4-r8, lr}"),
});

code.disableFunction({
	at: 0x020904c8,
	expected: insn(0xe92d4ff8, "stmdb sp!, {r3-r11, lr}"),
});

code.retargetCall(0x020c42a0, 0x0200b8a4, code.sym("RandiWithUpdate"));
```

### ビルドと実行 (Build & Run)

#### コマンドラインでビルドする

プロジェクトのルートで以下を実行する。

```bash
make
```

`make` は `node --experimental-strip-types build.ts` を実行し、CソースのコンパイルとARコードの生成を行う（`npm run build` も同じ `make` を呼び出す）。
型チェックのみ行う場合は以下を実行する。

```bash
make typecheck
```

#### DeSmuME上で実行する

DeSmuME を起動し、ゲームを読み込む。

1. メニューの `Tools` > `Lua Scripting` > `New Lua Script Window` を開く。
2. `Browse...` をクリックし、`exec.lua` を選択して開く。
3. 自動的にビルドが実行される。
   - `exec.lua` が `make` を呼び出す。`make` と `node` にPATHが通っていること、カレントディレクトリがプロジェクトのルートであることを確認する。
   - ビルドログが表示される。エラーがあればここに表示されるため確認する。
4. ビルドが成功すると、`dist/cheats.ar` が読み込まれ、`exec.lua` の `runtime_cheat_names` に指定したチートが即座にゲーム内に適用される。
   - 生成されたコードがエミュレータ上のメモリへ即座に注入されるため、外部チート機能に手動登録する必要はない。
   - ソースコードや `build.ts` を修正したら、Luaウィンドウの `Restart` ボタンを押すだけで再ビルド・再適用される。その後チートが実行されていない状態をQLすればメモリが新しい処理に書き換わる。

### 完成コードの出力

ビルドすると、実機・フラッシュカード向けのファイルが `dist/` に出力される。

- `dist/KIRBY_USDX_J_YKWJ01_00.dct`: DeSmuME用のチートファイル（`games` の各ゲームごとに1ファイル）。
- `dist/usrcheat.dat`: R4等のフラッシュカード用チートデータベース。`games` の全ゲームが含まれる。実機ではこれをSDカードに配置して使用する。
- `dist/cheats.ar`: 全チートの AR コード。Lua 実行時はこのファイルが読み込まれる。

既存の出力ファイルと生成結果が一致しない場合、上書き前に `dist/backup/`（例: `dist/backup/usrcheat.dat`）へバックアップが作成される。一致する場合はバックアップも書き込みも行わない。

ビルド時は、出力が既存ファイルと一致したかどうかを示す1行だけを表示する（`dist: up to date` または `dist: updated`）。

ゲーム名・シリアル・CRCなどのメタ情報とデータベース名は `build.ts` で指定する。Luaの実行ログにはコード全文は出力されず、`dist/cheats.ar` を介して実行される。

## Action Replayコードの仕組み

Action Replay (AR) コードの全タイプ仕様一覧。

---

### 基本構造

ARコードは16進数で書かれ、**8桁 8桁** のペアで構成される：
```text
TTAAAAAA XXXXXXXX
│└─────┘ └──────┘
│   │        └── 値・データ
│   └── アドレス（下位24bit）
└── コードタイプ（上位4bit）
```

---

### 書き込みコード (Type 0x00 - 0x02)

メモリに定数を書き込む基本的な命令。

| タイプ | フォーマット        | 意味                                                            |
| :----- | :------------------ | :-------------------------------------------------------------- |
| 0x00   | `0XXXXXXX YYYYYYYY` | アドレス `[XXXXXXX + offset]` に32bit値 `YYYYYYYY` を書き込む。 |
| 0x01   | `1XXXXXXX 0000YYYY` | アドレス `[XXXXXXX + offset]` に16bit値 `YYYY` を書き込む。     |
| 0x02   | `2XXXXXXX 000000YY` | アドレス `[XXXXXXX + offset]` に8bit値 `YY` を書き込む。        |

| 例                  | 動作                              |
| :------------------ | :-------------------------------- |
| `0205B3C0 0098967F` | `*(int32_t*)0x0205B3C0 = 0x98967F;` |
| `1206C3EE 0000E3A0` | `*(int16_t*)0x0206C3EE = 0xE3A0;`   |
| `2205B3C4 00000063` | `*(int8_t*)0x0205B3C4 = 0x63;`      |

---

### 条件分岐コード (Type 0x03 - 0x0A)

条件が**真**の場合、次のコードブロックが実行される。
条件が**偽**の場合、`D0` または `D2` コードまでスキップされる。
`D0` は直前の if 文だけを閉じるが、`D2` はすべての if 文を閉じる。ただし、NitroHax では `D0` も `D2` と同じくすべての if 文を閉じる。

#### 32bit比較 (Type 0x03 - 0x06)

| タイプ | フォーマット        | 条件       |
| :----- | :------------------ | :--------- |
| 0x03   | `3XXXXXXX YYYYYYYY` | `[X] < Y`  |
| 0x04   | `4XXXXXXX YYYYYYYY` | `[X] > Y`  |
| 0x05   | `5XXXXXXX YYYYYYYY` | `[X] == Y` |
| 0x06   | `6XXXXXXX YYYYYYYY` | `[X] != Y` |

#### 16bit比較 + マスク (Type 0x07 - 0x0A)

| タイプ | フォーマット        | 条件              |
| :----- | :------------------ | :---------------- |
| 0x07   | `7XXXXXXX ZZZZYYYY` | `([X] & ~Z) < Y`  |
| 0x08   | `8XXXXXXX ZZZZYYYY` | `([X] & ~Z) > Y`  |
| 0x09   | `9XXXXXXX ZZZZYYYY` | `([X] & ~Z) == Y` |
| 0x0A   | `AXXXXXXX ZZZZYYYY` | `([X] & ~Z) != Y` |

#### 例

```text
94000130 FDFF0000   ; if((*(int32_t*)0x04000130 & 0x200) != 0){
2205B3C4 00000063   ;     *(int8_t*)0x0205B3C4 = 0x63;
3205B3C0 0098967F   ;     if(0x98967F > *(int32_t*)0x0205B3C0){
0205B3C0 0098967F   ;         *(int32_t*)0x0205B3C0 = 0x98967F;
D2000000 00000000   ;     }
                    ; }

94000130 FDFF0000   ; if((*(int32_t*)0x04000130 & 0x200) != 0){
7205B3C4 FF000063   ;     if((*(int16_t*)0x0205B3C4 & 0xFF) < 0x63){
2205B3C4 00000063   ;         *(int8_t*)0x0205B3C4 = 0x63;
D0000000 00000000   ;     }
3205B3C0 0098967F   ;     if(*(int32_t*)0x0205B3C0 < 0x98967F){
0205B3C0 0098967F   ;         *(int32_t*)0x0205B3C0 = 0x98967F;
D0000000 00000000   ;     }
D0000000 00000000   ; }
```

---

### オフセット/データレジスタ (Type 0x0B, 0xD3-0xDB)

ARエンジンには内部レジスタが存在する：
- **offset**: アドレス計算に加算される値
- **data**: 書き込み用のデータ

#### オフセット操作

| コード              | 動作                                               |
| :------------------ | :------------------------------------------------- |
| `BXXXXXXX 00000000` | `offset = [XXXXXXX + offset]` (メモリから読み込み) |
| `D3000000 XXXXXXXX` | `offset = XXXXXXXX` (直接設定)                     |
| `DC000000 XXXXXXXX` | `offset += XXXXXXXX` (加算)                        |

#### データレジスタ操作

| コード              | 動作                                                |
| :------------------ | :-------------------------------------------------- |
| `D4000000 XXXXXXXX` | `data += XXXXXXXX`                                  |
| `D5000000 XXXXXXXX` | `data = XXXXXXXX`                                   |
| `D6000000 XXXXXXXX` | `[XXXXXXXX + offset] = data (32bit)`, `offset += 4` |
| `D7000000 XXXXXXXX` | `[XXXXXXXX + offset] = data (16bit)`, `offset += 2` |
| `D8000000 XXXXXXXX` | `[XXXXXXXX + offset] = data (8bit)`, `offset += 1`  |
| `D9000000 XXXXXXXX` | `data = [XXXXXXXX + offset] (32bit)`                |
| `DA000000 XXXXXXXX` | `data = [XXXXXXXX + offset] (16bit)`                |
| `DB000000 XXXXXXXX` | `data = [XXXXXXXX + offset] (8bit)`                 |

---

### ループコード (Type 0x0C)

```text
C0000000 YYYYYYYY
```
ループ回数を `YYYYYYYY` に設定する。
`D1` または `D2` コードに到達すると、ループが実行される。

---

### 終了コード (Type 0xD0 - 0xD2)

| コード              | 動作                                                      |
| :------------------ | :-------------------------------------------------------- |
| `D0000000 00000000` | 条件ブロックの終了（直前のif文を閉じる）                  |
| `D1000000 00000000` | ループ実行（レジスタはクリアしない）                      |
| `D2000000 00000000` | ループ実行 + 全レジスタクリア（offset, data等をリセット） |

---

### パッチコード (Type 0x0E)

```text
EXXXXXXX YYYYYYYY
[データ...]
```
アドレス `[XXXXXXX + offset]` に `YYYYYYYY` バイトのデータを書き込む。

**これがC言語のバイナリをメモリに展開するために使う主要なコード。**

**例**: `0x023FE000` に8バイトのデータを書き込む
```text
E023FE00 00000008
01020304 05060708
```

> [!NOTE]
> データはリトルエンディアンで記述する。
> バイト列 `01 02 03 04` は `04030201` として記述する。

---

### メモリコピー (Type 0x0F)

```text
FXXXXXXX YYYYYYYY
```
`offset` から `XXXXXXX` へ `YYYYYYYY` バイトをコピーする（事前に `D3` で offset を設定しておく必要がある）。

**例**: `0x02000000` から `0x02100000` へ 256バイトコピー
```text
D3000000 02000000   ; offset = 0x02000000
F2100000 00000100   ; copy 256 bytes to 0x02100000
D2000000 00000000   ; reset
```
