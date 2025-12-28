/* 
    NDS Payload Linker Script
*/

OUTPUT_FORMAT("elf32-littlearm", "elf32-bigarm", "elf32-littlearm")
OUTPUT_ARCH(arm)
ENTRY(_start)

SECTIONS {
    /* Makefileから渡されたSTART_ADDRを使用。未定義ならデフォルト値。 */
    . = DEFINED(START_ADDR) ? START_ADDR : 0x023FE000;

    /*.textセクション: 実行可能コード */
    .text : {
        __text_start = . ;
        KEEP(*(.text.startup)) /* スタートアップコードを最優先 */
        *(.text)
        *(.text.*)
       . = ALIGN(4); /* ARM命令は4バイト境界が必要 */
        __text_end = . ;
    }

    /*.rodataセクション: 定数データ */
    .rodata : {
        *(.rodata)
        *(.rodata.*)
        . = ALIGN(4);
    }

    /*.dataセクション: 初期値のある大域変数 */
    .data : {
        __data_start = . ;
        *(.data)
        *(.data.*)
        . = ALIGN(4);
        __data_end = . ;
    }

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
    }

    /* 不要なメタデータの破棄 */
    /DISCARD/ : {
        *(.comment)
        *(.ARM.attributes)
    }
}