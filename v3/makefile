# -------------------------------------------------------------------------
# NDS Cheat Payload Makefile
# Target: ARM946E-S (Flat Binary for Action Replay)
# -------------------------------------------------------------------------

# --- プロジェクト設定 ---
TARGET      := payload
BUILD       := build
SRC         ?= source/main.c
ADDR        ?= 0x023FE000
OBJ         := $(BUILD)/$(notdir $(SRC:.c=.o))

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

# --- フラグ設定 ---
ARCH        := -mcpu=arm946e-s -march=armv5te -marm
CFLAGS      := $(ARCH) -Os -ffreestanding -fomit-frame-pointer -Wall -Wextra -Werror -fno-strict-aliasing
LDFLAGS     := $(ARCH) -nostartfiles -nostdlib -T linker.ld -Wl,-Map,$(BUILD)/$(TARGET).map -Wl,--defsym=START_ADDR=$(ADDR)

# --- ビルドロール ---
.PHONY: all clean dump

all: $(BUILD) $(BUILD)/$(TARGET).bin

# ビルドディレクトリ作成
$(BUILD):
	@mkdir -p $@

# コンパイル
$(OBJ): $(SRC)
	@echo "Compiling $<..."
	@$(CC) $(CFLAGS) -c $< -o $@

# リンク
$(BUILD)/$(TARGET).elf: $(OBJ)
	@echo "Linking..."
	@$(LD) $(LDFLAGS) $< -o $@

# バイナリ抽出
$(BUILD)/$(TARGET).bin: $(BUILD)/$(TARGET).elf
	@echo "Creating flat binary..."
	@$(OBJCOPY) -O binary -S $< $@
	@echo "Build Complete: $@"

# デバッグ用：逆アセンブルリストの生成
dump: $(BUILD)/$(TARGET).elf
	@$(OBJDUMP) -d $< > $(BUILD)/$(TARGET).dump

# クリーンアップ
clean:
	@echo "Cleaning..."
	@rm -rf $(BUILD)
