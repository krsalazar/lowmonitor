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
; Verificacion de estado (requisito "verificar estados y flags
; despues de cada operacion"): tras cada lectura IN se evalua el
; valor devuelto. En el bus de E/S x86, un puerto sin respuesta
; deja las lineas flotando y se lee 0xFF; por eso se interpreta:
;   valor != 0xFF  -> el puerto respondio            -> [OK]
;   valor == 0xFF  -> sin respuesta (bus flotante)   -> [--]
; Para OUT no hay dato de retorno; su validez queda garantizada
; por el permiso concedido por ioperm (ya verificado arriba).
;
; Seguridad: la escritura (OUT) se realiza sobre el puerto de
; diagnostico POST 0x80, de uso tradicional como "basurero" de
; E/S en Linux; no controla hardware critico.
; ==========================================================

extern print_string

section .data
    msg_mod2_titulo  db "--- Modulo 2: Monitor de puertos E/S ---", 10, 0

    ; Etiquetas de puerto (sin el estado; el estado se anexa aparte)
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

    ; Estados posibles (incluyen salto de linea)
    estado_ok        db "[OK]", 10, 0      ; puerto respondio / OUT valido
    estado_sin_resp  db "[--]", 10, 0      ; lectura 0xFF: sin respuesta

    ; Mensaje informativo (no es un fallo del programa): el acceso
    ; directo a puertos de E/S de hardware requiere privilegios por
    ; diseno del kernel de Linux. El modulo continua sin abortar.
    msg_sin_privs1   db "Acceso a puertos E/S no disponible: requiere privilegios.", 10, 0
    msg_sin_privs2   db "  El kernel de Linux restringe IN/OUT a procesos privilegiados.", 10, 0
    msg_sin_privs3   db "  Para probar este modulo, ejecute: sudo ./lowmonitor", 10, 0

    msg_salto_m2     db 10, 0

section .text
    global modulo2_ioports

; ----------------------------------------------------------
; print_estado_lectura
;   Imprime [OK] si el valor leido != 0xFF, o [--] si == 0xFF.
;   Entrada: AL = byte menos significativo del valor leido.
;   Altera : RDI, y lo que altere print_string.
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

modulo2_ioports:
    ; Titulo del modulo
    mov rdi, msg_mod2_titulo
    call print_string

    ; --- 1. Permisos para el rango de puertos usados ---
    ; Habilitamos 0x00..0x3FF (1024 puertos) para cubrir teclado
    ; (60h/61h), diagnostico POST (80h) y COM1 (3F8h).
    mov rax, 173        ; syscall sys_ioperm
    mov rdi, 0          ; puerto base 0
    mov rsi, 0x400      ; 1024 puertos (0x000..0x3FF)
    mov rdx, 1          ; habilitar
    syscall

    cmp rax, 0
    jl .error_permisos  ; rax < 0 => error (falta de privilegios)

    ; --- 2. Lecturas con verificacion real de estado ---
    ; Puerto 60h (teclado), 8 bits
    mov rdi, lbl_p60
    call print_string
    xor rax, rax
    mov dx, 0x60
    in al, dx
    call print_estado_lectura   ; evalua AL (0xFF => sin respuesta)

    ; Puerto 61h (panel), 8 bits
    mov rdi, lbl_p61
    call print_string
    xor rax, rax
    mov dx, 0x61
    in al, dx
    call print_estado_lectura

    ; Puerto 3F8h (COM1), 8 bits
    mov rdi, lbl_p3f8
    call print_string
    xor rax, rax
    mov dx, 0x3F8
    in al, dx
    call print_estado_lectura

    ; --- 3. Demostracion de los tres anchos de IN y OUT ---
    mov rdi, msg_anchos_hdr
    call print_string

    ; IN 8 bits (teclado)
    mov rdi, lbl_in8
    call print_string
    xor rax, rax
    mov dx, 0x60
    in al, dx
    call print_estado_lectura

    ; IN 16 bits (COM1: 3F8h-3F9h). Verificamos AL (byte bajo).
    mov rdi, lbl_in16
    call print_string
    xor rax, rax
    mov dx, 0x3F8
    in ax, dx
    call print_estado_lectura

    ; IN 32 bits (COM1: 3F8h-3FBh). Verificamos AL (byte bajo).
    mov rdi, lbl_in32
    call print_string
    xor rax, rax
    mov dx, 0x3F8
    in eax, dx
    call print_estado_lectura

    ; OUT 8 bits al puerto POST 0x80. No hay dato de retorno; su
    ; validez la garantiza el permiso ya concedido por ioperm.
    mov rdi, lbl_out8
    call print_string
    mov dx, 0x80
    mov al, 0x00
    out dx, al
    mov rdi, estado_ok
    call print_string

    ; OUT 16 bits
    mov rdi, lbl_out16
    call print_string
    mov dx, 0x80
    mov ax, 0x0000
    out dx, ax
    mov rdi, estado_ok
    call print_string

    ; OUT 32 bits
    mov rdi, lbl_out32
    call print_string
    mov dx, 0x80
    mov eax, 0x00000000
    out dx, eax
    mov rdi, estado_ok
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
