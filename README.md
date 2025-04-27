# 星のカービィ ウルトラスーパーデラックス 練習用チートv2.4

## 導入方法

Releasesからusrcheat.datをダウンロード

NDSForwarderを使っている場合は"usrcheat.dat"を"sd:/_nds/ntr-forwarder/usrcheat.dat"に配置  
既にある場合、変えたくなければr4cceで編集する  
ゲームを起動するときにYを押し続けるとメニューが表示される  
Xを押すと、チートが表示され、Aで選択、Xで保存して戻る  
STARTで保存して開始  
デフォルトでは、 QSQL Lite と R + START to Pause Anytime と R + SELECT to Die と Freeze RoMK Timer のみ有効

TWiLight Menu++の場合は"sd:/_nds/TWiLightMenu/extras/usrcheat.dat"に配置

ちなみにFTPDを使えば無線でファイルのやりとりができる

## 注意事項

銀河にねがいをのマルク戦では一度死んでからQSしたほうがいい

日本版のROMでしか使えない

自分の環境はNew3DSのnds-bootstrapのv2.2.2でだいたい問題なく機能してるけど、他の環境だと違うかもしれない  
古いバージョンのnds-bootstrapだとEタイプコードが機能しないから、QSQLなどが機能しない  
プログラムと変数を配置してるRAMがマジコンでも使われてるらしいから、たぶんQSQLは使えなくてQSQL Liteは使える

## チート一覧

### QSQL Lite

ほぼ次のQSQLと同じ  
Monitor RNG と併用できない  
フロアごとの区間タイムが表示されない

#### 変数

|Address|Size|Name|
|02090DC4|4|show_number|
|02090DC8|4|sav_gameStates|
|02090DCC|4|sav_helperStates|
|02090DD0|4|sav_playerMode|
|02090DD4|4|sav_mww_abilities|
|02090DD8|4|tmp_pos|
|02090DDC|4|sav_playerStates|
|02090DE0|4|sav_pos|
|02090DE4|4|tmp_playerMode|
|02090DE8|2|tmp_helperInvincibility|
|02090DEA|2|conf_musicReset|
|02090DEC|2|tmp_playerInvincibility|
|02090DEE|2|sav_playerInvincibility|
|02090DF0|2|sav_helperInvincibility|
|02090DF2|1|sav_helperRode|
|02090DF3|1|sav_mww_selected_abilities|
|02090DF4|1|sav_arena_idx|
|02090DF5|1|sav_playerRiding|

### QSQL

#### 操作方法

ポーズ中にLでQS  
ポーズ中にRで、QL時に曲が最初からになるQS  
ポーズ中にXで、ジェットをセーブ  
Rを押しながらLで、格闘王系のモードで次の戦闘に進める

#### 仕様

セーブされるのは、フロア、座標、開始時の状態(ワープスターに乗ってきたかとか)、コピー能力、ヘルパー、両者のむてきキャンディ/メタクイック、銀河の取得済みのコピーのもとデラックス、銀河の下画面の能力の選択位置

QL時にそのモードでまだQSしてなかったらQSもされる  
QL時にはタイマーのリセット、HP全回復、残機99、メタナイトでゴーのPt最大、洞窟大作戦の宝箱とボスのリセット、ダイナブレイドのスイッチ復活が行われる

格闘王系のモードではボスがセーブされ、QLすると1戦目になってそのボスがロードされる

下画面に4桁の数値が4つ表示され、フロア遷移時のタイムを一番左に、区間タイムを右3つに表示する

#### 変数

|Address|Size|Name|
|--:|--:|:--|
|023FE500|1|sav_mww_selectedAbility|
|023FE501|1|sav_arena_boss|
|023FE502|1|sav_playerRiding|
|023FE503|1|sav_helperRode|
|023FE504|2|sav_playerInvincibility|
|023FE506|2|sav_helperInvincibility|
|023FE508|2|tmp_playerInvincibility|
|023FE50A|2|tmp_helperInvincibility|
|023FE50C|2|conf_musicReset|
|023FE510|4|tmp_pos|
|023FE514|4|sav_seed|
|023FE518|4|tmp_seed|
|023FE51C|4|tmp_playerMode|
|023FE520|4|sav_playerStates|
|023FE524|4|sav_gameStates|
|023FE528|4|sav_mww_abilities|
|023FE52C|4|sav_helperStates|
|023FE530|4|sav_pos|
|023FE534|4|sav_playerMode|

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

## どうやって作ったか

C言語で書いたコードをdesmumeでcompile.luaを使って、ARMv5向けのコンパイルコマンドを実行し、出来たELFファイルを組み込めるように変換し、そのコードを書き込むためのActionReplayコードを作る  
かなり無理やりな方法をしている部分があるからうまくいかないこともあるかもしれない

コードはRAMの023FE000に配置した  
DSATM(DS Auto Trainer Maker)っていう、ROMにチートを埋め込めるアプリがあるんだけど、チート機能がコピーされる場所のデフォルトがそこでほとんどのゲームでは問題ないらしいからそうした  
実際ウルデラでは問題なかった

そのコードはボタン入力処理の所(020017C0-020017CC)から呼び出した  
毎フレーム実行されるしレジスタにボタン入力情報が入った状態だから都合がいい

QSQL Lite は純粋にActionReplayコードで動いている
