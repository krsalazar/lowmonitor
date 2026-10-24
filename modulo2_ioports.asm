; ==========================================================
; modulo2_ioports.asm
; Modulo 2: Monitor de puertos E/S
;   Lee puertos estandar del sistema (teclado 60h, panel 61h,
;   serial COM1 3F8h) y demuestra las instrucciones IN/OUT en
;   los tres anchos (8, 16 y 32 bits), tras solicitar acceso
;   con el syscall ioperm.
; Expone la rutina 'modulo2_ioports', llamada desde main.asm.
; Depende de print_string (utils.asm).
;
; Direccionamiento: los puertos < 256 pueden usar inmediato
; (in al, 0x60); para cubrir todo el espacio 0-65535 se usa
; el registro DX, que es la forma general en x86-64.
;
; Seguridad: la escritura (OUT) se realiza sobre el puerto de
; diagnostico POST 0x80, de uso tradicional como "basurero" de
; E/S en Linux; no controla hardware critico. Las lecturas (IN)
; se hacen sobre puertos de consulta (teclado/estado y COM1).
; ==========================================================

extern print_string

section .data
    msg_mod2_titulo  db "--- Modulo 2: Monitor de puertos E/S ---", 10, 0

    msg_p60          db "Puerto 60h (teclado): [OK]", 10, 0
    msg_p61          db "Puerto 61h (panel): [OK]", 10, 0
    msg_p3f8         db "Puerto 3F8h (COM1): [OK]", 10, 0

    ; Demostracion de anchos IN/OUT
    msg_anchos_hdr   db "Anchos de E/S demostrados (direccionamiento por DX):", 10, 0
    msg_in8          db "  IN  8  bits (in al, dx)  puerto 60h  [OK]", 10, 0
    msg_in16         db "  IN  16 bits (in ax, dx)  puerto 3F8h [OK]", 10, 0
    msg_in32         db "  IN  32 bits (in eax, dx) puerto 3F8h [OK]", 10, 0
    msg_out8         db "  OUT 8  bits (out dx, al)  puerto 80h [OK]", 10, 0
    msg_out16        db "  OUT 16 bits (out dx, ax)  puerto 80h [OK]", 10, 0
    msg_out32        db "  OUT 32 bits (out dx, eax) puerto 80h [OK]", 10, 0

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

    ; --- 1. Permisos para el rango de puertos usados ---
    ; Habilitamos de golpe 0x00..0x3FF (1024 puertos) para cubrir
    ; teclado (60h/61h/64h), diagnostico POST (80h) y COM1 (3F8h).
    mov rax, 173        ; syscall sys_ioperm
    mov rdi, 0          ; puerto base 0
    mov rsi, 0x400      ; 1024 puertos (0x000..0x3FF)
    mov rdx, 1          ; habilitar
    syscall

    cmp rax, 0
    jl .error_permisos  ; rax < 0 => error (falta de privilegios)

    ; --- 2. Lecturas originales (teclado, panel, COM1) 8 bits ---
    xor rax, rax
    mov dx, 0x60
    in al, dx           ; teclado, 8 bits
    mov rdi, msg_p60
    call print_string

    xor rax, rax
    mov dx, 0x61
    in al, dx           ; panel de sistema, 8 bits
    mov rdi, msg_p61
    call print_string

    xor rax, rax
    mov dx, 0x3F8
    in al, dx           ; COM1, 8 bits (direccion > 255 via DX)
    mov rdi, msg_p3f8
    call print_string

    ; --- 3. Demostracion de los tres anchos de IN y OUT ---
    mov rdi, msg_anchos_hdr
    call print_string

    ; IN 8 bits
    xor rax, rax
    mov dx, 0x60
    in al, dx
    mov rdi, msg_in8
    call print_string

    ; IN 16 bits (lee 3F8h y 3F9h)
    xor rax, rax
    mov dx, 0x3F8
    in ax, dx
    mov rdi, msg_in16
    call print_string

    ; IN 32 bits (lee 3F8h..3FBh)
    xor rax, rax
    mov dx, 0x3F8
    in eax, dx
    mov rdi, msg_in32
    call print_string

    ; OUT 8 bits al puerto de diagnostico POST (0x80)
    mov dx, 0x80
    mov al, 0x00
    out dx, al
    mov rdi, msg_out8
    call print_string

    ; OUT 16 bits
    mov dx, 0x80
    mov ax, 0x0000
    out dx, ax
    mov rdi, msg_out16
    call print_string

    ; OUT 32 bits
    mov dx, 0x80
    mov eax, 0x00000000
    out dx, eax
    mov rdi, msg_out32
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
