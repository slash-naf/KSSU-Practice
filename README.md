# 星のカービィ ウルトラスーパーデラックス 練習用チートv2.7

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

## 留意事項と既知の問題

銀河にねがいをのマルク戦では一度死んでからQSしたほうがいい

日本版のROMでしか使えない

自分の環境はNew3DSのnds-bootstrapのv2.2.2でだいたい問題なく機能してるけど、他の環境だと違うかもしれない  
古いバージョンのnds-bootstrapだとEタイプコードが機能しないから、QSQLなどが機能しない  
プログラムと変数を配置してるRAMがマジコンでも使われてるらしいから、たぶんQSQLは使えなくてQSQL Liteは使える

以下の状態でQLするとエラーになる
- タックに能力を盗られて止まっているとき
- メタナイトの竜巻やトルネイドに巻き込まれているとき

Prevent Ending が有効のときリアクターでエラーになる

## チート一覧

### QSQL Lite

機能はほぼ次のQSQLと同じで、違いは、  
Monitor RNG と併用できない  
Mix View と併用できない  
フロアごとの区間タイムが表示されない  
ほおばりのセーブができない

### QSQL

#### 操作方法

ポーズ中にLでQS  
ポーズ中にRで、QL時に曲が最初からになるQS  
ポーズ中にXで、ジェットをセーブ  
ポーズ中にYで、その時点の座標をセーブ  
Rを押しながらLで、格闘王系のモードで次の戦闘に進める

#### 仕様

セーブされるのは、フロア、座標、開始時の状態(ワープスターに乗ってきたかとか)、コピー能力、ヘルパー、両者のむてきキャンディ/メタクイック、銀河の取得済みのコピーのもとデラックス、銀河の下画面の能力の選択位置  
何かをほおばっているときにQSすると、吸い込みをしたときにそれをほおばる

QL時にそのモードでまだQSしてなかったらQSもされる  
QL時にはタイマーのリセット、HP全回復、残機99、メタナイトでゴーのPt最大、洞窟大作戦の宝箱とボスのリセットが行われる

むてきキャンディや1UPやマキシムトマトはフロア遷移で復活する  
ダイナのスイッチはフロア遷移で復活するが、おためし部屋は常に開放されている

格闘王系のモードではボスがセーブされ、QLすると1戦目になってそのボスがロードされる

下画面に4桁の数値が4つ表示され、フロア遷移時のタイムを一番左に、区間タイムを右3つに表示する

### R + START to Pause Anytime

RとSTARTを押すと、はるかぜとともにのステージ冒頭のムービー中とかワープスターに乗ってるときでもポーズできる

### R + SELECT to Die

RとSELECTを押すと死ぬ

### Freeze RoMK Timer

これは自分で作ったんじゃなくてネットで拾ってきたやつ  
メタナイトの逆襲のタイマーが減らなくなる

### Prevent Ending

ダイナブレイド、洞窟大作戦、グルメレース、メタナイトの逆襲、銀河に願いを、メタナイトでゴー、のエンディングが流れずに再度フロアをロードする

### Mix View

ミックスをしたときに4fのどのタイミングだったかを表示する  
他の行動で誤作動することもあるけどまあそんなに問題ない

## 乱数調査用機能

普通は使わないと思うので分けて記述  
QSQLと併用前提

### QSQL

上押しながらQSで、QL時に乱数と乱数タイマーをロード

左押しながらQSで、ログを有効にする  
その状態でQLすると、そのフロアと、遷移時の乱数と乱数タイマーの情報をログに追加する  
Monitor RNG が無効なら、ログを、ログが有効になったときの状態に戻す

### Input Log

ログが有効なら、ボタン入力情報をログに追加  
ポーズ時に下押しながらセレクトで、ログを無効にし、最後のフロア遷移時までログの状態を戻す

### Dump Log

水しょうの畑のセーブ部屋でQSしてセレクトを押したら、次にセーブが実行されたときにログをセーブファイルにダンプする

### Monitor RNG

一番左に乱数タイマーの値を、左から2番目に乱数の進んだ量を、左から3番目に8fごとのを除いた乱数の進んだ量を、一番右に乱数の値を表示する  
QLでリセット

ログが有効なら乱数とタイマーの情報をログに追加

以降の Impact Star や Invincibility Star はこれと併用で、その乱数が判定されたら情報を更新する

## 変数のメモリ配置

### QSQL Lite

|Address|Size|Name|
|--:|--:|:--|
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

### 他

|Address|Size|Name|
|:----|:----|:----|
|02090DD8|10|show|
|023FDF00|1|sav_mww_selectedAbility|
|023FDF01|1|sav_arena_boss|
|023FDF02|1|sav_playerRiding|
|023FDF03|1|sav_helperRode|
|023FDF04|2|sav_playerInvincibility|
|023FDF06|2|sav_helperInvincibility|
|023FDF08|2|options|
|023FDF0a|2|tmp_playerInvincibility|
|023FDF0c|2|tmp_helperInvincibility|
|023FDF10|4|tmp_pos|
|023FDF14|4|sav_seed|
|023FDF18|4|tmp_seed|
|023FDF1C|4|tmp_playerMode|
|023FDF20|4|sav_inhale1|
|023FDF24|4|sav_inhale2|
|023FDF28|4|sav_playerStates|
|023FDF2C|4|sav_pos|
|023FDF30|4|sav_gameStates|
|023FDF34|4|sav_mww_abilities|
|023FDF38|4|sav_helperStates|
|023FDF3C|4|sav_playerMode|
|023FDF60|C|Prevent Ending in Gourmet Race|
|023FDF80|2|prev (input_log.c)|
|023FE000|550|QSQL|
|023FE57C|2|seed_advances|
|023FE57E|2|narrowed_seed_advances|
|023FE580|D4|Monitor RNG|
|023FE680|64|Mix View|
|023FE700|190|Input Log|
|02EFFFA0|40|Log Dump|
|02EFFFFE|-|p|

## 開発過程

最初はActionReplayコードを直接書くところから始まった  
しかし、それだと非効率だしミスもしやすいから、プログラムでActionReplayコードを作れるようにした
ただ、そもそもActionReplayコードだとできることに制約があるし、nds-bootstrapのチートエンジンだと条件文の入れ子ができないというのもあり、C言語とLuaによる開発に移行した

C言語で書いたコードをclangでARMv5向けにコンパイルし、出来たELFファイルを組み込めるように変換し、そのコードを書き込むためのActionReplayコードを作るというのをDeSmuMEでLuaスクリプトで行う  
かなり無理やりな方法をしている部分があるからうまくいかないこともあるかもしれない  
ELFファイルの仕様についてしっかり理解していないから、問題が起きるたびに場当たり的に対処した

コードはRAMの023FE000に配置した  
DSATM(DS Auto Trainer Maker)っていう、ROMにチートを埋め込めるアプリがあり、チート機能がコピーされる場所のデフォルトがそこでほとんどのゲームでは問題ないらしいからそうした  
実際ウルデラでは問題なかった  
しかし、使えるメモリが少ないため、02F00000以降のメモリを使ったほうが良かっただろう  
また、使用するメモリがマジコンと競合することが分かったため、純粋にActionReplayコードで動く QSQL Lite を後に作った

コードはボタン入力処理の所(020017C0-020017CC)から呼び出した  
毎フレーム実行されるしレジスタにボタン入力情報が入った状態だから都合がいい

行き当たりばったりで作っていったのでいろいろ複雑になってしまい、これ以上の開発は難しいかもしれないから、作り直すことを考えている
