---@meta
-- Lua Language Server 用の DeSmuME Lua API 定義

---@class memory
memory = {}

---メモリから1バイト読み込む (符号なし)
---@param address number アドレス
---@return number
function memory.readbyte(address) end

---メモリから1バイト読み込む (符号あり)
---@param address number アドレス
---@return number
function memory.readbytesigned(address) end

---メモリから2バイト読み込む (符号なし)
---@param address number アドレス
---@return number
function memory.readword(address) end

---メモリから2バイト読み込む (符号あり)
---@param address number アドレス
---@return number
function memory.readwordsigned(address) end

---メモリから4バイト読み込む (符号なし)
---@param address number アドレス
---@return number
function memory.readdword(address) end

---メモリから4バイト読み込む (符号あり)
---@param address number アドレス
---@return number
function memory.readdwordsigned(address) end

---指定した範囲のメモリをバイト文字列として読み込む
---@param address number 開始アドレス
---@param length number 長さ
---@return string
function memory.readbyterange(address, length) end

---メモリに1バイト書き込む
---@param address number アドレス
---@param value number 値
function memory.writebyte(address, value) end

---メモリに2バイト書き込む
---@param address number アドレス
---@param value number 値
function memory.writeword(address, value) end

---メモリに4バイト書き込む
---@param address number アドレス
---@param value number 値
function memory.writedword(address, value) end

---アドレスが有効かどうかを確認する
---@param address number アドレス
---@return boolean
function memory.isvalid(address) end

---CPUレジスタの値を取得する
---@param name string レジスタ名 ("r0"-"r15", "pc", "sp", "lr", "cpsr" など)
---@return number
function memory.getregister(name) end

---CPUレジスタに値を設定する
---@param name string レジスタ名
---@param value number 値
function memory.setregister(name, value) end

---VRAMから2バイト読み込む (エンジンA/Bに応じてマッピングが異なる場合があるため注意)
---@param address number アドレス
---@return number
function memory.vram_readword(address) end

---VRAMに2バイト書き込む
---@param address number アドレス
---@param value number 値
function memory.vram_writeword(address, value) end

---メモリ書き込み時に呼び出される関数を登録する (フック)
---@param address number 監視するアドレス
---@param func? function|nil コールバック関数 (引数なし)。nilで解除。
function memory.registerwrite(address, func) end

---メモリ読み込み時に呼び出される関数を登録する (フック)
---@param address number 監視するアドレス
---@param func? function|nil コールバック関数 (引数なし)。nilで解除。
function memory.registerread(address, func) end

---メモリ実行時に呼び出される関数を登録する (フック)
---@param address number 監視するアドレス
---@param func? function|nil コールバック関数 (引数なし)。nilで解除。
function memory.registerexec(address, func) end

---@class emu
emu = {}

---エミュレータを1フレーム進める
function emu.frameadvance() end

---エミュレータを一時停止する
function emu.pause() end

---エミュレータの一時停止を解除する
function emu.unpause() end

---現在のフレーム数を取得する
---@return number
function emu.framecount() end

---現在のエミュレーション速度 (fps) を取得する
---@return number
function emu.speed() end

---実行前/実行後に呼び出されるコールバック関数を登録する
---@param func function
function emu.registerbefore(func) end
function emu.registerafter(func) end

---@class gui
gui = {}

---エミュレータが描画を更新するたびに呼び出されるコールバック関数を登録する
---@param func function
function gui.register(func) end

---画面にピクセルを描画する
---@param x number X座標
---@param y number Y座標
---@param color number|string 色
function gui.pixel(x, y, color) end

---画面に線を描画する
---@param x1 number 始点X
---@param y1 number 始点Y
---@param x2 number 終点X
---@param y2 number 終点Y
---@param color number|string 色
function gui.line(x1, y1, x2, y2, color) end

---画面に短形を描画する
---@param x1 number 左上X
---@param y1 number 左上Y
---@param x2 number 右下X
---@param y2 number 右下Y
---@param fill_color number|string 塗りつぶし色
---@param outline_color number|string 枠線色
function gui.box(x1, y1, x2, y2, fill_color, outline_color) end

---画面にテキストを描画する
---@param x number X座標
---@param y number Y座標
---@param str string 文字列
---@param color? number|string 文字色
---@param back_color? number|string 背景色
function gui.text(x, y, str, color, back_color) end

---GUIレイヤーの不透明度を設定する
---@param alpha number 0.0 から 1.0
function gui.opacity(alpha) end

---@class joypad
joypad = {}

---現在のジョイパッドの状態を取得する
---@return table
function joypad.get() end

---ジョイパッドの状態を設定する (次のフレーム用)
---@param input table
function joypad.set(input) end

---@class input
input = {}

---マウス/タッチペンの位置とボタン状態を取得する
---@return table {x:number, y:number, left:boolean, ...}
function input.get() end

---@class savestate
savestate = {}

---セーブステートオブジェクトを作成する
---@param slot? number スロット番号 (省略時はファイルに関連付けられないオブジェクト)
---@return table
function savestate.create(slot) end

---ステートをファイルに保存する
---@param state table セーブステートオブジェクト
function savestate.save(state) end

---ステートをファイルからロードする
---@param state table セーブステートオブジェクト
function savestate.load(state) end

---@class movie
movie = {}

---現在のムービーモードを取得する
---@return string "record", "playback", nil
function movie.mode() end

---現在のフレーム数を取得する
---@return number
function movie.framecount() end

---@class sound
sound = {}
