; ==========================================================
; modulo6_simd.asm
; Modulo 6: Operaciones SIMD (bonus)
;   Demuestra operaciones vectoriales con AVX2 (registros YMM de
;   256 bits = 8 floats de 32 bits en paralelo):
;     - Suma vectorizada        (vaddps)
;     - Multiplicacion          (vmulps)
;     - Comparacion             (vcmpps)
;   y mide un throughput aproximado en GFLOPS.
;
; Expone la rutina 'modulo6_simd', llamada desde main.asm.
; Depende de print_string, print_uint y print_fixed2 (utils.asm).
;
; Deteccion: se consulta CPUID hoja 7 (EBX bit 5 = AVX2). Si no
; esta disponible, el modulo informa y omite las operaciones YMM.
;
; GFLOPS: se ejecuta un bucle de operaciones de punto flotante
; vectorizadas, se miden los ciclos con RDTSC y se estima el
; tiempo usando la frecuencia del TSC (medida con nanosleep, igual
; que en el Modulo 4):
;     GFLOPS = FLOPs_totales / segundos / 1e9
;     segundos = ciclos / frecuencia_Hz
;
; Nota de honestidad: el tiempo se deriva del TSC (frecuencia
; constante), no de un reloj de pared de alta resolucion; el valor
; de GFLOPS es una estimacion representativa, no una medida de
; laboratorio.
; ==========================================================

extern print_string
extern print_uint
extern print_fixed2

%define ITERS_FLOP  10000000       ; iteraciones del bucle de GFLOPS

section .data
    msg_titulo   db "--- Modulo 6: Operaciones SIMD (AVX2) ---", 10, 0

    lbl_avx2     db "AVX2 habilitado:          ", 0
    msg_si       db "Si", 10, 0
    msg_no       db "No (se omiten operaciones YMM)", 10, 0

    lbl_suma     db "Suma vectorizada (vaddps):     ", 0
    lbl_mul      db "Multiplicacion   (vmulps):     ", 0
    lbl_cmp      db "Comparacion      (vcmpps):     ", 0
    msg_ok8      db "8 floats en paralelo [OK]", 10, 0

    lbl_through  db "Throughput:               ", 0
    msg_through  db " operaciones paralelas (YMM, 8x float32)", 10, 0

    lbl_gflops   db "Benchmark:                ", 0
    msg_gflops   db " GFLOPS", 10, 0

    msg_salto    db 10, 0

    ; timespec para nanosleep: 100 ms
    ts6_100ms:
        dq 0
        dq 100000000

    ; Dos vectores de 8 floats (32 bytes, alineados a 32 para YMM).
    align 32
    vec_a   dd 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0
    align 32
    vec_b   dd 8.0, 7.0, 6.0, 5.0, 4.0, 3.0, 2.0, 1.0
    align 32
    vec_res dd 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0

section .bss
    ts6_rem   resq 2
    avx2_ok   resb 1

section .text
    global modulo6_simd

; ----------------------------------------------------------
; leer_tsc_m6: RAX = TSC de 64 bits, serializado con CPUID.
; ----------------------------------------------------------
leer_tsc_m6:
    push rbx
    xor eax, eax
    cpuid
    rdtsc
    shl rdx, 32
    or rax, rdx
    pop rbx
    ret

modulo6_simd:
    push r12
    push r13
    push r14
    push r15

    mov rdi, msg_titulo
    call print_string

    ; --- 1. Detectar AVX2 (CPUID hoja 7, EBX bit 5) ---
    mov eax, 7
    xor ecx, ecx
    cpuid
    bt ebx, 5
    jc .tiene_avx2
    mov byte [avx2_ok], 0
    mov rdi, lbl_avx2
    call print_string
    mov rdi, msg_no
    call print_string
    jmp .fin

