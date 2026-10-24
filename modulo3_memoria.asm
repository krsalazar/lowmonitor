; ==========================================================
; modulo3_memoria.asm
; Modulo 3: Diagnostico de memoria
;   Testea la integridad de un bloque de memoria aplicando tres
;   patrones de prueba (0xAA, 0x55 y una secuencia incremental),
;   escribiendo y releyendo cada byte, y contando los BITS
;   corruptos (no solo los bytes) cuando el valor leido difiere
;   del escrito.
;
;   Ademas reporta la RAM total del sistema obtenida con el
;   syscall sysinfo (99), sin requerir privilegios.
;
; Expone la rutina 'modulo3_memoria', llamada desde main.asm.
; Depende de print_string y print_uint (utils.asm).
;
; Nota: se prueba un buffer en espacio de usuario (BUF_SIZE), no
; toda la RAM fisica, ya que mapear toda la memoria fisica exige
; privilegios de kernel. El algoritmo es el estandar de un test
; de memoria (escribir patron -> releer -> comparar).
; ==========================================================

extern print_string
extern print_uint

%define BUF_SIZE 1048576        ; 1 MiB de buffer de prueba

section .data
    msg_titulo    db "--- Modulo 3: Diagnostico de memoria ---", 10, 0

    lbl_aa        db "Patron 0xAA:              ", 0
    lbl_55        db "Patron 0x55:              ", 0
    lbl_inc       db "Patron incremental:       ", 0

    msg_pasada    db "PASADA (0 errores)", 10, 0
    msg_fallo_a   db "FALLO (", 0
    msg_fallo_b   db " bits corruptos)", 10, 0

    lbl_total     db "Memoria total:            ", 0
    msg_mb        db " MB detectada", 10, 0

    lbl_buffer    db "Buffer probado:           ", 0
    msg_kb        db " KB", 10, 0

    msg_salto     db 10, 0

section .bss
    buffer    resb BUF_SIZE     ; bloque bajo prueba
    sysinfo_b resb 128          ; buffer para struct sysinfo

section .text
    global modulo3_memoria

; ----------------------------------------------------------
; test_patron
;   Escribe un patron de byte fijo en todo el buffer, lo relee
;   y cuenta los bits que no coinciden.
;   Entrada: SIL = byte de patron a usar
;   Salida : RAX = total de bits corruptos encontrados
; ----------------------------------------------------------
test_patron:
    ; Fase de escritura
    mov rcx, BUF_SIZE
    mov rdi, buffer
.escribir:
    mov byte [rdi], sil
    inc rdi
    dec rcx
    jnz .escribir

    ; Fase de lectura/comparacion
    xor rax, rax            ; acumulador de bits corruptos
    mov rcx, BUF_SIZE
    mov rdi, buffer
.comparar:
    mov r8b, byte [rdi]     ; valor leido
    mov r9b, sil            ; valor esperado
    xor r8b, r9b            ; bits distintos quedan en 1
    jz .siguiente           ; si 0, no hay diferencia
    movzx r8, r8b
    popcnt r8, r8           ; contar bits en 1
    add rax, r8
.siguiente:
    inc rdi
    dec rcx
    jnz .comparar
    ret

; ----------------------------------------------------------
; test_incremental
;   Escribe en cada byte un valor incremental (indice mod 256),
;   relee y cuenta bits corruptos.
;   Salida : RAX = total de bits corruptos
; ----------------------------------------------------------
test_incremental:
    ; Escritura: buffer[i] = i (truncado a 8 bits)
    xor rcx, rcx
    mov rdi, buffer
.escribir:
    mov rax, rcx
    mov byte [rdi], al      ; i mod 256
    inc rdi
    inc rcx
    cmp rcx, BUF_SIZE
    jb .escribir

    ; Comparacion
    xor r10, r10            ; acumulador de bits corruptos
    xor rcx, rcx
    mov rdi, buffer
.comparar:
    mov r8b, byte [rdi]     ; leido
    mov rax, rcx
    mov r9b, al             ; esperado = i mod 256
    xor r8b, r9b
    jz .siguiente
    movzx r8, r8b
    popcnt r8, r8
    add r10, r8
.siguiente:
    inc rdi
    inc rcx
    cmp rcx, BUF_SIZE
    jb .comparar
    mov rax, r10
    ret

; ----------------------------------------------------------
; imprimir_resultado
;   Imprime "PASADA" si RAX==0, o "FALLO (N bits corruptos)".
;   Entrada: RAX = numero de bits corruptos
; ----------------------------------------------------------
imprimir_resultado:
    test rax, rax
    jnz .con_fallo
    mov rdi, msg_pasada
    call print_string
    ret
.con_fallo:
    push rbx               ; preservar conteo en registro callee-saved
    mov rbx, rax
    mov rdi, msg_fallo_a
    call print_string
    mov rdi, rbx
    call print_uint
    mov rdi, msg_fallo_b
    call print_string
    pop rbx
    ret

modulo3_memoria:
    mov rdi, msg_titulo
    call print_string

    ; --- Patron 0xAA ---
    mov rdi, lbl_aa
    call print_string
    mov sil, 0xAA
    call test_patron
    call imprimir_resultado

    ; --- Patron 0x55 ---
    mov rdi, lbl_55
    call print_string
    mov sil, 0x55
    call test_patron
    call imprimir_resultado

    ; --- Patron incremental ---
    mov rdi, lbl_inc
    call print_string
    call test_incremental
    call imprimir_resultado

    ; --- RAM total via sysinfo ---
    mov rax, 99             ; syscall sysinfo
    mov rdi, sysinfo_b
    syscall
    ; struct sysinfo (x86-64): totalram en offset 32, mem_unit en
    ; offset 104. total_bytes = totalram * mem_unit.
    mov rax, [sysinfo_b + 32]    ; totalram  (offset 32 en x86-64)
    mov r8d, dword [sysinfo_b + 104] ; mem_unit (offset 104, unsigned int)
    test r8, r8
    jnz .tiene_unit
    mov r8, 1               ; si mem_unit==0, tratar como 1
.tiene_unit:
    mul r8                  ; RAX = totalram * mem_unit (bytes)
    ; convertir a MB: dividir entre 1048576
    mov rbx, 1048576
    xor rdx, rdx
    div rbx                 ; RAX = MB
    mov r12, rax            ; guardar MB

    mov rdi, lbl_total
    call print_string
    mov rdi, r12
    call print_uint
    mov rdi, msg_mb
    call print_string

    ; --- Tamano del buffer probado (en KB) ---
    mov rdi, lbl_buffer
    call print_string
    mov rdi, BUF_SIZE / 1024
    call print_uint
    mov rdi, msg_kb
    call print_string

    mov rdi, msg_salto
    call print_string
    ret
