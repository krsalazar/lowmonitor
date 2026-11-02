; ==========================================================
; modulo2_ioports.asm
; Modulo 2: Monitor de puertos E/S
;   Lee puertos estandar del sistema (teclado 60h, panel 61h,
;   serial COM1 3F8h) y demuestra las instrucciones IN/OUT en
;   los tres anchos (8, 16 y 32 bits).
; Expone la rutina 'modulo2_ioports', llamada desde main.asm.
; Depende de print_string y print_uint (utils.asm).
;
; Ejecucion como usuario regular (sin root):
;   1. Se pide acceso con ioperm. Solo se concede si el proceso
;      tiene CAP_SYS_RAWIO (root o binario con setcap).
;   2. Se instala un manejador de SIGSEGV con rt_sigaction.
;   3. Las instrucciones IN/OUT se ejecutan SIEMPRE. Si el proceso
;      no tiene permiso, el CPU las bloquea con una excepcion de
;      proteccion general (#GP, vector 13) y el kernel la entrega
;      como SIGSEGV. El manejador anota el vector, marca la
;      operacion como fallida y mueve RIP (en el ucontext) a una
;      direccion de recuperacion para continuar con la siguiente.
;   4. Al terminar se restaura el manejador por defecto, para que
;      un fallo real en otro modulo termine el proceso como siempre.
;
; Direccionamiento: todas las operaciones usan DX como puerto,
; la forma general que cubre el espacio completo 0-65535.
;
; Verificacion de estado despues de cada operacion:
;   - Excepcion capturada        -> [DENEGADO] + vector del CPU
;   - IN con valor != 0xFF       -> [OK]  (el puerto respondio)
;   - IN con valor == 0xFF       -> [--]  (bus flotante, sin respuesta)
;   - OUT sin excepcion          -> [OK]
;
; Seguridad: la escritura (OUT) se hace sobre el puerto de
; diagnostico POST 0x80, de uso tradicional como "basurero" de
; E/S en Linux; no controla hardware critico.
; ==========================================================

extern print_string
extern print_uint

; --- Syscalls y constantes del kernel (x86-64) ---
%define SYS_RT_SIGACTION  13
%define SYS_RT_SIGRETURN  15
%define SYS_IOPERM        173
%define SIGSEGV           11
%define SA_SIGINFO        0x00000004
%define SA_RESTORER       0x04000000

; Offsets dentro de ucontext_t (x86-64):
;   uc_flags(8) + uc_link(8) + uc_stack(24) = 40 -> inicio de gregs
;   gregs[REG_RIP=16]    -> 40 + 16*8 = 168
;   gregs[REG_TRAPNO=20] -> 40 + 20*8 = 200
%define UC_RIP            168
%define UC_TRAPNO         200

; ----------------------------------------------------------
; IO_PROTEGIDA instruccion
;   Ejecuta una instruccion IN/OUT con recuperacion ante #GP.
;   Limpia la bandera de fallo, registra la direccion a la que el
;   manejador debe saltar si la instruccion falla, ejecuta la
;   instruccion y desarma la recuperacion.
;   Usa R11 (no hay syscall entre su carga y su uso).
; ----------------------------------------------------------
%macro IO_PROTEGIDA 1+
    mov byte [fault_flag], 0
    lea r11, [rel %%despues]
    mov [recover_rip], r11
    %1
%%despues:
    mov qword [recover_rip], 0
%endmacro

section .data
    msg_mod2_titulo  db "--- Modulo 2: Monitor de puertos E/S ---", 10, 0

    msg_modo_priv    db "Modo: privilegiado (ioperm concedido, acceso real a puertos)", 10, 0
    msg_modo_user_a  db "Modo: usuario regular (ioperm denegado, errno ", 0
    msg_modo_user_b  db ")", 10
                     db "  IN/OUT se ejecutan igual; si el CPU los bloquea, la excepcion", 10
                     db "  se captura y se reporta (vector 13 = #GP, proteccion general).", 10, 0
    msg_sin_manej    db "No se pudo instalar el manejador de SIGSEGV; se omiten las pruebas.", 10, 0

    ; Etiquetas de puerto (el estado se anexa aparte)
    lbl_p60          db "Puerto 60h (teclado): ", 0
    lbl_p61          db "Puerto 61h (panel):   ", 0
    lbl_p3f8         db "Puerto 3F8h (COM1):   ", 0

    msg_anchos_hdr   db "Anchos de E/S demostrados (direccionamiento por DX):", 10, 0
    lbl_in8          db "  IN  8  bits (in al, dx)  puerto 60h  ", 0
    lbl_in16         db "  IN  16 bits (in ax, dx)  puerto 3F8h ", 0
    lbl_in32         db "  IN  32 bits (in eax, dx) puerto 3F8h ", 0
    lbl_out8         db "  OUT 8  bits (out dx, al)  puerto 80h ", 0
    lbl_out16        db "  OUT 16 bits (out dx, ax)  puerto 80h ", 0
    lbl_out32        db "  OUT 32 bits (out dx, eax) puerto 80h ", 0

    ; Estados posibles
    estado_ok        db "[OK]", 10, 0
    estado_sin_resp  db "[--]", 10, 0
    estado_deneg_a   db "[DENEGADO] excepcion vector ", 0
    estado_deneg_b   db 10, 0

    msg_salto_m2     db 10, 0

    ; struct kernel_sigaction para rt_sigaction:
    ;   sa_handler(8), sa_flags(8), sa_restorer(8), sa_mask(8)
    sa_segv:
        dq segv_handler
        dq SA_SIGINFO | SA_RESTORER
        dq sigreturn_restorer
        dq 0
    sa_default:
        dq 0                        ; SIG_DFL
        dq SA_RESTORER
        dq sigreturn_restorer
        dq 0

section .bss
    recover_rip   resq 1    ; destino de recuperacion (0 = desarmado)
    fault_flag    resb 1    ; 1 si la ultima operacion fallo
    modo_priv     resb 1    ; 1 si ioperm fue concedido
    trapno        resq 1    ; vector de la ultima excepcion capturada
    errno_ioperm  resq 1    ; errno devuelto por ioperm

section .text
    global modulo2_ioports

; ----------------------------------------------------------
; segv_handler (SA_SIGINFO): RDI=signo, RSI=siginfo*, RDX=ucontext*
;   Si hay una operacion de E/S armada, guarda el vector de la
;   excepcion, marca el fallo y redirige RIP a la recuperacion.
;   Si no hay ninguna armada, el fallo no es de este modulo:
;   restaura SIG_DFL y retorna, de modo que la instruccion vuelve
;   a fallar y el proceso termina con SIGSEGV como de costumbre.
; ----------------------------------------------------------
segv_handler:
    mov rax, [recover_rip]
    test rax, rax
    jz .no_armado
    mov [rdx + UC_RIP], rax         ; continuar tras la instruccion
    mov rcx, [rdx + UC_TRAPNO]
    mov [trapno], rcx               ; vector reportado por el CPU
    mov byte [fault_flag], 1
    mov qword [recover_rip], 0      ; desarmar
    ret                             ; vuelve a sigreturn_restorer
.no_armado:
    call restaurar_sigsegv
    ret

; Restaurador obligatorio en x86-64 (SA_RESTORER): al retornar el
; manejador, el kernel restaura el contexto con rt_sigreturn.
sigreturn_restorer:
    mov rax, SYS_RT_SIGRETURN
    syscall

; Restaura la accion por defecto de SIGSEGV.
restaurar_sigsegv:
    mov rax, SYS_RT_SIGACTION
    mov rdi, SIGSEGV
    mov rsi, sa_default
    xor rdx, rdx
    mov r10, 8                      ; sizeof(sigset_t) del kernel
    syscall
    ret

; ----------------------------------------------------------
; print_estado_lectura
;   Imprime [OK] si el valor leido != 0xFF, o [--] si == 0xFF.
;   Entrada: AL = byte menos significativo del valor leido.
; ----------------------------------------------------------
print_estado_lectura:
    cmp al, 0xFF
    je .sin_resp
    mov rdi, estado_ok
    call print_string
    ret
.sin_resp:
    mov rdi, estado_sin_resp
    call print_string
    ret

; ----------------------------------------------------------
; reportar_in: estado tras un IN protegido (AL = valor leido).
; reportar_out: estado tras un OUT protegido.
; ----------------------------------------------------------
reportar_in:
    cmp byte [fault_flag], 0
    jne reportar_denegado
    jmp print_estado_lectura

reportar_out:
    cmp byte [fault_flag], 0
    jne reportar_denegado
    mov rdi, estado_ok
    jmp print_string

reportar_denegado:
    mov rdi, estado_deneg_a
    call print_string
    mov rdi, [trapno]
    call print_uint
    mov rdi, estado_deneg_b
    jmp print_string

modulo2_ioports:
    mov rdi, msg_mod2_titulo
    call print_string

    ; --- 1. Solicitar permisos para 0x000..0x3FF ---
    mov rax, SYS_IOPERM
    xor rdi, rdi                    ; puerto base 0
    mov rsi, 0x400                  ; 1024 puertos
    mov rdx, 1                      ; habilitar
    syscall
    test rax, rax
    js .sin_permiso

    mov byte [modo_priv], 1
    mov rdi, msg_modo_priv
    call print_string
    jmp .instalar

.sin_permiso:
    ; Sin CAP_SYS_RAWIO: no se aborta, se sigue en modo usuario.
    mov byte [modo_priv], 0
    neg rax                         ; -errno -> errno
    mov [errno_ioperm], rax
    mov rdi, msg_modo_user_a
    call print_string
    mov rdi, [errno_ioperm]
    call print_uint
    mov rdi, msg_modo_user_b
    call print_string

.instalar:
    ; --- 2. Instalar el manejador de SIGSEGV ---
    mov rax, SYS_RT_SIGACTION
    mov rdi, SIGSEGV
    mov rsi, sa_segv
    xor rdx, rdx                    ; no se necesita la accion previa
    mov r10, 8
    syscall
    test rax, rax
    js .sin_manejador

    ; --- 3. Lecturas de los puertos del enunciado (8 bits) ---
    mov rdi, lbl_p60
    call print_string
    xor eax, eax
    mov dx, 0x60
    IO_PROTEGIDA in al, dx
    call reportar_in

    mov rdi, lbl_p61
    call print_string
    xor eax, eax
    mov dx, 0x61
    IO_PROTEGIDA in al, dx
    call reportar_in

    mov rdi, lbl_p3f8
    call print_string
    xor eax, eax
    mov dx, 0x3F8
    IO_PROTEGIDA in al, dx
    call reportar_in

    ; --- 4. Los tres anchos de IN y OUT ---
    mov rdi, msg_anchos_hdr
    call print_string

    mov rdi, lbl_in8
    call print_string
    xor eax, eax
    mov dx, 0x60
    IO_PROTEGIDA in al, dx
    call reportar_in

    ; IN 16 bits (3F8h-3F9h); se verifica el byte bajo (AL)
    mov rdi, lbl_in16
    call print_string
    xor eax, eax
    mov dx, 0x3F8
    IO_PROTEGIDA in ax, dx
    call reportar_in

    ; IN 32 bits (3F8h-3FBh); se verifica el byte bajo (AL)
    mov rdi, lbl_in32
    call print_string
    xor eax, eax
    mov dx, 0x3F8
    IO_PROTEGIDA in eax, dx
    call reportar_in

    mov rdi, lbl_out8
    call print_string
    xor eax, eax
    mov dx, 0x80
    IO_PROTEGIDA out dx, al
    call reportar_out

    mov rdi, lbl_out16
    call print_string
    xor eax, eax
    mov dx, 0x80
    IO_PROTEGIDA out dx, ax
    call reportar_out

    mov rdi, lbl_out32
    call print_string
    xor eax, eax
    mov dx, 0x80
    IO_PROTEGIDA out dx, eax
    call reportar_out

    ; --- 5. Limpieza: manejador por defecto y liberar permisos ---
    call restaurar_sigsegv

    cmp byte [modo_priv], 1
    jne .fin
    mov rax, SYS_IOPERM
    xor rdi, rdi
    mov rsi, 0x400
    xor rdx, rdx                    ; deshabilitar (minimo privilegio)
    syscall
    jmp .fin

.sin_manejador:
    mov rdi, msg_sin_manej
    call print_string

.fin:
    mov rdi, msg_salto_m2
    call print_string
    ret
