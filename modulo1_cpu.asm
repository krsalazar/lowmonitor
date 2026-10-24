; ==========================================================
; modulo1_cpu.asm
; Modulo 1: Identificacion del CPU
;   - Extrae el nombre comercial (brand string) via CPUID
;     hojas 0x80000002..0x80000004.
;   - Detecta extensiones SSE, SSE2, AVX, AVX2 y AVX-512.
; Expone la rutina 'modulo1_cpu', llamada desde main.asm.
; Depende de print_string (utils.asm).
; ==========================================================

extern print_string

section .data
    msg_procesador    db "Procesador: ", 0
    msg_arquitectura  db "Arquitectura: x86_64", 10, 0
    msg_extensiones   db "Extensiones: ", 0

    ; Cadenas de las extensiones
    msg_sse     db "SSE ", 0
    msg_sse2    db "SSE2 ", 0
    msg_avx     db "AVX ", 0
    msg_avx2    db "AVX2 ", 0
    msg_avx512  db "AVX-512 ", 0

    msg_salto   db 10, 0          ; Salto de linea

section .bss
    brand_string  resb 49         ; 48 chars del brand string + NUL

    ; Variables para guardar los flags de CPUID
    cpuid_1_ecx   resd 1
    cpuid_1_edx   resd 1
    cpuid_7_ebx   resd 1

section .text
    global modulo1_cpu

modulo1_cpu:
    ; --- 1. Extraer nombre comercial del procesador ---
    mov eax, 0x80000002
    cpuid
    mov dword [brand_string], eax
    mov dword [brand_string + 4], ebx
    mov dword [brand_string + 8], ecx
    mov dword [brand_string + 12], edx

    mov eax, 0x80000003
    cpuid
    mov dword [brand_string + 16], eax
    mov dword [brand_string + 20], ebx
    mov dword [brand_string + 24], ecx
    mov dword [brand_string + 28], edx

    mov eax, 0x80000004
    cpuid
    mov dword [brand_string + 32], eax
    mov dword [brand_string + 36], ebx
    mov dword [brand_string + 40], ecx
    mov dword [brand_string + 44], edx
    mov byte [brand_string + 48], 0

    ; --- 2. Extraer caracteristicas base (SSE, SSE2, AVX) ---
    mov eax, 1
    cpuid
    mov dword [cpuid_1_ecx], ecx
    mov dword [cpuid_1_edx], edx

    ; --- 3. Extraer caracteristicas extendidas (AVX2, AVX-512) ---
    mov eax, 7
    mov ecx, 0
    cpuid
    mov dword [cpuid_7_ebx], ebx

    ; --- Impresion de resultados ---
    ; Procesador
    mov rdi, msg_procesador
    call print_string
    mov rdi, brand_string
    call print_string
    mov rdi, msg_salto
    call print_string

    ; Arquitectura
    mov rdi, msg_arquitectura
    call print_string

    ; Etiqueta de Extensiones
    mov rdi, msg_extensiones
    call print_string

    ; Evaluar SSE (bit 25 de EDX en EAX=1)
    mov eax, dword [cpuid_1_edx]
    bt eax, 25                  ; copia el bit 25 al Carry Flag (CF)
    jnc .check_sse2             ; si CF=0, no esta presente: saltar
    mov rdi, msg_sse
    call print_string

.check_sse2:
    ; Evaluar SSE2 (bit 26 de EDX en EAX=1)
    mov eax, dword [cpuid_1_edx]
    bt eax, 26
    jnc .check_avx
    mov rdi, msg_sse2
    call print_string

.check_avx:
    ; Evaluar AVX (bit 28 de ECX en EAX=1)
    mov eax, dword [cpuid_1_ecx]
    bt eax, 28
    jnc .check_avx2
    mov rdi, msg_avx
    call print_string

.check_avx2:
    ; Evaluar AVX2 (bit 5 de EBX en EAX=7)
    mov eax, dword [cpuid_7_ebx]
    bt eax, 5
    jnc .check_avx512
    mov rdi, msg_avx2
    call print_string

.check_avx512:
    ; Evaluar AVX-512F (bit 16 de EBX en EAX=7)
    mov eax, dword [cpuid_7_ebx]
    bt eax, 16
    jnc .fin
    mov rdi, msg_avx512
    call print_string

.fin:
    ; Salto de linea final del modulo
    mov rdi, msg_salto
    call print_string
    ret
