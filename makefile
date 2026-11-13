# --- プロジェクト設定 ---
BUILD       := build
SRC         ?= source/main.c
ADDR        ?= 0x023FE000
NAME        := $(basename $(notdir $(SRC)))
OBJ         := $(BUILD)/$(NAME).o
BIN         := $(BUILD)/$(NAME).bin
SYMBOLS     := $(BUILD)/$(NAME).txt

# コンパイラやツールのコマンド名定義
PREFIX      := arm-none-eabi-
CC          := $(PREFIX)gcc
LD          := $(PREFIX)gcc
OBJCOPY     := $(PREFIX)objcopy
OBJDUMP     := $(PREFIX)objdump
NM          := $(PREFIX)nm

# --- フラグ設定 ---
ARCH        := -mcpu=arm946e-s -march=armv5te -marm
CFLAGS      := $(ARCH) -Os -ffreestanding -fomit-frame-pointer -Wall -Wextra -Werror -fno-strict-aliasing
LDFLAGS     := $(ARCH) -nostartfiles -nostdlib -T linker.ld -Wl,-Map,$(BUILD)/$(NAME).map -Wl,--defsym=START_ADDR=$(ADDR)

# BSS変数が設定されている場合、BSS_ADDRシンボルを定義
ifdef BSS
    LDFLAGS += -Wl,--defsym=BSS_ADDR=$(BSS)
endif

# ビルドパラメータの追跡 (ADDR, BSS の変更検知用)
PARAMS      := $(BUILD)/$(NAME).params
PREV_PARAMS := $(shell cat $(PARAMS) 2>/dev/null)
CURR_PARAMS := ADDR=$(ADDR) BSS=$(BSS)

# パラメータに変更がある場合のみ PARAMS を更新対象にする
ifneq ($(PREV_PARAMS),$(CURR_PARAMS))
.PHONY: $(PARAMS)
endif

# --- ビルドルール ---
.PHONY: all module typecheck clean

# 既定のビルド: build.ts を実行して dist にチート一式を出力する
all:
	@node --experimental-strip-types build.ts

# Cモジュールのビルド (tools/scripts/ar.ts から呼び出される)
module: $(BUILD) $(BIN) $(SYMBOLS)

# 型チェックのみ
typecheck:
	@npx tsc --noEmit

# ビルドディレクトリ作成
$(BUILD):
	@mkdir -p $@

# パラメータファイルの更新
$(PARAMS): | $(BUILD)
	@echo "$(CURR_PARAMS)" > $@

# コンパイル
$(OBJ): $(SRC)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# リンク (コード変更時・リンカ変更時・アドレス変更時に再リンク)
$(BUILD)/$(NAME).elf: $(OBJ) linker.ld $(PARAMS)
	@echo "Linking $(NAME) at $(ADDR)..."
	@$(LD) $(LDFLAGS) $< -o $@

# バイナリ抽出
$(BIN): $(BUILD)/$(NAME).elf
	@echo "Creating flat binary..."
	@$(OBJCOPY) -O binary -S $< $@
	@echo "Build Complete: $@"

# シンボル情報の抽出
$(SYMBOLS): $(BUILD)/$(NAME).elf
	@echo "Generating symbol map..."
	@$(NM) -g $< > $@

# クリーンアップ
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD)
