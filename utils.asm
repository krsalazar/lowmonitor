; ==========================================================
; utils.asm
; Rutinas auxiliares compartidas por todos los modulos.
; Se exponen con 'global' para que main.asm y los modulos
; las usen mediante 'extern'.
; ==========================================================

section .text
    global print_string
    global strlen

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
