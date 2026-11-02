; ==========================================================
; main.asm
; Punto de entrada del proyecto LowMonitor.
; Llama a cada modulo en orden y termina el proceso.
;
; Los modulos y utilidades viven en archivos separados y se
; enlazan juntos mediante el Makefile:
;   utils.asm           -> print_string, strlen
;   modulo1_cpu.asm     -> modulo1_cpu
;   modulo2_ioports.asm -> modulo2_ioports
; ==========================================================

extern modulo1_cpu
extern modulo2_ioports
extern modulo3_memoria

section .text
    global _start

_start:
    ; Modulo 1: Identificacion del CPU
    call modulo1_cpu

    ; Modulo 2: Monitor de puertos E/S
    call modulo2_ioports

    ; Modulo 3: Diagnostico de memoria
    call modulo3_memoria

    ; (Aqui se encadenaran los modulos 4, 5 y 6)

    ; --- Salida del programa ---
    mov rax, 60         ; syscall: exit
    mov rdi, 0          ; codigo de salida 0
    syscall
