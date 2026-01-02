# Directories
BOOTLOADER_DIR = bootloader
KERNEL_DIR     = kernel
USER_DIR       = user
BUILD_DIR      = build

# Output files
BOOTLOADER_BIN = $(BUILD_DIR)/boot.bin
KERNEL_BIN     = $(BUILD_DIR)/kernel.bin
SHELL_BIN      = $(BUILD_DIR)/shell.bin
FLOPPY_IMG     = $(BUILD_DIR)/floppy.img

# Tools
ASM = nasm
ASMFLAGS = -f bin

# Targets
all: $(FLOPPY_IMG)

# Ensure build directory exists
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(FLOPPY_IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN) $(SHELL_BIN) | $(BUILD_DIR)
	dd if=/dev/zero of=$(FLOPPY_IMG) bs=512 count=2880
	dd if=$(BOOTLOADER_BIN) of=$(FLOPPY_IMG) bs=512 seek=0 conv=notrunc
	dd if=$(KERNEL_BIN)     of=$(FLOPPY_IMG) bs=512 seek=1 conv=notrunc
	dd if=$(SHELL_BIN)      of=$(FLOPPY_IMG) bs=512 seek=3 conv=notrunc

$(BOOTLOADER_BIN): $(BOOTLOADER_DIR)/boot.asm | $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(KERNEL_BIN): $(KERNEL_DIR)/kernel.asm | $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

$(SHELL_BIN): $(USER_DIR)/shell.asm | $(BUILD_DIR)
	$(ASM) $(ASMFLAGS) $< -o $@

clean:
	rm -rf $(BUILD_DIR)

.PHONY: all clean
