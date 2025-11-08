org 0x0000

start:
    cli
    mov ax, 0x1000
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE

    call install_timer_handler
    call enable_irq0

    sti

    mov si, msg
    call print_string

hang:
    jmp hang

; -------------------------------
; Timer Interrupt Handler (INT 08h)
; -------------------------------
timer_handler:
    push ax
    push dx

    mov dx, 0x3F8         ; COM1 port (optional debug output)
    mov al, '.'           ; Send a dot to serial port
    out dx, al

    pop dx
    pop ax
    iret

; -------------------------------
; Install Timer Handler into IVT
; -------------------------------
install_timer_handler:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov word [0x0020], timer_handler   ; Offset for INT 08h
    mov word [0x0022], cs              ; Segment for INT 08h
    sti
    ret

; -------------------------------
; Enable IRQ0 in PIC
; -------------------------------
enable_irq0:
    in al, 0x21           ; Read PIC mask
    and al, 0xFE          ; Clear bit 0 (IRQ0)
    out 0x21, al          ; Write back
    ret

; -------------------------------
; Print String Routine
; -------------------------------
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

msg db "8088/OS Kernel Initialized", 0
