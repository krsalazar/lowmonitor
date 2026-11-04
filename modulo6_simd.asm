; ==========================================================
; modulo6_simd.asm - Modulo 6: Operaciones SIMD (bonus)
;   Operaciones AVX2 sobre registros YMM (8 floats de 32 bits):
;   vaddps, vmulps y vcmpps. AVX2 se detecta con CPUID hoja 7 (EBX bit 5).
;   Estima GFLOPS = FLOPs * freq / ciclos / 1e9 con RDTSC, usando la
;   frecuencia del TSC medida con nanosleep (como en el Modulo 4).
;
;   En una VM el hipervisor puede ejecutar AVX muy por debajo de la
;   velocidad nativa (~464 ciclos por grupo de 8 operaciones YMM
;   medidos), por lo que el GFLOPS refleja el entorno, no el hardware.
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
    nota_vm      db "  (nota: en VM el AVX no corre a velocidad nativa;", 10
                 db "   en hardware fisico se esperan decenas de GFLOPS)", 10, 0

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
    ; 8 destinos YMM independientes (ymm2..ymm9), sin cadena de
    ; dependencias, para saturar las unidades FP: 8 instrucciones x
    ; 8 floats = 64 FLOPs por iteracion.
    vmovaps ymm0, [vec_a]
    vmovaps ymm1, [vec_b]
    vmovaps ymm2, [vec_a]
    vmovaps ymm3, [vec_b]
    vmovaps ymm4, [vec_a]
    vmovaps ymm5, [vec_b]
    vmovaps ymm6, [vec_a]
    vmovaps ymm7, [vec_b]
    vmovaps ymm8, [vec_a]
    vmovaps ymm9, [vec_b]

    call leer_tsc_m6
    mov r14, rax                ; TSC inicial

    ; Entradas fijas (ymm0, ymm1) y destinos distintos: los valores no
    ; se realimentan, por lo que no divergen a Inf/NaN.
    mov rcx, ITERS_FLOP
.bucle_flop:
    vaddps  ymm2, ymm0, ymm1
    vaddps  ymm3, ymm0, ymm1
    vaddps  ymm4, ymm0, ymm1
    vaddps  ymm5, ymm0, ymm1
    vmulps  ymm6, ymm0, ymm1
    vmulps  ymm7, ymm0, ymm1
    vmulps  ymm8, ymm0, ymm1
    vmulps  ymm9, ymm0, ymm1
    dec rcx
    jnz .bucle_flop

    call leer_tsc_m6
    sub rax, r14                ; ciclos del bucle
    mov r15, rax

    ; FLOPs totales = ITERS_FLOP * 64
    ; (8 instrucciones YMM por iteracion * 8 floats = 64 FLOPs)
    mov rax, ITERS_FLOP
    mov rcx, 64
    mul rcx
    mov r12, rax                ; r12 = FLOPs totales

    ; GFLOPS*100 = FLOPs * (freq/1e7) / ciclos, con freq/1e7 = GHz*100.
    ; Se multiplica antes de dividir para no perder precision.
    mov rax, r13                ; freq_Hz
    xor rdx, rdx
    mov rcx, 10000000           ; 1e7
    div rcx                     ; RAX = freq / 1e7  (= GHz*100)
    mov rcx, rax                ; rcx = factor (GHz*100)

    mov rax, r12                ; FLOPs totales
    mul rcx                     ; RDX:RAX = FLOPs * factor
    div r15                     ; RAX = GFLOPS * 100

    mov rdi, lbl_gflops
    push rax
    call print_string
    pop rdi
    call print_fixed2
    mov rdi, msg_gflops
    call print_string
    mov rdi, nota_vm
    call print_string

.fin:
    ; Evita la penalizacion de transicion AVX<->SSE
    vzeroupper

    mov rdi, msg_salto
    call print_string

    pop r15
    pop r14
    pop r13
    pop r12
    ret
