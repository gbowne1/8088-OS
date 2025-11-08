org 0x0000

start:
    mov si, msg
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

msg db "8088/OS Kernel Loaded!", 0
