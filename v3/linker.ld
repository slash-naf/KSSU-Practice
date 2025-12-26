/* 
    NDS Payload Linker Script
    Target Address: 0x023FE000
*/

OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

MEMORY {
    /* 
        Main RAM内のターゲット領域。
        ORIGINを注入予定のアドレスに合わせる。
        LENGTHはペイロードの最大許容サイズ。
    */
    RAM (rwx) : ORIGIN = 0x023FE000, LENGTH = 4K
}

SECTIONS {
    /* カレントアドレスをRAMの先頭に設定 */
    . = ORIGIN(RAM);

    /*.textセクション: 実行可能コード */
    .text : {
        /* エントリポイントが先頭に来るように配置 */
        __text_start = . ;
        KEEP(*(.text.startup)) /* スタートアップコードを最優先 */
        *(.text)
        *(.text.*)
       . = ALIGN(4); /* ARM命令は4バイト境界が必要 */
        __text_end = . ;
    } > RAM

    /*.rodataセクション: 定数データ（文字列など） */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
    } > RAM

    /*.dataセクション: 初期値のある大域変数 */
    .data : {
        __data_start = . ;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        __data_end = . ;
    } > RAM

    /*.bssセクション: 初期値のない大域変数 */
    /* 
        このセクションはバイナリファイルには含まれない(NOLOAD扱い)。
        しかし、実行時にはメモリ領域を占有する。
        初期化はスタートアップコードで手動で行う必要がある。
    */
    .bss : {
        __bss_start = . ;
        *(.bss)
        *(.bss.*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = . ;
    } > RAM

    /* 不要なメタデータの破棄 */
    /DISCARD/ : {
        *(.comment)
        *(.ARM.attributes)
    }
}