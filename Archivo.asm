section .data
    ; Constantes, strings, tablas de datos
    msg_procesador db "Procesador: ", 0
    msg_arquitectura db "Arquitectura: x86_64", 10, 0
    msg_extensiones db "Extensiones: ", 0
    
    ; Cadenas de las extensiones
    msg_sse db "SSE ", 0
    msg_sse2 db "SSE2 ", 0
    msg_avx db "AVX ", 0
    msg_avx2 db "AVX2 ", 0
    msg_avx512 db "AVX-512 ", 0
    
    msg_salto db 10, 0 ; Salto de línea
; --- Mensajes del Módulo 2 ---
    msg_mod2_titulo db "--- Módulo 2: Monitor de puertos E/S ---", 10, 0
    msg_p60 db "Puerto 60h (teclado): [OK]", 10, 0
    msg_p61 db "Puerto 61h (panel): [OK]", 10, 0
    msg_p3f8 db "Puerto 3F8h (COM1): [OK]", 10, 0
    msg_err_ioperm db "Error: Permisos denegados para E/S. Ejecute con sudo.", 10, 0
    
section .bss
    ; Variables reservadas (buffers, contadores)
    brand_string resb 49   
    
    ; Variables para guardar los flags de CPUID
    cpuid_1_ecx resd 1
    cpuid_1_edx resd 1
    cpuid_7_ebx resd 1

section .text
    global _start

_start:
    ; ==========================================================
    ; Módulo 1: Identificación del CPU
    ; ==========================================================
    
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

    ; --- 2. Extraer características base (SSE, SSE2, AVX) ---
    mov eax, 1
    cpuid
    mov dword [cpuid_1_ecx], ecx
    mov dword [cpuid_1_edx], edx

    ; --- 3. Extraer características extendidas (AVX2, AVX-512) ---
    mov eax, 7
    mov ecx, 0
    cpuid
    mov dword [cpuid_7_ebx], ebx

    ; ==========================================================
    ; Impresión de resultados en pantalla
    ; ==========================================================
    
    ; Imprimir Procesador
    mov rdi, msg_procesador
    call print_string
    mov rdi, brand_string
    call print_string
    mov rdi, msg_salto
    call print_string

    ; Imprimir Arquitectura
    mov rdi, msg_arquitectura
    call print_string

    ; Imprimir etiqueta de Extensiones
    mov rdi, msg_extensiones
    call print_string

    ; --- Evaluación e impresión de extensiones individuales ---
    
    ; Evaluar SSE (bit 25 de EDX en EAX=1)
    mov eax, dword [cpuid_1_edx]
    bt eax, 25              ; Bit Test: copia el bit 25 al Carry Flag (CF)
    jnc check_sse2          ; Jump if Not Carry: si es 0, salta al siguiente
    mov rdi, msg_sse
    call print_string

check_sse2:
    ; Evaluar SSE2 (bit 26 de EDX en EAX=1)
    mov eax, dword [cpuid_1_edx]
    bt eax, 26
    jnc check_avx
    mov rdi, msg_sse2
    call print_string

check_avx:
    ; Evaluar AVX (bit 28 de ECX en EAX=1)
    mov eax, dword [cpuid_1_ecx]
    bt eax, 28
    jnc check_avx2
    mov rdi, msg_avx
    call print_string

check_avx2:
    ; Evaluar AVX2 (bit 5 de EBX en EAX=7)
    mov eax, dword [cpuid_7_ebx]
    bt eax, 5
    jnc check_avx512
    mov rdi, msg_avx2
    call print_string

check_avx512:
    ; Evaluar AVX-512 (bit 16 de EBX en EAX=7)
    mov eax, dword [cpuid_7_ebx]
    bt eax, 16
    jnc end_extensions
    mov rdi, msg_avx512
    call print_string

end_extensions:
    ; Imprimir salto de línea final
    mov rdi, msg_salto
    call print_string

; ==========================================================
    ; Módulo 2: Monitor de puertos E/S
    ; ==========================================================
    
    ; Imprimir título del Módulo 2
    mov rdi, msg_mod2_titulo
    call print_string

    ; --- 1. Teclado (60h) y Panel de sistema (61h) ---
    ; Solicitar permisos E/S usando sys_ioperm
    mov rax, 173        ; syscall sys_ioperm
    mov rdi, 0x60       ; Puerto base 60h
    mov rsi, 2          ; 2 puertos (60h y 61h)
    mov rdx, 1          ; Habilitar (1)
    syscall

    ; Verificar estados y flags después de la operación (Manejo de errores requerido)
    cmp rax, 0
    jl error_permisos   ; Si rax < 0, hubo un error (falta de privilegios)

    ; Leer puerto 60h (Teclado) con ancho de 8 bits
    xor rax, rax
    in al, 0x60         
    mov rdi, msg_p60    ; Si no se bloqueó, la lectura fue exitosa
    call print_string

    ; Leer puerto 61h (Panel de sistema) con ancho de 8 bits
    xor rax, rax
    in al, 0x61
    mov rdi, msg_p61
    call print_string

    ; --- 2. Puerto Serial COM1 (3F8h) ---
    ; Solicitar permisos para el puerto 3F8h
    mov rax, 173
    mov rdi, 0x3F8
    mov rsi, 8          ; COM1 usa rango 3F8h-3FFh
    mov rdx, 1
    syscall

    cmp rax, 0
    jl error_permisos

    ; Leer puerto 3F8h con ancho de 8 bits
    xor rax, rax
    mov dx, 0x3F8       ; Direcciones > 255 deben cargarse en DX
    in al, dx
    mov rdi, msg_p3f8
    call print_string
    
    ; Imprimir salto de línea final del módulo
    mov rdi, msg_salto
    call print_string
    jmp fin_modulo2

error_permisos:
    ; Rutina de manejo de errores si sys_ioperm falla
    mov rdi, msg_err_ioperm
    call print_string
    mov rdi, msg_salto
    call print_string

fin_modulo2:
    ; (Aquí continuará el Módulo 3 posteriormente)

    ; ==========================================================
    ; Salida del programa
    ; ==========================================================
    mov rax, 60
    mov rdi, 0
    syscall

; ==========================================================
; Funciones auxiliares
; ==========================================================

strlen:
    xor rax, rax
.loop:
    cmp byte [rdi + rax], 0
    je .done
    inc rax
    jmp .loop
.done:
    ret

print_string:
    push rdi
    call strlen
    mov rdx, rax
    pop rsi
    mov rax, 1
    mov rdi, 1
    syscall
    ret
    
    
