# Makefile

AS = nasm
ASFLAGS = -f elf64
LD = ld
LDFLAGS =

TARGET = lowmonitor
SRC = Archivo.asm
OBJ = $(SRC:.asm=.o)

all: $(TARGET)

$(TARGET): $(OBJ)
	$(LD) $(LDFLAGS) -o $@ $^

%.o: %.asm
	$(AS) $(ASFLAGS) -o $@ $<

clean:
	rm -f $(OBJ) $(TARGET)

.PHONY: all clean
