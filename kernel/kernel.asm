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
    call install_keyboard_handler
    call enable_irq1

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
; Keyboard Interrupt Handler (INT 09h)
; -------------------------------
keyboard_handler:
    push ax
    push bx
    push cx
    push dx

    in al, 0x60           ; Read scancode
    cmp al, 58
    ja .done              ; Ignore scancodes beyond table

    mov bx, ax
    mov si, scancode_table
    xor ah, ah
    mov al, [si + bx]     ; Translate to ASCII
    cmp al, 0
    je .done              ; Skip non-printables

    call buffer_put       ; Store in ring buffer

.done:
    mov al, 0x20
    out 0x20, al          ; Send EOI to PIC

    pop dx
    pop cx
    pop bx
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

    mov word [0x0020], timer_handler
    mov word [0x0022], cs
    sti
    ret

; -------------------------------
; Install Keyboard Handler into IVT
; -------------------------------
install_keyboard_handler:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax

    mov word [0x0024], keyboard_handler
    mov word [0x0026], cs
    sti
    ret

; -------------------------------
; Enable IRQ0 in PIC
; -------------------------------
enable_irq0:
    in al, 0x21
    and al, 0xFE
    out 0x21, al
    ret

; -------------------------------
; Enable IRQ1 in PIC
; -------------------------------
enable_irq1:
    in al, 0x21
    and al, 0xFD
    out 0x21, al
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

; -------------------------------
; Keyboard Ring Buffer
; -------------------------------
buffer_size equ 64

keyboard_buffer: times buffer_size db 0
buffer_head: dw 0
buffer_tail: dw 0

; -------------------------------
; Put Character in Buffer
; -------------------------------
buffer_put:
    push ax
    push bx
    push cx
    push dx

    mov bx, [buffer_head]
    mov cx, [buffer_tail]
    mov dx, buffer_size
    inc bx
    cmp bx, dx
    jne .skip_wrap
    xor bx, bx
.skip_wrap:
    cmp bx, cx
    je .full              ; Buffer full, drop character

    mov si, keyboard_buffer
    add si, [buffer_head]
    mov [si], al
    mov [buffer_head], bx

.full:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Get Character from Buffer
; -------------------------------
buffer_get:
    push ax
    push bx
    push cx
    push dx

    mov bx, [buffer_tail]
    cmp bx, [buffer_head]
    je .empty             ; Buffer empty

    mov si, keyboard_buffer
    add si, bx
    mov al, [si]
    inc bx
    cmp bx, buffer_size
    jne .skip_wrap
    xor bx, bx
.skip_wrap:
    mov [buffer_tail], bx
    jmp .done

.empty:
    mov al, 0             ; Return null if empty

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; -------------------------------
; Scancode to ASCII Table
; -------------------------------
scancode_table:
    db 0, 27, '1','2','3','4','5','6','7','8','9','0','-','=', 8, 9
    db 'q','w','e','r','t','y','u','i','o','p','[',']',13, 0,'a','s'
    db 'd','f','g','h','j','k','l',';',39,'`', 0,'\\','z','x','c','v'
    db 'b','n','m',',','.','/', 0, '*', 0, ' '

; -------------------------------
; Boot Message
; -------------------------------
msg db "8088/OS Kernel Initialized", 0
