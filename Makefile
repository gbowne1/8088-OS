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

$(FLOPPY_IMG): $(BOOTLOADER_BIN) $(KERNEL_BIN) $(SHELL_BIN)
	dd if=/dev/zero of=$(FLOPPY_IMG) bs=512 count=2880
	dd if=$(BOOTLOADER_BIN) of=$(FLOPPY_IMG) bs=512 seek=0 conv=notrunc
	dd if=$(KERNEL_BIN)     of=$(FLOPPY_IMG) bs=512 seek=1 conv=notrunc
	dd if=$(SHELL_BIN)      of=$(FLOPPY_IMG) bs=512 seek=3 conv=notrunc

$(BOOTLOADER_BIN): $(BOOTLOADER_DIR)/boot.asm
	$(ASM) $(ASMFLAGS) $< -o $@

$(KERNEL_BIN): $(KERNEL_DIR)/kernel.asm
	$(ASM) $(ASMFLAGS) $< -o $@

$(SHELL_BIN): $(USER_DIR)/shell.asm
	$(ASM) $(ASMFLAGS) $< -o $@

clean:
	rm -f $(BUILD_DIR)/*.bin $(FLOPPY_IMG)

.PHONY: all clean