.tiene_avx2:
    mov byte [avx2_ok], 1
    mov rdi, lbl_avx2
    call print_string
    mov rdi, msg_si
    call print_string

    ; --- 2. Suma vectorizada: vec_res = vec_a + vec_b (8 floats) ---
    vmovaps ymm0, [vec_a]
    vmovaps ymm1, [vec_b]
    vaddps  ymm2, ymm0, ymm1
    vmovaps [vec_res], ymm2
    mov rdi, lbl_suma
    call print_string
    mov rdi, msg_ok8
    call print_string

    ; --- 3. Multiplicacion vectorizada: vec_a * vec_b ---
    vmulps  ymm3, ymm0, ymm1
    vmovaps [vec_res], ymm3
    mov rdi, lbl_mul
    call print_string
    mov rdi, msg_ok8
    call print_string

    ; --- 4. Comparacion vectorizada: vec_a >= vec_b (predicado 13) ---
    vcmpps  ymm4, ymm0, ymm1, 13
    vmovaps [vec_res], ymm4
    mov rdi, lbl_cmp
    call print_string
    mov rdi, msg_ok8
    call print_string

    ; --- 5. Throughput: 8 operaciones float en paralelo ---
    mov rdi, lbl_through
    call print_string
    mov rdi, 8
    call print_uint
    mov rdi, msg_through
    call print_string

    ; --- 6. Frecuencia del TSC (para convertir ciclos a segundos) ---
    call leer_tsc_m6
    mov r12, rax
    mov rax, 35                 ; nanosleep
    mov rdi, ts6_100ms
    mov rsi, ts6_rem
    syscall
    call leer_tsc_m6
    sub rax, r12                ; ciclos en 100 ms
    ; frecuencia_Hz = ciclos * 10
    mov r13, rax
    imul r13, 10                ; r13 = frecuencia en Hz

    ; --- 7. Benchmark GFLOPS ---
    ; Bucle: cada iteracion hace vaddps + vmulps sobre YMM = 2 ops
    ; vectoriales de 8 floats c/u = 16 FLOPs por iteracion.
    vmovaps ymm0, [vec_a]
    vmovaps ymm1, [vec_b]
    vmovaps ymm2, [vec_a]

    call leer_tsc_m6
    mov r14, rax                ; TSC inicial

    mov rcx, ITERS_FLOP
.bucle_flop:
    vaddps  ymm2, ymm2, ymm1    ; 8 FLOPs
    vmulps  ymm2, ymm2, ymm0    ; 8 FLOPs
    dec rcx
    jnz .bucle_flop

    call leer_tsc_m6
    sub rax, r14                ; ciclos del bucle
    mov r15, rax

    ; FLOPs totales = ITERS_FLOP * 16
    mov rax, ITERS_FLOP
    mov rcx, 16
    mul rcx
    mov r12, rax                ; r12 = FLOPs totales

    ; GFLOPS*100 = FLOPs * 100 * frecuencia / ciclos / 1e9
    ;           = FLOPs * frecuencia / ciclos / 1e7
    ; Para no desbordar: GFLOPS*100 = (FLOPs/ciclos aprox) ...
    ; Hacemos: tmp = FLOPs * frecuencia_Hz   (puede ser grande)
    ; GFLOPS*100 = tmp / ciclos / 10,000,000
    ; Reordenamos para precision: primero FLOPs*100, luego escalas.
    ;   seg = ciclos / frecuencia
    ;   GFLOPS = FLOPs / seg / 1e9 = FLOPs * frecuencia / ciclos / 1e9
    ;   GFLOPS*100 = FLOPs * frecuencia / ciclos / 1e7
    ; Calculo por pasos cuidando el rango de 64 bits:
    mov rax, r12                ; FLOPs
    xor rdx, rdx
    mov rcx, 100
    mul rcx                     ; RDX:RAX = FLOPs * 100
    div r15                     ; RAX = (FLOPs*100)/ciclos  = ops/ciclo *100
    ; ahora multiplicar por frecuencia y dividir por 1e9:
    ; GFLOPS*100 = (ops/ciclo*100) * frecuencia / 1e9
    xor rdx, rdx
    mul r13                     ; RDX:RAX = (ops/ciclo*100) * frecuencia_Hz
    mov rcx, 1000000000
    div rcx                     ; RAX = GFLOPS * 100

    mov rdi, lbl_gflops
    push rax
    call print_string
    pop rdi
    call print_fixed2
    mov rdi, msg_gflops
    call print_string

.fin:
    ; Limpiar estado AVX para evitar penalizacion de transicion
    ; AVX<->SSE en codigo posterior.
    vzeroupper

    mov rdi, msg_salto
    call print_string

    pop r15
    pop r14
    pop r13
    pop r12
    ret
