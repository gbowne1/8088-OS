org 0x0000

buffer_size equ 64

; -------------------------------
; Data Section
; -------------------------------
prompt db "8088/OS Shell> ", 0
unknown_cmd db "Unknown command", 13, 10, 0
echo_cmd db "echo", 0
clear_cmd db "clear", 0
help_cmd db "help", 0
help_text db "Commands: echo, clear, help", 13, 10, 0

line_buffer: times buffer_size db 0

; -------------------------------
; Entry Point
; -------------------------------
start:
    mov si, prompt
    call print_string

.loop:
    call read_line
    call parse_command
    jmp .loop

; -------------------------------
; Read Line from Keyboard
; -------------------------------
read_line:
    mov di, 0
.read_char:
    mov ah, 0x01
    int 0x60
    cmp al, 0
    je .read_char
    cmp al, 0x0D
    je .done
    cmp di, buffer_size
    jae .read_char
    mov [line_buffer + di], al
    inc di
    mov ah, 0x02
    int 0x60
    jmp .read_char
.done:
    mov byte [line_buffer + di], 0
    ret

; -------------------------------
; Parse and Execute Command
; -------------------------------
parse_command:
    mov si, line_buffer
    mov di, echo_cmd
    call strcmp
    cmp al, 0
    jne .check_clear
    call echo_handler
    ret

.check_clear:
    mov si, line_buffer
    mov di, clear_cmd
    call strcmp
    cmp al, 0
    jne .check_help
    call clear_handler
    ret

.check_help:
    mov si, line_buffer
    mov di, help_cmd
    call strcmp
    cmp al, 0
    jne .unknown
    call help_handler
    ret

.unknown:
    mov si, unknown_cmd
    call print_string
    ret

; -------------------------------
; Echo Handler
; -------------------------------
echo_handler:
    mov si, line_buffer + 5
    call print_string
    ret

; -------------------------------
; Clear Screen Handler
; -------------------------------
clear_handler:
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    ret

; -------------------------------
; Help Handler
; -------------------------------
help_handler:
    mov si, help_text
    call print_string
    ret

; -------------------------------
; Print String Routine
; -------------------------------
print_string:
    mov ah, 0x0E
.next:
    lodsb
    cmp al, 0
    je .done
    int 0x10
    jmp .next
.done:
    ret

; -------------------------------
; String Compare Routine
; -------------------------------
strcmp:
    push si
    push di
.next:
    lodsb
    cmp al, [di]
    jne .notequal
    cmp al, 0
    je .equal
    inc di
    jmp .next
.notequal:
    mov al, 1
    pop di
    pop si
    ret
.equal:
    xor al, al
    pop di
    pop si
    ret
