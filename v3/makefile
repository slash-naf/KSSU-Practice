# --- プロジェクト設定 ---
BUILD       := build
SRC         ?= source/main.c
ADDR        ?= 0x023FE000
NAME        := $(basename $(notdir $(SRC)))
OBJ         := $(BUILD)/$(NAME).o
BIN         := $(BUILD)/$(NAME).bin
SYMBOLS     := $(BUILD)/$(NAME).txt

# 環境変数 DEVKITARM が設定されていることを確認
ifndef DEVKITARM
    $(error DEVKITARM is not set)
endif

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

# --- ビルドロール ---
.PHONY: all clean

all: $(BUILD) $(BIN) $(SYMBOLS)

# ビルドディレクトリ作成
$(BUILD):
	@mkdir -p $@

# コンパイル
$(OBJ): $(SRC)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# リンク
$(BUILD)/$(NAME).elf: $(OBJ)
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
