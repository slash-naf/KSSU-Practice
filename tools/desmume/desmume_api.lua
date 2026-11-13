---@meta
-- Lua Language Server 用の DeSmuME Lua API 定義
-- 別名 (エイリアス) は定義しない

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

---現在のラグフレーム数を取得する
---@return number
function emu.lagcount() end

---現在のフレームがラグフレームかどうかを取得する
---@return boolean
function emu.lagged() end

---エミュレーションが開始されているかどうかを取得する
---@return boolean
function emu.emulating() end

---フレーム境界にいるかどうかを取得する
---@return boolean
function emu.atframeboundary() end

---現在のエミュレーション速度 (fps) を取得する
---@return number
function emu.speed() end

---エミュレーション速度モードを設定する
---@param mode "normal"|"nothrottle"|"turbo"|"maximum"|number モード名または数値
function emu.speedmode(mode) end

---エミュレーションを1フレーム進める (速度モードを適用)
function emu.emulateframe() end

---エミュレーションを高速に1フレーム進める (フレームスキップなし)
function emu.emulateframefastnoskipping() end

---エミュレーションを高速に1フレーム進める (ターボ)
function emu.emulateframefast() end

---エミュレーションを最高速で1フレーム進める (描画・音声なし)
function emu.emulateframeinvisible() end

---スクリプトの計算中にエミュレータを待機させる
function emu.wait() end

---画面を再描画する
function emu.redraw() end

---ROMのゲームコード (4文字) を取得する
---@return string
function emu.gamecode() end

---ROMのゲームコード (3文字) を取得する
---@return string
function emu.smallgamecode() end

---実行前/実行後に呼び出されるコールバック関数を登録する
---@param func function
function emu.registerbefore(func) end
---@param func function
function emu.registerafter(func) end

---エミュレーション開始時に呼び出されるコールバック関数を登録する
---@param func function
function emu.registerstart(func) end

---スクリプト終了時に呼び出されるコールバック関数を登録する
---@param func function
function emu.registerexit(func) end

---グローバル変数をスクリプト終了時に保存し、次回起動時に復元する
---@param variabletable table 変数名と既定値のテーブル
function emu.persistglobalvariables(variabletable) end

---エミュレータの情報メッセージを表示する
---@param str string メッセージ
function emu.message(str) end

---別の Lua スクリプトを開く
---@param filename string ファイル名
function emu.openscript(filename) end

---エミュレータをリセットする
function emu.reset() end

---Lua メニューを追加する
---@param menuName string メニュー名
---@param menuEntries table メニュー項目
function emu.addmenu(menuName, menuEntries) end

---Lua メニュー項目の情報を設定する
---@param menuItem function 対象のコールバック関数
---@param infoTable table {enabled?:boolean, checked?:boolean, name?:string}
function emu.setmenuiteminfo(menuItem, infoTable) end

---メニュー初期化時に呼び出されるコールバック関数を登録する
---@param func function
function emu.registermenustart(func) end

---3D イベント時に呼び出されるコールバック関数を登録する
---@param func function
function emu.register3devent(func) end

---3D 変換を設定する
---@param mode number モード
---@param matrix table 4x4 行列 (16要素)
function emu.set3dtransform(mode, matrix) end

---@class gui
gui = {}

---エミュレータが描画を更新するたびに呼び出されるコールバック関数を登録する
---@param func function
function gui.register(func) end

---画面にピクセルを描画する
---@param x number X座標
---@param y number Y座標
---@param color? number|string 色
function gui.pixel(x, y, color) end

---画面のピクセルの色を取得する
---@param x number X座標
---@param y number Y座標
---@return number r
---@return number g
---@return number b
function gui.getpixel(x, y) end

---画面に線を描画する
---@param x1 number 始点X
---@param y1 number 始点Y
---@param x2 number 終点X
---@param y2 number 終点Y
---@param color? number|string 色
---@param skipfirst? boolean 始点を描画しないか
function gui.line(x1, y1, x2, y2, color, skipfirst) end

---画面に短形を描画する
---@param x1 number 左上X
---@param y1 number 左上Y
---@param x2 number 右下X
---@param y2 number 右下Y
---@param fill_color? number|string 塗りつぶし色
---@param outline_color? number|string 枠線色
function gui.box(x1, y1, x2, y2, fill_color, outline_color) end

---画面にテキストを描画する
---@param x number X座標
---@param y number Y座標
---@param str string 文字列
---@param color? number|string 文字色
---@param outline_color? number|string 縁取り色
function gui.text(x, y, str, color, outline_color) end

---HUD と同じフォントでテキストを描画する
---@param x number X座標
---@param y number Y座標
---@param msg string 文字列
function gui.osdtext(x, y, msg) end

---GUIレイヤーの不透明度を設定する
---@param alpha number 0.0 から 1.0
function gui.opacity(alpha) end

