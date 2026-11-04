; ==========================================================
; modulo4_rendimiento.asm - Modulo 4: Monitor de rendimiento del CPU
;   Con RDTSC (serializado con CPUID) mide la frecuencia del TSC
;   (ciclos en 100 ms de nanosleep) y los ciclos de un bucle de
;   ITERS x 5 instrucciones. CPI = ciclos / instrucciones; IPC es su
;   inverso.
;
;   El TSC es invariante: refleja la frecuencia del contador, no la
;   instantanea del nucleo. El conteo de instrucciones es exacto por
;   construccion del bucle (no usa la PMU).
; ==========================================================

extern print_string
extern print_uint
extern print_fixed2

; Bucle medido: ITERS iteraciones x 5 instrucciones (add, add, add, dec, jnz).
%define ITERS          100000000           ; 100 millones
%define INSTR_POR_ITER 5

section .data
    msg_titulo    db "--- Modulo 4: Monitor de rendimiento del CPU ---", 10, 0

    lbl_freq      db "Frecuencia (TSC):         ", 0
    msg_ghz       db " GHz", 10, 0

    lbl_ciclos    db "Ciclos totales:           ", 0
    msg_nl        db 10, 0

    lbl_instr     db "Instrucciones ejecutadas: ", 0
    lbl_cpi       db "CPI promedio:             ", 0
    lbl_ipc       db "IPC:                      ", 0

    msg_salto     db 10, 0

    ; timespec para nanosleep: 0 s, 100 ms = 100,000,000 ns
    ts_100ms:
        dq 0
        dq 100000000

section .bss
    ts_rem    resq 2        ; timespec restante (si nanosleep se interrumpe)

section .text
    global modulo4_rendimiento

; ----------------------------------------------------------
; leer_tsc: devuelve en RAX el TSC de 64 bits, serializado.
;   CPUID actua de barrera para impedir reordenamiento.
;   Altera: RAX, RBX, RCX, RDX.
; ----------------------------------------------------------
leer_tsc:
    push rbx
    xor eax, eax
    cpuid                   ; barrera de serializacion
    rdtsc                   ; EDX:EAX = TSC
    shl rdx, 32
    or rax, rdx             ; RAX = TSC completo de 64 bits
    pop rbx
    ret

modulo4_rendimiento:
    push r12
    push r13
    push r14
    push r15

    mov rdi, msg_titulo
    call print_string

    ; ==========================================================
    ; 1. Estimar la frecuencia del TSC
    ;    Hz = ciclos durante 100 ms / 0.1
    ; ==========================================================
    call leer_tsc
    mov r12, rax            ; TSC inicial

    mov rax, 35             ; syscall nanosleep
    mov rdi, ts_100ms
    mov rsi, ts_rem
    syscall

    call leer_tsc
    sub rax, r12            ; RAX = ciclos durante ~100 ms
    mov r13, rax            ; guardar ciclos/0.1s

    ; frecuencia en Hz = ciclos * 10 ; en GHz escalado x100:
    ;   GHz*100 = (ciclos * 10) / 1e9 * 100 = ciclos / 1e6
    mov rax, r13
    xor rdx, rdx
    mov rcx, 1000000
    div rcx                 ; RAX = GHz * 100  (parte entera de ciclos/1e6)

    mov rdi, lbl_freq
    push rax
    call print_string
    pop rdi                 ; RDI = GHz*100
    call print_fixed2
    mov rdi, msg_ghz
    call print_string

    ; ==========================================================
    ; 2. Medir ciclos de un bloque de trabajo conocido
    ; ==========================================================
    call leer_tsc
    mov r14, rax            ; TSC inicial del trabajo

    ; Bucle de trabajo: 5 instrucciones por iteracion (INSTR_POR_ITER)
    xor r8, r8
    xor r9, r9
    xor r10, r10
    mov rcx, ITERS
.trabajo:
    add r8, 1
    add r9, 1
    add r10, 1
    dec rcx
    jnz .trabajo

    call leer_tsc
    sub rax, r14            ; RAX = ciclos del trabajo
    mov r15, rax            ; guardar ciclos totales

    ; Imprimir ciclos totales
    mov rdi, lbl_ciclos
    call print_string
    mov rdi, r15
    call print_uint
    mov rdi, msg_nl
    call print_string

    ; Instrucciones ejecutadas = ITERS * INSTR_POR_ITER
    mov rax, ITERS
    mov rcx, INSTR_POR_ITER
    mul rcx                 ; RAX = total de instrucciones
    mov r12, rax            ; r12 = instrucciones

    mov rdi, lbl_instr
    call print_string
    mov rdi, r12
    call print_uint
    mov rdi, msg_nl
    call print_string

    ; ==========================================================
    ; 3. CPI = ciclos / instrucciones  (escalado x100 para 2 dec)
    ;    CPI*100 = ciclos * 100 / instrucciones
    ; ==========================================================
    mov rax, r15
    xor rdx, rdx
    mov rcx, 100
    mul rcx                 ; RDX:RAX = ciclos * 100
    div r12                 ; RAX = CPI * 100
    mov rdi, lbl_cpi
    push rax
    call print_string
    pop rdi
    call print_fixed2
    mov rdi, msg_nl
    call print_string

    ; ==========================================================
    ; 4. IPC = instrucciones / ciclos  (escalado x100)
    ;    IPC*100 = instrucciones * 100 / ciclos
    ; ==========================================================
    mov rax, r12
    xor rdx, rdx
    mov rcx, 100
    mul rcx                 ; RDX:RAX = instrucciones * 100
    div r15                 ; RAX = IPC * 100
    mov rdi, lbl_ipc
    push rax
    call print_string
    pop rdi
    call print_fixed2
    mov rdi, msg_nl
    call print_string

    mov rdi, msg_salto
    call print_string

    pop r15
    pop r14
    pop r13
    pop r12
    ret
