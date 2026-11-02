; ==========================================================
; utils.asm
; Rutinas auxiliares compartidas por todos los modulos.
; Se exponen con 'global' para que main.asm y los modulos
; las usen mediante 'extern'.
; ==========================================================

section .text
    global print_string
    global strlen
    global print_uint

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
;   Metodo : se extraen los digitos por division sucesiva entre
;            10 y se escriben de atras hacia adelante en un buffer
;            fijo; al final se emiten con UN solo write.
;   Importante: NO se hace ningun syscall dentro del bucle de
;   extraccion, porque la instruccion syscall destruye RCX y R11;
;   todo el syscall write ocurre una sola vez al final.
;   Altera : RAX, RCX, RDX, RSI, RDI, R8, R9 (clobbers de syscall)
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

section .bss
    ; Buffer para la conversion de enteros a texto en print_uint.
    ; 20 bytes bastan para el maximo uint64 (18446744073709551615).
    uint_buf  resb 20
