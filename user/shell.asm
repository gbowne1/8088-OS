org 0x0000

buffer_size equ 64

; -------------------------------
; Entry Point
; -------------------------------
start:
    mov ax, 0x2000
    mov ds, ax
    mov es, ax

.loop:
    mov si, prompt
    call print_string

    call read_line
    call parse_command
    jmp .loop

; -------------------------------
; Read Line from Keyboard
; -------------------------------
read_line:
    mov di, 0
    mov byte [buffer_warned], 0     ; reset warning flag
.read_char:
    mov ah, 0x01
    int 0x60
    cmp al, 0
    je .read_char
    cmp al, 0x0D
    je .done
    cmp al, 0x08        ; Backspace?
    je .handle_backspace
    cmp di, buffer_size
    jae .buffer_full
    mov [line_buffer + di], al
    inc di
    mov ah, 0x02
    int 0x60
    jmp .read_char

.handle_backspace:
    cmp di, 0       ; Buffer empty?
    je .read_char
    dec di          ; Remove the buffer

    ; Erase from screen: backspace, space, backspace
    mov al, 0x08
    mov ah, 0x02
    int 0x60
    mov al, ' '
    mov ah, 0x02
    int 0x60
    mov al, 0x08
    mov ah, 0x02
    int 0x60
    jmp .read_char

.buffer_full:
    cmp byte [buffer_warned], 1
    je .read_char       ; skip warning if already warned

    ; Visual feedback (print a warning message)
    push si
    mov si, buffer_full_msg
    call print_string
    pop si

    ; Print bell character (beeps)
    mov al, 0x07
    mov ah, 0x02
    int 0x60

    mov byte [buffer_warned], 1     ; set warning flag
    jmp .read_char
.done:
    mov byte [line_buffer + di], 0
    ret

; -------------------------------
; Parse and Execute Command
; -------------------------------
parse_command:
    mov si, line_buffer
    call tokenize

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
    mov si, string_crlf
    call print_string

    mov si, [args_ptr]
    cmp si, 0
    je .done

    call print_string
.done:
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
.exit:
    pop di
    pop si
    ret
.equal:
    xor al, al
    pop di
    pop si
    ret

tokenize:
    push si
    mov si, line_buffer
    mov word [args_ptr], 0

.skip_leading:
    lodsb
    cmp al, ' '
    je .skip_leading
    dec si

.find_space:
    lodsb
    cmp al, 0
    je .done
    cmp al, ' '
    jne .find_space

    ; terminate command
    mov byte [si-1], 0

.skip_spaces:
    lodsb
    cmp al, ' '
    je .skip_spaces
    dec si

    mov [args_ptr], si
.done:
    pop si
    ret

; -------------------------------
; Data Section
; -------------------------------
prompt db 0x0d,0x0a,"8088/OS Shell> ", 0
unknown_cmd db 0x0d, 0x0a, "Unknown command", 13, 10, 0
echo_cmd db "echo", 0
clear_cmd db "clear", 0
help_cmd db "help", 0
help_text db 0x0d, 0x0a, "Commands: echo, clear, help", 13, 10, 0
string_crlf db 0x0d, 0x0a, 0
buffer_full_msg db 0x0D, 0x0A, "[Buffer full! - Press Enter to continue]", 0x0D, 0x0A, 0
buffer_warned db 0      ; Flag to track if warned or not
args_ptr dw 0           ; Pointer to command arguments

line_buffer: times buffer_size db 0
