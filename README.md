# 星のカービィ ウルトラスーパーデラックス 練習用チートv2.3.0

## 導入方法

Releasesからusrcheat.datをダウンロード

NDSForwarderを使っている場合は"usrcheat.dat"を"sd:/_nds/ntr-forwarder/usrcheat.dat"に配置  
既にある場合、変えたくなければr4cceで編集する  
ゲームを起動するときにYを押し続けるとメニューが表示される  
Xを押すと、チートが表示され、Aで選択、Xで保存して戻る  
STARTで保存して開始  
デフォルトで全て有効になってるからそれで良ければメニュー開く必要は無い

TWiLight Menu++の場合は"sd:/_nds/TWiLightMenu/extras/usrcheat.dat"に配置

ちなみにFTPDを使えば無線でファイルのやりとりができる

## 注意事項

銀河にねがいをのマルク戦では一度死んでからQSしたほうがいい

日本語版でしか使えない

## チート一覧

### QSQL

ポーズ中にLでQS  
ポーズ中にRで、QL時に曲が最初からになるQS  
セーブされるのは、フロア、座標、開始時の状態(ワープスターに乗ってきたかとか)、コピー能力、ヘルパー、両者のむてきキャンディ/メタクイック、銀河の取得済みのコピーのもとデラックス、銀河の下画面の能力の選択位置

ポーズ中にXで、ジェットをセーブ

プレイ中にLでQL  
そのモードでまだQSしてなかったらQSもされる

QL時にはタイマーのリセット、HP全回復、残機99、メタナイトでゴーのPt最大、洞窟大作戦の宝箱とボスのリセット、ダイナブレイドのスイッチ復活が行われる

格闘王系のモードではボスがセーブされ、QLすると1戦目になってそのボスがロードされる  
Rを押しながらLで次の戦闘に進める

マキシムトマト、むてきキャンディ、1UPなどの、ステージを出ないと復活しないアイテムがフロア遷移で復活するようになる

下画面に4桁の数値が4つ表示され、フロア遷移時のタイムを一番左に、区間タイムを右3つに表示する

### R + START to Pause Anytime

RとSTARTを押すと、はるかぜのステージ冒頭のムービー中とかワープスターに乗ってるときでもポーズできる

### R + SELECT to Die

RとSELECTを押すと死ぬ

### Freeze RoMK Timer

これは自分で作ったんじゃなくてネットで拾ってきたやつ  
メタナイトの逆襲のタイマーが減らなくなる

### Monitor RNG

QSQLと併用

乱数をQSQLする

左から2番目に乱数の進んだ量を、左から3番目に8fごとのを除いた乱数の進んだ量を、一番右に乱数の値を表示する  
QLでリセット

以降はこれと併用で、特定の乱数が判定されたら情報を更新する

## 変数のメモリ配置

|アドレス|サイズ|変数名|
|--:|--:|:--|
|023fe500|1|sav_mww_selectedAbility|
|023fe501|1|sav_arena_boss|
|023fe502|1|sav_playerRiding|
|023fe503|1|sav_helperRode|
|023fe504|2|sav_playerInvincibility|
|023fe506|2|sav_helperInvincibility|
|023fe508|2|tmp_playerInvincibility|
|023fe50a|2|tmp_helperInvincibility|
|023fe50c|2|conf_musicReset|
|023fe510|4|tmp_pos|
|023fe514|4|sav_seed|
|023fe518|4|tmp_seed|
|023fe51c|4|tmp_playerMode|
|023fe520|4|sav_playerStates|
|023fe524|4|sav_gameStates|
|023fe528|4|sav_mww_abilities|
|023fe52c|4|sav_helperStates|
|023fe530|4|sav_pos|
|023fe534|4|sav_playerMode|

## どうやって作ったか

C言語で書いたコードをdesmumeでcompile.luaを使って、ARMv5向けのコンパイルコマンドを実行し、出来たELFファイルを組み込めるように変換し、そのコードを書き込むためのActionReplayコードを作る  
かなり無理やりな方法をしている部分があるからうまくいかないこともあるかもしれない

コードはRAMの023FE000に配置した  
DSATM(DS Auto Trainer Maker)っていう、ROMにチートを埋め込めるアプリがあるんだけど、チート機能がコピーされる場所のデフォルトがそこでほとんどのゲームでは問題ないらしいからそうした  
実際ウルデラでは問題なかった

そのコードはボタン入力処理の所(020017C0-020017CC)から呼び出した  
毎フレーム実行されるしレジスタにボタン入力情報が入った状態だから都合がいい
