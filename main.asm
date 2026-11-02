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
extern modulo4_rendimiento
extern modulo5_jerarquia

section .text
    global _start

_start:
    ; Modulo 1: Identificacion del CPU
    call modulo1_cpu

    ; Modulo 2: Monitor de puertos E/S
    call modulo2_ioports

    ; Modulo 3: Diagnostico de memoria
    call modulo3_memoria

    ; Modulo 4: Monitor de rendimiento del CPU
    call modulo4_rendimiento

    ; Modulo 5: Gestion jerarquica de memoria
    call modulo5_jerarquia

    ; (Aqui se encadenara el modulo 6)

    ; --- Salida del programa ---
    mov rax, 60         ; syscall: exit
    mov rdi, 0          ; codigo de salida 0
    syscall
