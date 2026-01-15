bits 16
org 0x0000

start:
    cli
    mov ax, 0x0800
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0xFFFE

    mov [boot_drive], dl

    ;call init_pic
    ;call install_timer_handler
    ;call enable_irq0
    call install_keyboard_handler
    ;call enable_irq1
    ;call install_irq_handlers_3_to_7
    ;call enable_irq3_to_7

    call install_syscall_handler

    sti

    mov si, msg
    call print_string

    call load_shell
    call jump_to_shell

hang:
    jmp hang


; ---------------------------------
; Install Keyboard Handler into IVT
; ---------------------------------
install_keyboard_handler:
    push ds
    xor ax, ax
    mov ds, ax
    ;mov word [0x0084], keyboard_handler
    ;mov word [0x0086], cs
    mov word [0x24], keyboard_handler
    mov word [0x26], cs
    pop ds
    ret

; -------------------------------------
; Install System Call Handler (INT 60h)
; -------------------------------------
install_syscall_handler:
    push ds
    xor ax, ax
    mov ds, ax
    mov word [0x0180], syscall_handler
    mov word [0x0182], cs
    pop ds
    ret

; ------------------------------------
; Keyboard Interrupt Handler (INT 09h)
; ------------------------------------
keyboard_handler:
    pushf
    push ax
    push bx
    push cx
    push dx
    push si
    push di
    push bp
    push ds
    push es

    mov ax, cs
    mov ds, ax
    mov es, ax

    in al, 0x60                     ; Read scancode from keyboard

    ; Check for break code (key release, bit 7 set)
    test al, 0x80
    jnz .key_release

    ; ============================================
    ; KEY PRESS (make code)
    ; ============================================

    ; Clear AH before any comparisons to avoid contamination
    xor ah, ah

    ; Validate scancode range
    cmp al, 0x53
    ja .done

    ; Check for CapsLock toggle (0x3A)
    cmp al, 0x3A
    je .caps_lock_press

    ; Check for Left Shift press (0x2A)
    cmp al, 0x2A
    je .left_shift_press

    ; Check for Right Shift press (0x36)
    cmp al, 0x36
    je .right_shift_press

    ; Check for Left Ctrl press (0x1D)
    cmp al, 0x1D
    je .left_ctrl_press

    ; Check for Left Alt press (0x38)
    cmp al, 0x38
    je .left_alt_press

    ; ============================================
    ; NORMAL KEY - Determine if it's a letter
    ; ============================================

    ; Check Q-P row (scancodes 0x10-0x19)
    cmp al, 0x10
    jb .not_letter
    cmp al, 0x19
    jbe .is_letter

    ; Gap: 0x1A-0x1D ([, ], Enter, Ctrl) - NOT letters
    cmp al, 0x1D
    jbe .not_letter

    ; Check A-L row (scancodes 0x1E-0x26)
    cmp al, 0x1E
    jb .not_letter
    cmp al, 0x26
    jbe .is_letter

    ; Gap: 0x27-0x2B (;, ', `, Left Shift, \) - NOT letters
    cmp al, 0x2B
    jbe .not_letter

    ; Check Z-M row (scancodes 0x2C-0x32)
    cmp al, 0x2C
    jb .not_letter
    cmp al, 0x32
    jbe .is_letter

    ; Everything else - NOT letters
    jmp .not_letter

    ; ============================================
    ; NOT A LETTER - Only Shift affects it
    ; ============================================
.not_letter:
    ; Check if ANY shift is pressed (test bits 0 and 1)
    mov cl, [shift_pressed]
    test cl, cl
    jz .use_normal_table
    jmp .use_shift_table

    ; ============================================
    ; IS A LETTER - Apply CapsLock XOR Shift
    ; ============================================
.is_letter:
    ; Normalize shift to boolean
    mov cl, [shift_pressed]
    test cl, cl
    jz .shift_is_zero
    mov cl, 1

.shift_is_zero:
    ; XOR with CapsLock state
    xor cl, [caps_lock]             ; CL = Shift XOR CapsLock

    ; If result is 1, use uppercase; if 0, use lowercase
    test cl, cl
    jnz .use_shift_table
    jmp .use_normal_table

    ; ============================================
    ; TABLE SELECTION - Use BL only for indexing
    ; ============================================
.use_normal_table:
    xor bx, bx
    mov bl, al
    mov si, scancode_table
    mov al, [si + bx]
    jmp .check_valid

.use_shift_table:
    xor bx, bx
    mov bl, al
    mov si, scancode_table_shift
    mov al, [si + bx]
    jmp .check_valid

.check_valid:
    ; Only buffer non-zero characters
    cmp al, 0
    je .done

    ; Clear AH to avoid register contamination
    xor ah, ah
    call buffer_put
    jmp .done

    ; ============================================
    ; MODIFIER KEY PRESSES
    ; ============================================
.caps_lock_press:
    ; Toggle CapsLock state
    xor byte [caps_lock], 1
    jmp .done

.left_shift_press:
    or byte [shift_pressed], 0x01   ; Set bit 0
    jmp .done

.right_shift_press:
    or byte [shift_pressed], 0x02   ; Set bit 1
    jmp .done

.left_ctrl_press:
    or byte [ctrl_pressed], 0x01    ; Set bit 0
    jmp .done

.left_alt_press:
    or byte [alt_pressed], 0x01     ; Set bit 0
    jmp .done

    ; ============================================
    ; KEY RELEASE (break code)
    ; ============================================
.key_release:
    ; Remove break bit to get make code
    and al, 0x7F

    ; Check for Left Shift release
    cmp al, 0x2A
    je .left_shift_release

    ; Check for Right Shift release
    cmp al, 0x36
    je .right_shift_release

    ; Check for Left Ctrl release
    cmp al, 0x1D
    je .left_ctrl_release

    ; Check for Left Alt release
    cmp al, 0x38
    je .left_alt_release

    jmp .done

.left_shift_release:
    and byte [shift_pressed], 0xFE  ; Clear bit 0
    jmp .done

.right_shift_release:
    and byte [shift_pressed], 0xFD  ; Clear bit 1
    jmp .done

.left_ctrl_release:
    and byte [ctrl_pressed], 0xFE   ; Clear bit 0
    jmp .done

.left_alt_release:
    and byte [alt_pressed], 0xFE    ; Clear bit 0
    jmp .done

.done:
    ; Send EOI to PIC
    mov al, 0x20
    out 0x20, al

    pop es
    pop ds
    pop bp
    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    popf
    iret

key_tmp:    db 0
; -----------------------------
; System Call Handler (INT 60h)
; -----------------------------
syscall_handler:
    pusha
    push ds
    push es
    push ax
    mov ax, cs
    mov ds, ax
    mov es, ax
    pop ax

    cmp ah, 0x01
    je .get_char
    cmp ah, 0x02
    je .print_char
    cmp ah, 0x03
    je .malloc_syscall
    cmp ah, 0x04
    je .read_line
    cmp ah, 0x05
    je .clear_screen
    cmp ah, 0x06
    je .get_time
    cmp ah, 0x07
    je .exec
    jmp .done

.get_char:
    call buffer_get
    jmp .done

.print_char:
    mov ah, 0x0E
    int 0x10
    jmp .done

.malloc_syscall:
    ; Assumption: The requested size is in CX when the syscall is made.
    push cx          ; Save CX since malloc needs BX for size
    mov bx, cx       ; Move the requested size from CX into BX
    call malloc      ; Perform the allocation (which uses BX)
    pop cx           ; Restore CX

    ; Check if malloc failed (returns ES=0, DI=0)
    mov ax, es
    or ax, di
    jnz .malloc_ok      ; Non-zero means success

    ; Out of memory (print error msg and hang)
    mov si, oom_msg
    call print_string
    jmp $

.malloc_ok:
    ; Return the allocated segment (ES) in AX and offset (DI) in BX
    ; NOTE: malloc currently returns segment in ES and offset in DI
    mov ax, es
    mov bx, di
    jmp .done

.read_line:
    xor cx, cx
.next_char:
    call buffer_get
    cmp al, 0
    je .next_char
    cmp al, 13
    je .done_read
    cmp cx, bx
    jae .done_read
    stosb
    inc cx
    jmp .next_char
.done_read:
    mov al, cl
    jmp .done

.clear_screen:
    mov ax, 0x0600
    mov bh, 0x07
    mov cx, 0x0000
    mov dx, 0x184F
    int 0x10
    jmp .done

.get_time:
    mov ax, [tick_count]
    jmp .done

.exec:
    push ax
    push bx
    push cx
    push dx
    push es

    mov dl, [boot_drive]   ; use boot drive
    xor dh, dh             ; head 0 for simple case
    mov bx, 0x0000
    mov ax, 0x5000         ; Changed from 0x3000 to 0x5000
    mov es, ax
    xor ch, ch
    mov cl, al             ; sector number from caller
    mov ax, 0x0201         ; read 1 sector
    int 0x13
    jc .disk_error

    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    jmp 0x5000:0000        ; FIXED: Changed from 0x3000:0000 to 0x5000:0000

.disk_error:
    mov si, disk_err_msg
    call print_string
    jmp $

.done:
    pop es
    pop ds
    mov byte cs:[key_tmp], al
    popa
    mov al, byte cs:[key_tmp]
    iret

; -------------------------------
; Jump to Shell at 0x2000:0000
; -------------------------------
jump_to_shell:
    jmp 0x2000:0000

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

buffer_put:
    cli
    mov bx, [buffer_head]
    mov cx, [buffer_tail]
    mov dx, buffer_size
    inc bx
    cmp bx, dx
    jne .skip_wrap
    xor bx, bx
.skip_wrap:
    cmp bx, cx
    je .full

    mov si, keyboard_buffer
    add si, [buffer_head]
    mov [si], al
    mov [buffer_head], bx
    sti
    ret

.full:
    sti
    ret

buffer_get:
    cli
    mov bx, [buffer_tail]
    cmp bx, [buffer_head]
    je .empty

    mov si, keyboard_buffer
    add si, bx
    mov al, [si]
    inc bx
    cmp bx, buffer_size
    jne .skip_wrap
    xor bx, bx
.skip_wrap:
    mov [buffer_tail], bx
    sti
    ret
    jmp .done

.empty:
    mov al, 0
    sti
    ret

.done:
    ret

; -------------------------------
; Heap Allocator with Bounds Checking
; -------------------------------
; Heap range: 0x3000:0000 to 0x4FFF:FFFF (128KB)
; Returns: ES:DI = allocated memory (or 0:0 if failed)
; Input: BX = size in bytes
; -------------------------------
free_segment dw 0x3000     ; Heap starts at 0x3000:0000
free_offset  dw 0x0000
heap_max_segment dw 0x5000 ; MUST NOT reach 0x5000 (exec region)

malloc:
    push ax
    push bx
    push cx
    push dx

    ; Get current segment and check bounds
    mov ax, [free_segment]
    mov cx, [heap_max_segment]
    cmp ax, cx
    jae .out_of_memory        ; Already at or past limit

    ; Try to allocate in current segment
    mov dx, [free_offset]
    add dx, bx                ; New offset after allocation
    jnc .alloc_current        ; No overflow, we're good

    ; Offset would overflow - need new segment
    inc ax                    ; Move to next segment (adds 0x10 to address)
    cmp ax, cx
    jae .out_of_memory        ; Would exceed heap limit

    ; Allocation spans into next segment
    mov [free_segment], ax
    mov [free_offset], bx     ; Start at bx in new segment
    mov es, ax
    xor di, di                ; Return DI=0 in new segment
    jmp .done

.alloc_current:
    ; Allocation fits in current segment
    mov es, ax
    mov di, [free_offset]     ; Return current offset
    mov [free_offset], dx     ; Update to new offset
    jmp .done

.out_of_memory:
    ; Return NULL pointer (ES=0, DI=0)
    xor ax, ax
    mov es, ax
    xor di, di

.done:
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; ---------------------------------
; Timer Interrupt Handler (INT 08h)
; ---------------------------------
tick_count dw 0

timer_handler:
    push ax
    inc word [tick_count]
    mov al, 0x20
    out 0x20, al      ; EOI to master PIC
    pop ax
    iret

; -------------------------------
; IRQ 3-7 Handlers (INT 23h - INT 27h)
; -------------------------------

; Generic handler template for IRQs 3-7
irq_handler_template:
    pusha                   ; Save all general-purpose registers
    ; Add specific IRQ logic here (e.g., handling a COM port interrupt)

    mov al, 0x20
    out 0x20, al            ; EOI to master PIC

    popa                    ; Restore all general-purpose registers
    iret                    ; Return from interrupt

irq3_handler: equ irq_handler_template
irq4_handler: equ irq_handler_template
irq5_handler: equ irq_handler_template
irq6_handler: equ irq_handler_template
irq7_handler: equ irq_handler_template

; -------------------------------
; Install Timer Handler into IVT
; -------------------------------
install_timer_handler:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov word [0x0080], timer_handler
    mov word [0x0082], cs
    sti
    ret

; -------------------------------
; Install IRQ 3-7 Handlers into IVT
; -------------------------------
install_irq_handlers_3_to_7:
    cli
    mov ax, cs
    mov ds, ax
    mov es, ax

    ; IRQ3 (INT 23h - IVT offset 0x8C)
    mov word [0x008C], irq3_handler
    mov word [0x008E], cs

    ; IRQ4 (INT 24h - IVT offset 0x90)
    mov word [0x0090], irq4_handler
    mov word [0x0092], cs

    ; IRQ5 (INT 25h - IVT offset 0x94)
    mov word [0x0094], irq5_handler
    mov word [0x0096], cs

    ; IRQ6 (INT 26h - IVT offset 0x98)
    mov word [0x0098], irq6_handler
    mov word [0x009A], cs

    ; IRQ7 (INT 27h - IVT offset 0x9C)
    mov word [0x009C], irq7_handler
    mov word [0x009E], cs

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
; Enable IRQ 3-7 in PIC
; -------------------------------
enable_irq3_to_7:
    in al, 0x21
    ; Mask to UNMASK bits 3, 4, 5, 6, 7: 11111111_2 & 00000111_2 = 0x07
    ; More readable: AND with the complement of the bits you want unmasked.
    ; Bits to unmask: 0b11111000 (0xF8)
    ; We want to clear bits 3, 4, 5, 6, 7.
    ; Bits to unmask: 3, 4, 5, 6, 7 -> 0b11111000 = 0xF8
    ; To clear these bits, we AND with the complement: NOT 0xF8 = 0x07.
    and al, 0x07                    ; Clear bits 3, 4, 5, 6, 7
    out 0x21, al
    ret

; ---------------------------------
; PIC Initialization (Remap IRQs)
; ---------------------------------
init_pic:
    pushf
    cli ; Disable interrupts during PIC setup

    ; ICW1: Start Initialization Sequence
    ; 0x11: ICW1 required, single 8259 (not cascaded), edge-triggered mode
    mov al, 0x11
    out 0x20, al    ; Write to Master PIC Command Port

    ; ICW2: Set New Vector Offset
    ; 0x20 (decimal 32): Remap IRQs 0-7 to start at INT 20h
    ; INT 20h-27h are safe from CPU exceptions
    mov al, 0x20
    out 0x21, al    ; Write to Master PIC Data Port

    ; ICW3: Cascade Information (Not used in single PIC setup, but required)
    ; 0x04: Indicates that slave PIC is on IRQ2 (not relevant for single, but standard for compatibility)
    mov al, 0x04
    out 0x21, al    ; Write to Master PIC Data Port

    ; ICW4: Mode of Operation
    ; 0x01: 8086/8088 mode (required), normal EOI
    mov al, 0x01
    out 0x21, al    ; Write to Master PIC Data Port

    ; Set Default Mask (Disable all IRQs initially)
    ; 0xFF: Mask all IRQ lines
    mov al, 0xFF
    out 0x21, al    ; Write to Master PIC Data Port
    popf ; Restore interrupt flag
    ret

; -------------------------------
; Load Shell from Disk (sector 4)
; -------------------------------
load_shell:
    push ax
    push bx
    push cx
    push dx
    push es

    mov ax, 0x2000
    mov es, ax
    mov ax, 0x0201
    mov bx, 0x0000
    mov cx, 0x0005          ; Start reading shell from sector 5
    mov dx, 0x0000
    int 0x13
    jc .error

    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    ret

.error:
    mov si, disk_err_msg
    call print_string
    jmp $

; -------------------------------
; Scancode to ASCII Table
; -------------------------------
scancode_table:
    db 0, 0, '1','2','3','4','5','6','7','8','9','0','-','=', 8, 0 ; 0x00-0x0F
    db 'q','w','e','r','t','y','u','i','o','p','[',']', 13, 0,'a','s' ; 0x10-0x1F
    db 'd','f','g','h','j','k','l',';',39, '`', 0, '\','z','x','c','v' ; 0x20-0x2F
    db 'b','n','m',',','.','/', 0, 0, 0, ' '                      ; 0x30-0x39

; -------------------------------
; Scancode to ASCII Table (Shifted)
; -------------------------------
scancode_table_shift:
    db 0, 0, '!','@','#','$','%','^','&','*','(',')','_','+', 8, 0
    db 'Q','W','E','R','T','Y','U','I','O','P','{','}', 13, 0,'A','S'
    db 'D','F','G','H','J','K','L',':','"', '~', 0, '|','Z','X','C','V'
    db 'B','N','M','<','>','?', 0, 0, 0, ' '

; -------------------------------
; Modifier Key State Flags
; -------------------------------
shift_pressed   db 0    ; Bit 0: Left Shift, Bit 1: Right Shift
ctrl_pressed    db 0    ; Bit 0: Left Ctrl, Bit 1: Right Ctrl (future)
alt_pressed     db 0    ; Bit 0: Left Alt, Bit 1: Right Alt (future)
caps_lock       db 0    ; Toggle state
num_lock        db 0    ; Toggle state
scroll_lock     db 0    ; Toggle state

; -------------------------------
; Boot Message
; -------------------------------
boot_drive db 0x00
msg db 0x0d, 0x0a, "8088/OS Kernel Initialized", 0x0d, 0x0a, 0
disk_err_msg db 0x0D,0x0A,"Disk read error!",0x0D,0x0A,0
oom_msg db 0x0D,0x0A,"Out of memory!",0x0D,0x0A,0