---GUIレイヤーの透明度を設定する (旧API)
---@param transparency number 0.0 (不透明) から 4.0 (透明)
function gui.transparency(transparency) end

---表示するレイヤーを設定する (Windows フロントエンドのみ)
---@param main number メイン画面のレイヤービットマスク
---@param sub number サブ画面のレイヤービットマスク
function gui.setlayermask(main, sub) end

---色をパースして RGBA 成分を取得する
---@param color number|string 色
---@return number r
---@return number g
---@return number b
---@return number a
function gui.parsecolor(color) end

---メッセージボックスを表示する
---@param message string メッセージ
---@param type? "ok"|"yesno"|"yesnocancel"|"okcancel"|"abortretryignore" ボタンの種類
---@param icon? "message"|"notice"|"question"|"warning"|"error" アイコン
---@return string 選択されたボタン
function gui.popup(message, type, icon) end

---画面のスクリーンショットを GD 形式の文字列として取得する
---@param whichScreen? "top"|"bottom"|boolean|number 取得する画面
---@return string
function gui.gdscreenshot(whichScreen) end

---GD 形式の画像を画面に描画する
---@overload fun(gdimage: string, sx?: number, sy?: number, width?: number, height?: number, alphamul?: number)
---@param dx? number 描画先X
---@param dy? number 描画先Y
---@param gdimage string GD 形式の画像
---@param sx? number 転送元X
---@param sy? number 転送元Y
---@param width? number 幅
---@param height? number 高さ
---@param alphamul? number 不透明度の倍率
function gui.gdoverlay(dx, dy, gdimage, sx, sy, width, height, alphamul) end

---画面を再描画する
function gui.redraw() end

---@class joypad
joypad = {}

---現在のジョイパッドの状態を取得する
---@return table
function joypad.get() end

---現在押されているボタンだけを取得する
---@return table
function joypad.getdown() end

---現在押されていないボタンだけを取得する
---@return table
function joypad.getup() end

---ユーザーが現在押しているジョイパッドの状態を取得する
---@return table
function joypad.peek() end

---ユーザーが現在押しているボタンだけを取得する
---@return table
function joypad.peekdown() end

---ユーザーが現在押していないボタンだけを取得する
---@return table
function joypad.peekup() end

---ジョイパッドの状態を設定する (次のフレーム用)
---@param input table
function joypad.set(input) end

---@class input
input = {}

---マウス/タッチペンの位置とボタン状態を取得する
---@return table {x:number, y:number, left:boolean, ...}
function input.get() end

---ホットキーが押されたときに呼び出される関数を登録する
---@param keynum number ホットキー番号 (1-16)
---@param func? function|nil コールバック関数。nilで解除。
function input.registerhotkey(keynum, func) end

---メッセージボックスを表示する
---@param message string メッセージ
---@param type? "ok"|"yesno"|"yesnocancel"|"okcancel"|"abortretryignore" ボタンの種類
---@param icon? "message"|"notice"|"question"|"warning"|"error" アイコン
---@return string 選択されたボタン
function input.popup(message, type, icon) end

---@class stylus
stylus = {}

---現在のタッチペンの状態を取得する
---@return table {x:number, y:number, touch:boolean}
function stylus.get() end

---ユーザーが現在入力しているタッチペンの状態を取得する
---@return table {x:number, y:number, touch:boolean}
function stylus.peek() end

---タッチペンの状態を設定する
---@param state table {x?:number, y?:number, touch?:boolean}
function stylus.set(state) end

---@class savestate
savestate = {}

---セーブステートオブジェクトを作成する
---@param slot? number スロット番号 (省略時はファイルに関連付けられないオブジェクト)
---@return table
function savestate.create(slot) end

---ステートをファイルに保存する
---@param state table セーブステートオブジェクト
---@param option? string "quiet" または "scriptdataonly"
function savestate.save(state, option) end

---ステートをファイルからロードする
---@param state table セーブステートオブジェクト
---@param option? string "quiet" または "scriptdataonly"
function savestate.load(state, option) end

---@class movie
movie = {}

---ムービーがアクティブかどうかを取得する
---@return boolean
function movie.active() end

---ムービーを録画中かどうかを取得する
---@return boolean
function movie.recording() end

---ムービーを再生中かどうかを取得する
---@return boolean
function movie.playing() end

---現在のムービーモードを取得する
---@return string "record", "playback", "inactive", "finished"
function movie.mode() end

---現在のムービーの長さ (フレーム数) を取得する
---@return number
function movie.length() end

---現在のムービー名を取得する
---@return string
function movie.name() end

---現在のフレーム数を取得する
---@return number
function movie.framecount() end

---現在のリレコード回数を取得する
---@return number
function movie.rerecordcount() end

