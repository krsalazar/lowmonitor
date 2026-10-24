; ==========================================================
; modulo2_ioports.asm
; Modulo 2: Monitor de puertos E/S
;   Lee puertos estandar del sistema (teclado 60h, panel 61h,
;   serial COM1 3F8h) usando IN tras solicitar acceso con el
;   syscall ioperm.
; Expone la rutina 'modulo2_ioports', llamada desde main.asm.
; Depende de print_string (utils.asm).
;
; NOTA: la logica es la original; las correcciones de permisos,
; anchos 8/16/32 con OUT y verificacion real de estado se
; aplican en tareas posteriores.
; ==========================================================

extern print_string

section .data
    msg_mod2_titulo  db "--- Modulo 2: Monitor de puertos E/S ---", 10, 0
    msg_p60          db "Puerto 60h (teclado): [OK]", 10, 0
    msg_p61          db "Puerto 61h (panel): [OK]", 10, 0
    msg_p3f8         db "Puerto 3F8h (COM1): [OK]", 10, 0

    ; Mensaje informativo (no es un fallo del programa): el acceso
    ; directo a puertos de E/S de hardware requiere privilegios por
    ; diseno del kernel de Linux. El modulo continua sin abortar.
    msg_sin_privs1   db "Acceso a puertos E/S no disponible: requiere privilegios.", 10, 0
    msg_sin_privs2   db "  El kernel de Linux restringe IN/OUT a procesos privilegiados.", 10, 0
    msg_sin_privs3   db "  Para probar este modulo, ejecute: sudo ./lowmonitor", 10, 0

    msg_salto_m2     db 10, 0

section .text
    global modulo2_ioports

modulo2_ioports:
    ; Titulo del modulo
    mov rdi, msg_mod2_titulo
    call print_string

    ; --- 1. Teclado (60h) y Panel de sistema (61h) ---
    ; Solicitar permisos E/S con sys_ioperm
    mov rax, 173        ; syscall sys_ioperm
    mov rdi, 0x60       ; puerto base 60h
    mov rsi, 2          ; 2 puertos (60h y 61h)
    mov rdx, 1          ; habilitar
    syscall

    cmp rax, 0
    jl .error_permisos  ; rax < 0 => error (falta de privilegios)

    ; Leer puerto 60h (teclado), ancho 8 bits
    xor rax, rax
    in al, 0x60
    mov rdi, msg_p60
    call print_string

    ; Leer puerto 61h (panel), ancho 8 bits
    xor rax, rax
    in al, 0x61
    mov rdi, msg_p61
    call print_string

    ; --- 2. Puerto Serial COM1 (3F8h) ---
    mov rax, 173
    mov rdi, 0x3F8
    mov rsi, 8          ; COM1 usa rango 3F8h-3FFh
    mov rdx, 1
    syscall

    cmp rax, 0
    jl .error_permisos

    ; Leer puerto 3F8h, ancho 8 bits
    xor rax, rax
    mov dx, 0x3F8       ; direcciones > 255 van en DX
    in al, dx
    mov rdi, msg_p3f8
    call print_string

    mov rdi, msg_salto_m2
    call print_string
    jmp .fin

.error_permisos:
    ; Condicion esperada cuando se corre sin privilegios.
    ; Se informa con claridad y el modulo retorna limpio para que
    ; el resto del programa (modulos 3, 4, 5...) siga ejecutandose.
    mov rdi, msg_sin_privs1
    call print_string
    mov rdi, msg_sin_privs2
    call print_string
    mov rdi, msg_sin_privs3
    call print_string
    mov rdi, msg_salto_m2
    call print_string

.fin:
    ret
