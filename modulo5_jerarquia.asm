; ==========================================================
; modulo5_jerarquia.asm
; Modulo 5: Gestion jerarquica de memoria
;   Mide la latencia de acceso (en ciclos) de cada nivel de la
;   jerarquia de memoria: registros, L1, L2, L3 y RAM principal.
;
; Expone la rutina 'modulo5_jerarquia', llamada desde main.asm.
; Depende de print_string y print_fixed2 (utils.asm).
;
; Metodo (pointer chasing):
;   Para medir un nivel se recorre una cadena de punteros alojada
;   en un buffer de tamano = al de ese nivel. Cada posicion guarda
;   la DIRECCION de la siguiente a visitar, con un paso (stride) de
;   64 bytes (una linea de cache) para tocar lineas distintas y
;   dejar inutil al prefetcher secuencial. Como cada acceso depende
;   del valor leido en el anterior, el CPU no puede paralelizarlos
;   ni adelantarlos: el tiempo medido es la latencia real del nivel
;   donde reside el buffer.
;
;   latencia_ciclos = (TSC_fin - TSC_ini) / numero_de_accesos
;   El TSC se serializa con CPUID antes de leerlo.
;
; Tamanos (segun lscpu de la maquina objetivo, Skylake):
;   L1d = 32 KB  -> buffer 16 KB  (cabe holgado en L1)
;   L2  = 4 MB   -> buffer 256 KB (excede L1, cabe en L2)
;   L3  = 16 MB  -> buffer 8 MB   (excede L2, cabe en L3)
;   RAM          -> buffer 64 MB  (excede L3, va a RAM)
;
; Nota: los resultados son aproximados y dependen de la carga y de
; la virtualizacion; el objetivo es mostrar la PROGRESION de
; latencias (registros < L1 < L2 < L3 < RAM).
; ==========================================================

extern print_string
extern print_fixed2

%define STRIDE   64                ; tamano de linea de cache (bytes)
%define ACCESOS  1000000           ; accesos por medicion

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
;   Prepara una cadena ciclica de punteros en buffer_mem. Cada nodo
;   (en pasos de STRIDE) apunta al siguiente; el ultimo al primero.
;   Entrada: RDI = tamano del buffer (bytes)
; ----------------------------------------------------------
construir_cadena:
    mov rcx, rdi
    shr rcx, 6              ; nodos = tamano / 64
    mov rsi, buffer_mem     ; nodo fisico actual
    mov r9, buffer_mem      ; base
    mov rdx, 1              ; indice del siguiente nodo
.loop:
    cmp rdx, rcx
    jb .no_wrap
    xor rdx, rdx            ; cerrar el ciclo hacia el nodo 0
.no_wrap:
    mov r8, rdx
    shl r8, 6               ; indice * 64
    add r8, r9              ; base + offset
    mov [rsi], r8           ; actual -> siguiente
    add rsi, STRIDE
    inc rdx
    dec rcx
    jnz .loop
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
