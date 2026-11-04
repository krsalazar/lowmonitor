; ==========================================================
; utils.asm - Rutinas compartidas: impresion de cadenas y numeros.
; ==========================================================

section .text
    global print_string
    global strlen
    global print_uint
    global print_fixed2

; ----------------------------------------------------------
; strlen: calcula la longitud de una cadena terminada en NUL.
;   Entrada: RDI = puntero a la cadena
;   Salida : RAX = numero de bytes antes del 0
;   Altera : RAX (preserva RDI)
; ----------------------------------------------------------
strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret

; ----------------------------------------------------------
; print_string: escribe una cadena NUL-terminada en stdout.
;   Entrada: RDI = puntero a la cadena
;   Usa el syscall write (rax=1, fd=1=stdout).
;   Altera : RAX, RSI, RDX (clobbers de syscall)
; ----------------------------------------------------------
print_string:
    push rdi            ; guardar el puntero (strlen usa RDI)
    call strlen         ; RAX = longitud
    mov rdx, rax        ; RDX = cantidad de bytes a escribir
    pop rsi             ; RSI = puntero a la cadena (buffer)
    mov rax, 1          ; syscall: write
    mov rdi, 1          ; fd: stdout
    syscall
    ret

; ----------------------------------------------------------
; print_uint: imprime un entero de 64 bits SIN signo en decimal.
;   Entrada: RDI = valor a imprimir
;   Extrae los digitos por division entre 10 (de atras hacia adelante
;   en un buffer) y los emite con un unico write: un syscall dentro
;   del bucle destruiria RCX y R11.
;   Altera : RAX, RCX, RDX, RSI, RDI, R9, R11
; ----------------------------------------------------------
print_uint:
    mov rax, rdi            ; RAX = valor
    mov r9, 10              ; divisor
    ; RSI apunta al final del buffer y se decrementa antes de cada
    ; escritura, dejando los digitos en orden correcto.
    lea rsi, [uint_buf + 20]

    ; Caso especial: valor == 0
    test rax, rax
    jnz .extraer
    dec rsi
    mov byte [rsi], '0'
    jmp .emitir

.extraer:
    ; Mientras RAX != 0: dividir por 10; el resto es un digito.
.loop_div:
    xor rdx, rdx            ; limpiar RDX antes de DIV de 128 bits
    div r9                  ; RAX = cociente, RDX = resto (0..9)
    add dl, '0'             ; resto -> ASCII
    dec rsi                 ; retroceder una posicion en el buffer
    mov [rsi], dl           ; escribir el digito
    test rax, rax
    jnz .loop_div

.emitir:
    ; RSI apunta al primer digito; la longitud es (fin - RSI).
    lea rdx, [uint_buf + 20]
    sub rdx, rsi            ; RDX = cantidad de digitos
    mov rax, 1              ; syscall write
    mov rdi, 1              ; stdout
    syscall                 ; un unico write con todos los digitos
    ret

; ----------------------------------------------------------
; print_fixed2: imprime un numero con 2 decimales a partir de un
;   entero escalado por 100. Ej: 158 -> "1.58", 56 -> "0.56",
;   340 -> "3.40", 7 -> "0.07".
;   Entrada: RDI = valor escalado (valor_real * 100)
; ----------------------------------------------------------
print_fixed2:
    push rbx
    mov rax, rdi
    xor rdx, rdx
    mov rbx, 100
    div rbx                 ; RAX = parte entera, RDX = resto (0..99)
    push rdx                ; guardar los 2 decimales

    ; Imprimir la parte entera reutilizando print_uint
    mov rdi, rax
    call print_uint

    ; Imprimir el punto decimal
    mov byte [fixed_tmp], '.'
    mov rax, 1
    mov rdi, 1
    mov rsi, fixed_tmp
    mov rdx, 1
    syscall

    ; Imprimir los 2 decimales con cero a la izquierda si hace falta
    pop rax                 ; RAX = resto (0..99)
    mov rcx, 10
    xor rdx, rdx
    div rcx                 ; RAX = decena, RDX = unidad
    add al, '0'
    add dl, '0'
    mov [fixed_tmp], al     ; primer decimal
    mov [fixed_tmp + 1], dl ; segundo decimal
    mov rax, 1
    mov rdi, 1
    mov rsi, fixed_tmp
    mov rdx, 2
    syscall

    pop rbx
    ret

section .bss
    fixed_tmp resb 2        ; buffer temporal de print_fixed2
    ; Buffer para la conversion de enteros a texto en print_uint.
    ; 20 bytes bastan para el maximo uint64 (18446744073709551615).
    uint_buf  resb 20
