# Makefile - LowMonitor
# Ensambla cada modulo por separado y los enlaza en un solo
# binario ELF64 con GNU ld. Compilacion para x86-64 nativo Linux.

AS = nasm
ASFLAGS = -f elf64
LD = ld
LDFLAGS =

TARGET = lowmonitor

# Orden: main primero (define _start), luego modulos y utilidades.
SRC = main.asm modulo1_cpu.asm modulo2_ioports.asm modulo3_memoria.asm utils.asm
OBJ = $(SRC:.asm=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJ) $(TARGET)

# Opcional: otorga solo CAP_SYS_RAWIO al binario para que el Modulo 2
# lea los puertos reales ejecutandose como usuario normal (sin root).
# Requiere sudo una vez; se pierde al recompilar (make lo regenera).
caps: $(TARGET)
	sudo setcap cap_sys_rawio+ep $(TARGET)
	getcap $(TARGET)

# Quita la capability del binario.
nocaps:
	sudo setcap -r $(TARGET)

.PHONY: all clean caps nocaps
