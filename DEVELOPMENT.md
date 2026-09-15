# C言語によるDSの改造コード開発

## 環境構築

必要なものは主に2つ：
- **devkitPro**: DS用のプログラムをコンパイルするためのツールチェーン。
- **Luaを導入済みのDeSmuME**: 作成したコードをゲームに適用し、動作確認するためのエミュレータ。

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

### DeSmuMEのインストールとLuaの導入

Action Replayコードの生成と即時実行には、Luaスクリプト機能を備えた **DeSmuME** エミュレータを使用。

1. **ダウンロード**
   [DeSmuME 公式サイト](http://desmume.org/download/) または [GitHub Releases](https://github.com/TASEmulators/desmume/releases) から最新のビルドをダウンロード。

2. **Luaスクリプトの導入**
   [Luaの公式サイト](https://luabinaries.sourceforge.net/download.html)から`LuaBinaries 5.1.5 - Release 1`の`lua5_1_5_Win64_dll8_lib.zip`をクリックしてSOURCEFORGEに飛び、`5.1.5`→`Windows Libraries`→`Dynamic`へ移動し、`lua-5.1.5_Win64_dll17_lib.zip`をダウンロードして解凍。`lua5.1.dll`をDeSmuMeがあるフォルダに置き、`lua51.dll`にリネーム。

3. **Luaウィンドウの確認**
   DeSmuMEを起動し、メニューバーの `Tools` > `Lua Scripting` > `New Lua Script Window` が開けることを確認。ここから `.lua` ファイルをロードして使用。


## C言語のコードをAction Replayコードに変換する仕組み

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
├── source/              # C言語のソースコードを入れる場所
│   ├── QSQL.c           # クイックセーブ・クイックロード機能
│   ├── ghost.c          # ゴースト機能
│   ├── seed_advances.c  # 乱数監視機能
│   ├── log_dump.c       # 乱数ログ記録機能
│   └── symbols.h        # ゲーム内アドレス・定数の定義
├── ActionReplay.lua     # ビルド＆ARコード生成エンジン
├── exec.lua             # ユーザ用：実行設定スクリプト
├── makefile             # コンパイル設定ファイル
└── linker.ld            # メモリ配置設定ファイル
```

### 各ファイルの役割

#### `source/` ディレクトリ
C言語のプログラム (`.c`) およびヘッダ (`.h`) をこの中に保存。
コンパイル対象となるソースコードは、スクリプトからファイル名指定で呼び出される。

#### `source/symbols.h`
ゲーム内の既存の変数アドレス、定数、マクロ定義を記述するヘッダファイル。

#### `exec.lua`
DeSmuME上で実行するメインLuaスクリプト。
モジュールの読み込み、メモリ配置、フックの設定、Action Replayコードの統合管理をここに記述。

```lua
local ar = require("ActionReplay")

-- メモリ管理マネージャの作成 (コード開始, BSS開始, メモリ終端)
local ram = ar.allocateRam(0x022C0000, 0x022C2000, 0x02368000)
local cheats = {}

-- QSQL モジュール
local qsqlMod = ram:createModule("QSQL.c")
	:hook("QS", 0x02001830, 0xE8BD8010)	-- ボタン入力処理の復帰直前にフック
	:hook("QL", 0x02074ED8, 0xE92D4008)	-- ロード進行状況の直前にフック
local QSQL = ar.newCode():import(qsqlMod)
table.insert(cheats, QSQL)
```

#### `ActionReplay.lua`
ARコードの生成と実行、コンパイルするためのコマンドの実行などを行うためのモジュール。
- **コマンドの実行**: 裏で `make` コマンドを呼び出し、C言語ファイルをコンパイル・リンクさせる。
- **バイナリの抽出**: 生成された `.bin` ファイルを読み込む。
- **ARコード生成**: バイナリデータをAction Replayの形式 (E0コードなど) に変換。
- **エミュレータへの注入**: 生成されたコードを DeSmuME のメモリに直接書き込み、即座に効果を発揮させる。

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
`ActionReplay.lua` から `make SRC=... ADDR=... BSS=...` のように引数付きで呼び出され、指定されたソースコードを指定されたアドレス向けにビルドするように設計されている。

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
前提として、`ActionReplay.lua` と `makefile`、`linker.ld` を作業フォルダに配置しておく必要がある。

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

`exec.lua` を開き、作成したファイルを読み込んでフックする設定を記述する。

[`ActionReplay.lua`](ActionReplay.lua) は用途に応じた複数のフック・パッチメソッドを提供する：

#### `hook(funcName, hookAddr, originalCode, [retInfo])`
指定アドレスの命令を自作関数呼び出しへ割り込ませる。トランポリンコードがレジスタの退避と復帰を自動で行う。
- `funcName`: 呼び出す C 関数のシンボル名
- `hookAddr`: フックを挿入するゲーム側のアドレス
- `originalCode`: フックによって上書きされる元の命令（32bit Hex）。自作コード終了後に実行される。
- `retInfo`（省略可）: フック後の戻り先。アドレスを指定した場合はそこへジャンプし、命令を指定した場合はその命令を実行して復帰する。

```lua
local myMod = ram:createModule("MyCode.c")
	:hook("RunMyCode", 0x02001830, 0xE8BD8010)
```

#### `override(targetFunc, originalAddr, originalCode, [retInfo])`
ゲーム側の処理を丸ごと自作関数で置き換える。

#### `replaceCall(originalAddr, oldTarget, newTarget)`
既存のサブルーチン呼び出し命令（`bl`）の呼び出し先アドレスのみを自作関数へ差し替える。

#### `redirect(targetFunc, originalAddr, originalCode)`
条件分岐やジャンプ処理を自作関数へ直接バイパスする。

#### `disable(originalAddr, originalCode)`
関数の先頭に `bx lr` (`0xE12FFF1E`) を書き込み、処理を即座に無効化（早期リターン）する。

### ビルドと実行 (Build & Run)

DeSmuME を起動し、ゲームを読み込む。

1. メニューの `Tools` > `Lua Scripting` > `New Lua Script Window` を開く。
2. `Browse...` をクリックし、`exec.lua` を選択して開く。
3. 自動的にビルドが実行される。
   - ビルドログが表示される。エラーがあればここに表示されるため確認する。
4. ビルドが成功すると、即座にゲーム内にコードが適用される。
   - `exec.lua` 内のコードがエミュレータ上のメモリへ即座に注入されるため、外部チート機能に手動登録する必要はない。
   - ソースコードを修正したら、Luaウィンドウの `Restart` ボタンを押すだけで再ビルド・再適用される。その後チートが実行されていない状態をQLすればメモリが新しい処理に書き換わる。

### 完成コードの出力

Luaスクリプトの実行ログ（Outputウィンドウ）には、生成されたAction Replayコードがテキストとして出力される。
これをコピーして `usrcheat.dat` に登録すれば実機でも動作する。

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
