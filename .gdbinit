# -----------------------------
# Real-mode 8086 OS Debug Setup
# -----------------------------

set confirm off
set pagination off
set verbose off

# Correct CPU + syntax
set architecture i8086
set disassembly-flavor intel

# Better stepping
set step-mode on
set print asm-demangle on
set print pretty on

# QEMU GDB stub
target remote :1234

# -----------------------------
# Convenience Functions
# -----------------------------

# Show real-mode CS:IP nicely
define rip
    printf "CS:IP = %04x:%04x  (linear=%05x)\n", $cs, $ip, ($cs << 4) + $ip
end

# Disassemble at CS:IP
define rdi
    x/10i ($cs << 4) + $ip
end

# Dump FLAGS
define rflags
    printf "FLAGS = %04x  [CF=%d ZF=%d IF=%d DF=%d OF=%d]\n", \
        $flags, \
        ($flags & 1), \
        (($flags >> 6) & 1), \
        (($flags >> 9) & 1), \
        (($flags >> 10) & 1), \
        (($flags >> 11) & 1)
end

# Dump stack (real mode)
define rstack
    x/16hx $ss:($sp)
end

# Dump IVT entry: ivt <int>
define ivt
    set $vec = $arg0
    set $off = $vec * 4
    printf "INT %02x → %04x:%04x\n", \
        $vec, \
        *(unsigned short *)($off), \
        *(unsigned short *)($off + 2)
end

# Dump PIC mask
define pic
    printf "PIC IMR = %02x (IRQ0=%d IRQ1=%d IRQ2=%d IRQ3=%d IRQ4=%d IRQ5=%d IRQ6=%d IRQ7=%d)\n", \
        *(unsigned char *)0x21, \
        (*(unsigned char *)0x21 & 1) == 0, \
        (*(unsigned char *)0x21 & 2) == 0, \
        (*(unsigned char *)0x21 & 4) == 0, \
        (*(unsigned char *)0x21 & 8) == 0, \
        (*(unsigned char *)0x21 & 16) == 0, \
        (*(unsigned char *)0x21 & 32) == 0, \
        (*(unsigned char *)0x21 & 64) == 0, \
        (*(unsigned char *)0x21 & 128) == 0
end

# -----------------------------
# Useful Breakpoints
# -----------------------------

# Kernel entry (after bootloader)
break *0x0800:0x0000

# Timer IRQ (IRQ0 → INT 20h)
break irq0_timer

# Keyboard IRQ (IRQ1 → INT 21h)
break irq1_keyboard

# -----------------------------
# Auto-display
# -----------------------------

display rip
display rflags

echo "\n[+] Real-mode OS GDB initialized\n"
echo "    Commands: rip, rdi, rflags, rstack, ivt <int>, pic\n\n"
