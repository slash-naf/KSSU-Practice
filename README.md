# 星のカービィ ウルトラスーパーデラックス 練習用チート

NDSForwarderを使っている場合、 "usrcheat.dat"を"sd:/_nds/ntr-forwarder/usrcheat.dat"に配置
ゲームを起動するときにYを押し続けるとメニューが表示される
Xを押すと、チートが表示され、Aで選択、Xで保存して戻る
STARTで保存して開始

TWiLight Menu++の場合は"sd:/_nds/TWiLightMenu/extras/usrcheat.dat"に配置

"Prepare for Next Routine"以外のチートは必要なければ無効にして大丈夫
0x023FE000から0x023FE040までの65バイトのメモリを勝手に使ってるから他のチートと併用したいときは注意

だいぶ完成度高いものが出来たと思ってるけど、まだできないこともある
曲の再生位置を変える方法は分からなかった
一部のフロア(知る限りでは銀河のマルクとメタナイトの逆襲の2面)では意図通りにQLされず、一度死んでからQSする必要がある

## Freeze Timer in RotMK

これは自分で作ったんじゃなくてネットで拾ってきたやつ
メタナイトの逆襲のタイマーが減らなくなる

## Restore Items

マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロアのロードで復活するようになる

## Restore Switches in DB

白き翼ダイナブレイドで、マップではおためし部屋が両方とも開放され、ステージ内ではスイッチが存在し、フロアをロードすれば復活する

## QSQL

ポーズ中にLでセーブ、プレイ中にLでロードされる
セーブをするときRを押しながらならステータス面はセーブされないから、格闘王でジェットをセーブしてメタ逆とか大王にジェットを持ち込んだりできる
ロード時にはタイマーのリセット、HP全回復、残機99、メタゴーのPt最大、洞窟の宝箱とボスのリセットが行われる

- ポーズ中にLでセーブ
  - セーブ
    - 格闘王系で何戦目か
    - フロア
    - フロア遷移時の座標
    - 乱数
  - Rを押しながらならセーブされない
    - カービィの能力
    - ヘルパーの能力と状態
    - フロア遷移時のむてきキャンディの時間
    - 銀河で取得したコピー
    - 銀河でのコピー選択位置
- プレイ中にLでロード
  - セーブした内容をロード
  - タイマーリセット
  - HP全回復
  - 残機99
  - メタゴーのPt最大
  - 洞窟の宝箱とボスのリセット

## Settings
  
ポーズのメニューの最初のページを0ページ目として、何ページ目でボタンを押したかのよって設定を行う
既定値は0

- 十字キー上
  - 0: 曲を流しっぱなしにする
  - 1: QLしたときに曲を最初からにする
  - 2: 次に曲が切り替わったとき不可逆的にずっとミュートになる
- 十字キー下
  - 0: 乱数をQLする
  - 1: しない
- SELECT
  - 0: 乱数が偶数か奇数かが切り替わったら表示タイム更新する
  - 1: しない

## RNG Parity Sync Timer

乱数が偶数か奇数かが切り替わったら表示タイム更新する
8フレームごとに2進むのを無視して、乱数の判定によって1進んだタイミングを検知できる
まあ奇数回進むのそれだけじゃないけど

## Time on Score or Gold

タイムをスコア・ゴールドに表示する
ボス戦でも表示され続ける

## Hold R + START to Pause Anytime

Rを押しながらSTARTを押すと、はるかぜのステージ冒頭のムービー中とかでもポーズできる

## Hold R + SELECT to Die

Rを押しながらSELECTを押すと死ぬ(死ぬときの演出は出ない)
銀河のマルクやメタナイトの逆襲の2面の最初とかでは意図通りににQLされないから一度死んでからQSしたほうがいい

## Prepare for Next Routine

次の処理のための準備
