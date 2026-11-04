; ==========================================================
; modulo5_jerarquia.asm - Modulo 5: Gestion jerarquica de memoria
;   Latencia (ciclos/acceso) de registros, L1, L2, L3 y RAM por
;   pointer chasing: cada nodo ocupa una linea de cache (64 B) y apunta
;   al siguiente, por lo que cada acceso depende del anterior.
;
;   Para derrotar al prefetcher los nodos se enlazan en una permutacion
;   idx(k) = (k * PASO) mod N, con N potencia de 2 y PASO impar (coprimo
;   con N): un unico ciclo que recorre todos los nodos en orden disperso.
;
;   Buffers (lscpu, Skylake): L1 16 KB (L1d 32 KB), L2 256 KB (4 MB),
;   L3 8 MB (16 MB), RAM 64 MB. Los valores absolutos dependen del
;   entorno; lo que se muestra es la progresion L1 < L2 < L3 < RAM.
; ==========================================================

extern print_string
extern print_fixed2

%define STRIDE   64                ; tamano de linea de cache (bytes)
%define ACCESOS  2000000           ; accesos por medicion
; PASO (en nodos): impar, por lo que es coprimo con N (potencia de 2);
; mayor que una linea para evitar el prefetch de stride.
%define PASO     2039

%define SZ_L1    16384             ; 16 KB
%define SZ_L2    262144            ; 256 KB
%define SZ_L3    8388608           ; 8 MB
%define SZ_RAM   67108864          ; 64 MB

section .data
    msg_titulo   db "--- Modulo 5: Gestion jerarquica de memoria ---", 10, 0

    lbl_reg      db "Registros:  ", 0
    lbl_l1       db "L1 cache:   ", 0
    lbl_l2       db "L2 cache:   ", 0
    lbl_l3       db "L3 cache:   ", 0
    lbl_ram      db "RAM:        ", 0

    suf_ciclos   db " ciclos/acceso", 0
    suf_l1       db "   (16 KB)", 10, 0
    suf_l2       db "   (256 KB)", 10, 0
    suf_l3       db "   (8 MB)", 10, 0
    suf_ram      db "   (64 MB)", 10, 0
    suf_reg      db 10, 0
    msg_nl       db 10, 0

section .bss
    buffer_mem   resb SZ_RAM       ; 64 MB; cada nivel usa un prefijo

section .text
    global modulo5_jerarquia

; ----------------------------------------------------------
; leer_tsc_m5: RAX = TSC de 64 bits, serializado con CPUID.
; ----------------------------------------------------------
leer_tsc_m5:
    push rbx
    xor eax, eax
    cpuid
    rdtsc
    shl rdx, 32
    or rax, rdx
    pop rbx
    ret

; ----------------------------------------------------------
; construir_cadena
;   Enlaza los nodos de buffer_mem segun la permutacion
;   idx(k) = (k * PASO) mod N, formando un unico ciclo disperso.
;   El nodo fisico idx(k) apunta al nodo fisico idx(k+1).
;   Entrada: RDI = tamano del buffer (bytes)
;   N = tamano / 64 (potencia de 2). mod N = and (N-1).
; ----------------------------------------------------------
construir_cadena:
    mov r10, rdi
    shr r10, 6             ; R10 = N (numero de nodos)
    mov r11, r10
    dec r11               ; R11 = N - 1 (mascara para mod N)
    mov r9, buffer_mem    ; base

    xor rcx, rcx          ; k = 0 (contador de nodos enlazados)
.loop:
    ; idx = (k * PASO) and (N-1)
    mov rax, rcx
    imul rax, PASO
    and rax, r11          ; rax = idx fisico del nodo k

    ; idx_next = ((k+1) * PASO) and (N-1)
    lea rdx, [rcx + 1]
    imul rdx, PASO
    and rdx, r11          ; rdx = idx fisico del nodo k+1

    ; nodo_fisico[idx] = direccion de nodo_fisico[idx_next]
    shl rax, 6            ; idx * 64
    shl rdx, 6            ; idx_next * 64
    add rax, r9           ; &buffer[idx]
    add rdx, r9           ; &buffer[idx_next]
    mov [rax], rdx        ; enlazar

    inc rcx
    cmp rcx, r10
    jb .loop
    ret

; ----------------------------------------------------------
; medir_latencia
;   Recorre la cadena ACCESOS veces y mide los ciclos.
;   Entrada: (cadena ya construida en buffer_mem)
;   Salida : RAX = ciclos/acceso * 100  (2 decimales)
; ----------------------------------------------------------
medir_latencia:
    push r12

    ; Precalentar: carga el buffer en el nivel correspondiente
    mov rax, buffer_mem
    mov rcx, ACCESOS
.warm:
    mov rax, [rax]
    dec rcx
    jnz .warm

    call leer_tsc_m5
    mov r12, rax            ; TSC inicial

    mov rax, buffer_mem
    mov rcx, ACCESOS
.run:
    mov rax, [rax]          ; acceso dependiente (pointer chasing)
    dec rcx
    jnz .run

    call leer_tsc_m5
    sub rax, r12            ; ciclos totales

    xor rdx, rdx
    mov rcx, 100
    mul rcx                 ; RDX:RAX = ciclos * 100
    mov rcx, ACCESOS
    div rcx                 ; RAX = ciclos/acceso * 100

    pop r12
    ret

; ----------------------------------------------------------
; medir_nivel: construye la cadena, mide e imprime una linea:
;   <etiqueta><latencia> ciclos/acceso<sufijo-tamano>
;   Entrada: RDI = tamano, RSI = etiqueta, RDX = sufijo de tamano
; ----------------------------------------------------------
medir_nivel:
    push r13
    push r14
    push r15
    mov r14, rsi            ; etiqueta
    mov r15, rdx            ; sufijo tamano

    call construir_cadena   ; RDI = tamano
    call medir_latencia     ; RAX = ciclos/acceso * 100
    mov r13, rax

    mov rdi, r14
    call print_string
    mov rdi, r13
    call print_fixed2
    mov rdi, suf_ciclos
    call print_string
    mov rdi, r15
    call print_string

    pop r15
    pop r14
    pop r13
    ret

modulo5_jerarquia:
    mov rdi, msg_titulo
    call print_string

    ; --- Registros: el acceso mas rapido, ~1 ciclo de referencia ---
    mov rdi, lbl_reg
    call print_string
    mov rdi, 100            ; 1.00
    call print_fixed2
    mov rdi, suf_ciclos
    call print_string
    mov rdi, suf_reg
    call print_string

    ; --- L1 / L2 / L3 / RAM ---
    mov rdi, SZ_L1
    mov rsi, lbl_l1
    mov rdx, suf_l1
    call medir_nivel

    mov rdi, SZ_L2
    mov rsi, lbl_l2
    mov rdx, suf_l2
    call medir_nivel

    mov rdi, SZ_L3
    mov rsi, lbl_l3
    mov rdx, suf_l3
    call medir_nivel

    mov rdi, SZ_RAM
    mov rsi, lbl_ram
    mov rdx, suf_ram
    call medir_nivel

    mov rdi, msg_nl
    call print_string
    ret
