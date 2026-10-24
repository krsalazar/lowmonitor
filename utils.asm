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
;   Metodo : division sucesiva por 10; los restos son los
;            digitos en orden inverso, se apilan y luego se
;            emiten en orden correcto.
;   Altera : RAX, RBX, RCX, RDX, RSI, RDI (clobbers de syscall)
;   Usa la pila como buffer temporal de digitos.
; ----------------------------------------------------------
print_uint:
    mov rax, rdi        ; RAX = valor
    mov rbx, 10         ; divisor
    xor rcx, rcx        ; RCX = contador de digitos apilados

    ; Caso especial: valor == 0 -> imprimir '0'
    test rax, rax
    jnz .extraer
    push '0'
    inc rcx
    jmp .emitir

.extraer:
    ; Mientras RAX != 0: dividir por 10, apilar (resto + '0')
    xor rdx, rdx        ; limpiar RDX antes de DIV (dividendo de 128 bits)
    div rbx             ; RAX = cociente, RDX = resto (0..9)
    add dl, '0'         ; convertir resto a caracter ASCII
    movzx rdx, dl
    push rdx            ; apilar el caracter (8 bytes)
    inc rcx
    test rax, rax
    jnz .extraer

.emitir:
    ; Desapilar e imprimir cada digito en orden correcto.
.loop_emitir:
    test rcx, rcx
    jz .done
    pop rax             ; RAX = caracter (en el byte bajo)
    ; escribir 1 byte usando la pila como buffer
    push rax            ; dejar el byte en memoria para write
    mov rax, 1          ; syscall write
    mov rdi, 1          ; stdout
    mov rsi, rsp        ; puntero al byte recien apilado
    mov rdx, 1          ; longitud 1
    syscall
    pop rax             ; descartar el byte temporal
    dec rcx
    jmp .loop_emitir

.done:
    ret