---リレコード回数を設定する
---@param count number リレコード回数
function movie.setrerecordcount(count) end

---リレコード回数のカウントを取得または設定する
---@param enabled? boolean 省略時は現在値を取得
---@return boolean|nil 引数省略時のみ現在値
function movie.rerecordcounting(enabled) end

---ムービーが読み取り専用かどうかを取得する
---@return boolean
function movie.readonly() end

---ムービーの読み取り専用状態を設定する
---@param readonly boolean 読み取り専用にするか
function movie.setreadonly(readonly) end

---ムービーを再生する
---@param filename? string ファイル名 (省略時はユーザーが選択)
function movie.play(filename) end

---現在のムービーを最初から再生する
function movie.replay() end

---ムービーを停止する
function movie.stop() end

---@class sound
sound = {}

---サウンドバッファをクリアする
function sound.clear() end

---@class controller
controller = {}

---PC のジョイスティックの状態を取得する (Windows フロントエンドのみ)
---@param joystickID? number ジョイスティックID (0-15)
---@param returnDiagonals? boolean 斜め入力を返すか
---@return table
function controller.get(joystickID, returnDiagonals) end

---@class agg
agg = {}

---線を描画する
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function agg.line(x1, y1, x2, y2) end

---三角形を描画する
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param x3 number
---@param y3 number
function agg.triangle(x1, y1, x2, y2, x3, y3) end

---短形を描画する
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
function agg.rectangle(x1, y1, x2, y2) end

---角丸短形を描画する
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param r number 角の半径
function agg.roundedRect(x1, y1, x2, y2, r) end

---楕円を描画する
---@param cx number 中心X
---@param cy number 中心Y
---@param rx number X半径
---@param ry number Y半径
function agg.ellipse(cx, cy, rx, ry) end

---円弧を描画する
---@param cx number 中心X
---@param cy number 中心Y
---@param rx number X半径
---@param ry number Y半径
---@param start number 開始角度
---@param sweep number 角度範囲
function agg.arc(cx, cy, rx, ry, start, sweep) end

---星形を描画する
---@param cx number 中心X
---@param cy number 中心Y
---@param r1 number 外側の半径
---@param r2 number 内側の半径
---@param startAngle number 開始角度
---@param numRays number 角の数
function agg.star(cx, cy, r1, r2, startAngle, numRays) end

---曲線を描画する
---@param x1 number
---@param y1 number
---@param x2 number
---@param y2 number
---@param x3 number
---@param y3 number
function agg.curve(x1, y1, x2, y2, x3, y3) end

---塗りつぶし色を設定する
---@overload fun(r?: number, g?: number, b?: number, a?: number)
---@param color number|string 色
function agg.fillColor(color) end

---塗りつぶしを無効にする
function agg.noFill() end

---線の色を設定する
---@overload fun(r?: number, g?: number, b?: number, a?: number)
---@param color number|string 色
function agg.lineColor(color) end

---線の描画を無効にする
function agg.noLine() end

---線の幅を設定する
---@param width number 幅
function agg.lineWidth(width) end

---フォントを設定する
---@param name string フォント名
function agg.setFont(name) end

---テキストを描画する
---@param x number X座標
---@param y number Y座標
---@param str string 文字列
function agg.text(x, y, str) end

---@class bit
bit = {}

---数値を符号付き32ビット整数に変換する
---@param x number
---@return number
function bit.tobit(x) end

---ビット反転する
---@param x number
---@return number
function bit.bnot(x) end

---ビット論理積を計算する
---@param x1 number
---@param ... number
---@return number
function bit.band(x1, ...) end

---ビット論理和を計算する
---@param x1 number
---@param ... number
---@return number
function bit.bor(x1, ...) end

---ビット排他的論理和を計算する
---@param x1 number
---@param ... number
---@return number
function bit.bxor(x1, ...) end

---左シフトする
---@param x number
---@param n number シフト量
---@return number
function bit.lshift(x, n) end

---右シフトする (論理シフト)
---@param x number
---@param n number シフト量
---@return number
function bit.rshift(x, n) end

---右シフトする (算術シフト)
---@param x number
---@param n number シフト量
---@return number
function bit.arshift(x, n) end

---左ローテートする
---@param x number
---@param n number ローテート量
---@return number
function bit.rol(x, n) end

---右ローテートする
---@param x number
---@param n number ローテート量
---@return number
function bit.ror(x, n) end

---バイト順を入れ替える
---@param x number
---@return number
function bit.bswap(x) end

---16進数文字列に変換する
---@param x number
---@param n? number 桁数 (負数で大文字)
---@return string
function bit.tohex(x, n) end

---テーブルの浅いコピーを作成する
---@param origtable table
---@return table
function copytable(origtable) end

---テーブルまたは関数のアドレスを取得する
---@param table_or_function table|function
---@return number
function addressof(table_or_function) end
