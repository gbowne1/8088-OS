bits 16
org 0x7C00

start:
    cli
    xor ax, ax
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7C00

    mov ax, 0x0800
    mov es, ax
    mov ax, 0x0203        ; INT 13h: read 3 sectors
    mov cx, 0x0002
    mov bx, 0x0000
    mov dx, 0x0000
    int 0x13

    jc disk_error         ; Jump if carry set (error)

    jmp 0x0800:0000       ; Jump to kernel

disk_error:
    mov si, err_msg
    call print_string
    jmp $

print_string:
    mov ah, 0x0E
.next_char:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .next_char
.done:
    ret

err_msg db "Disk read error!", 0

times 510 - ($ - $$) db 0
dw 0xAA55
