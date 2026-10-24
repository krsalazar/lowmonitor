# Makefile - LowMonitor
# Ensambla cada modulo por separado y los enlaza en un solo
# binario ELF64 con GNU ld. Compilacion para x86-64 nativo Linux.

AS = nasm
ASFLAGS = -f elf64
LD = ld
LDFLAGS =

TARGET = lowmonitor

# Orden: main primero (define _start), luego modulos y utilidades.
SRC = main.asm modulo1_cpu.asm modulo2_ioports.asm utils.asm
OBJ = $(SRC:.asm=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean
