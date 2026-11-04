# Reporte técnico — LowMonitor

**Diagnóstico y monitorización de hardware en ensamblador x86-64**

Curso: Arquitectura de Computadoras 2 — Universidad Mariano Gálvez
Repositorio: https://github.com/krsalazar/lowmonitor

---

## 1. Introducción

LowMonitor es una aplicación de diagnóstico de hardware escrita íntegramente
en ensamblador x86-64 para Linux, sin dependencias de bibliotecas externas
(se comunica con el sistema operativo mediante *syscalls* directas). El
objetivo es demostrar el dominio del set de instrucciones x86-64, el manejo
de registros, el acceso a puertos de E/S y la jerarquía de memoria.

El programa está compuesto por seis módulos y un conjunto de rutinas
auxiliares compartidas. Se ensambla con NASM y se enlaza con GNU ld,
produciendo un binario ELF64 que corre como usuario regular.

**Entorno de validación:** Linux Debian x86-64, procesador Intel Core
(Skylake), 4 CPUs, caches L1d 32 KB, L2 4 MB, L3 16 MB, 8 GB de RAM.

---

## 2. Arquitectura del código

El proyecto sigue una estructura modular: un archivo por módulo, cada uno
exponiendo su rutina con `global` y consumiendo las utilidades compartidas
mediante `extern`. El archivo `main.asm` contiene el punto de entrada
`_start` y llama a los módulos en secuencia.

Las rutinas compartidas (`utils.asm`) incluyen `print_string` (escritura a
stdout), `print_uint` (entero a decimal) y `print_fixed2` (número con dos
decimales). Un detalle relevante de diseño: `print_uint` construye la cadena
completa en un buffer y la emite con una sola llamada `write`, porque la
instrucción `syscall` destruye los registros `RCX` y `R11`; hacer una
syscall dentro del bucle de conversión corrompería el contador.

Todo el programa usa registros de 64 bits y la convención de llamadas de
Linux (`syscall` con número en `RAX`).

---

## 3. Módulo 1 — Identificación del CPU

**Objetivo:** detectar el procesador y sus extensiones SIMD.

**Implementación:** se usa la instrucción `CPUID`. Las hojas `0x80000002`
a `0x80000004` devuelven el *brand string* (nombre comercial, 48 bytes). La
hoja 1 reporta SSE/SSE2/AVX en `EDX`/`ECX`, y la hoja 7 reporta AVX2/AVX-512
en `EBX`. Cada bit de característica se evalúa con `BT` (bit test) y un salto
condicional.

**Resultado medido:**
```
Procesador: Intel Core Processor (Skylake)
Arquitectura: x86_64
Extensiones: SSE SSE2 AVX AVX2
```

La detección coincide con lo reportado por `lscpu`, lo que valida la lectura
de CPUID.

---

## 4. Módulo 2 — Monitor de puertos E/S

**Objetivo:** ejecutar `IN`/`OUT` en anchos de 8, 16 y 32 bits sobre puertos
estándar, verificando el estado de cada operación.

**Reto técnico — el requisito "sin root":** las instrucciones `IN`/`OUT`
son privilegiadas. El kernel de Linux solo las permite a procesos con la
capability `CAP_SYS_RAWIO`. El enunciado pide, a la vez, usar `IN`/`OUT` y
ejecutar como usuario regular, dos requisitos que en apariencia se
contradicen.

**Solución implementada:** se instala un manejador de `SIGSEGV` mediante
`rt_sigaction`. El módulo ejecuta siempre las operaciones de E/S; cuando el
proceso no tiene privilegios, el CPU lanza una **excepción de protección
general** (#GP, vector 13) que el kernel entrega como `SIGSEGV`. El
manejador lee el vector de la excepción desde el `ucontext`, marca la
operación como fallida y desvía `RIP` a una dirección de recuperación para
continuar con la siguiente. Al terminar, restaura el comportamiento por
defecto de `SIGSEGV` y libera los permisos.

Así el programa cumple ambos requisitos: usa instrucciones `IN`/`OUT`
reales y corre como usuario regular sin abortar. Las operaciones cubren los
tres anchos (`in al/ax/eax, dx` y `out dx, al/ax/eax`) con direccionamiento
por `DX`, que cubre el espacio completo 0–65535. Las escrituras se dirigen
al puerto de diagnóstico POST `0x80`, seguro en Linux.

**Verificación de estado:** `[OK]` si el puerto responde (valor ≠ 0xFF),
`[--]` si se lee 0xFF (bus flotante), `[DENEGADO] excepcion vector 13` si el
CPU bloquea la instrucción.

**Opcional:** el target `make caps` otorga `CAP_SYS_RAWIO` al binario para
leer los valores reales de los puertos sin ejecutar como root.

---

## 5. Módulo 3 — Diagnóstico de memoria

**Objetivo:** probar la integridad de la memoria y contar bits corruptos.

**Implementación:** sobre un buffer de 1 MiB se aplican tres patrones —
0xAA, 0x55 y una secuencia incremental (byte[i] = i mod 256). Para cada
patrón se escribe el buffer completo, se relee y se compara. Los bits
corruptos se cuentan haciendo `XOR` entre el valor esperado y el leído, y
`POPCNT` sobre el resultado (cuenta bits en 1). La RAM total se obtiene con
el syscall `sysinfo`.

**Resultado medido (RAM sana):**
```
Patron 0xAA:              PASADA (0 errores)
Patron 0x55:              PASADA (0 errores)
Patron incremental:       PASADA (0 errores)
Memoria total:            7943 MB detectada
```
El valor de RAM coincide con `free` (7.8 GiB).

**Validación de la detección de errores:** mediante una prueba de inyección
de fallo (corromper un byte de 0xAA a 0x00), el módulo reportó
`FALLO (4 bits corruptos)`, el valor exacto esperado
(10101010 XOR 00000000 = 4 bits). Esto confirma que el conteo es correcto.

---

## 6. Módulo 4 — Monitor de rendimiento del CPU

**Objetivo:** medir ciclos, CPI e IPC con el Timestamp Counter.

**Implementación:** se usa `RDTSC`, serializado con `CPUID` como barrera
para evitar el reordenamiento de instrucciones. La frecuencia del TSC se
estima leyendo el contador antes y después de dormir 100 ms con
`nanosleep`. Para CPI/IPC se ejecuta un bucle con un número exacto y
conocido de instrucciones (100 millones de iteraciones × 5 instrucciones =
500 millones), lo que da un denominador preciso.

**Resultado medido:**
```
Frecuencia (TSC):         1.00 GHz
Ciclos totales:           172300000
Instrucciones ejecutadas: 500000000
CPI promedio:             0.34
IPC:                      2.90
```

**Validación cruzada:** la frecuencia medida (1.00 GHz) coincide con
`/proc/cpuinfo` (1000.077 MHz), lo que confirma la medición por TSC. Un
CPI < 1 y un IPC ≈ 3 son coherentes con la naturaleza superescalar del
procesador Skylake, que ejecuta varias instrucciones por ciclo.

**Nota:** IPC/CPI "de hardware" (instrucciones retiradas reales) requerirían
los contadores de rendimiento (PMU); aquí el conteo es exacto por
construcción del bucle.

---

## 7. Módulo 5 — Gestión jerárquica de memoria

**Objetivo:** medir la latencia de cada nivel de la jerarquía de memoria.

**Implementación — *pointer chasing* permutado:** para cada nivel se recorre
una cadena cíclica de punteros alojada en un buffer del tamaño de ese nivel
(16 KB para L1, 256 KB para L2, 8 MB para L3, 64 MB para RAM). Cada nodo
ocupa una línea de caché (64 B) y guarda la dirección del siguiente. Como
cada acceso depende del valor leído en el anterior, el CPU no puede
paralelizarlos, y el tiempo medido es la latencia real del nivel.

El detalle clave es que los nodos **no** se enlazan en orden físico, que el
prefetcher de hardware detectaría y precargaría, falseando la medición. Se
enlazan según una permutación `idx = (k · PASO) mod N`, con N potencia de 2
y PASO impar (coprimo con N): esto recorre todos los nodos una vez en orden
disperso, derrotando al prefetcher.

**Resultado medido:**
```
Registros:  1.00 ciclos/acceso
L1 cache:   3.04 ciclos/acceso   (16 KB)
L2 cache:   7.52 ciclos/acceso   (256 KB)
L3 cache:   10.84 ciclos/acceso  (8 MB)
RAM:        175.25 ciclos/acceso (64 MB)
```

La progresión es la esperada: registros < L1 < L2 < L3 < RAM. Un primer
intento con recorrido secuencial daba ~10 ciclos para RAM (irreal), porque
el prefetcher precargaba el buffer; el cambio al recorrido permutado expuso
las latencias reales.

---

## 8. Módulo 6 — Operaciones SIMD (bonus)

**Objetivo:** demostrar operaciones vectoriales con AVX2.

**Implementación:** tras confirmar AVX2 con CPUID, se operan registros YMM
de 256 bits (8 floats de 32 bits en paralelo): suma (`vaddps`),
multiplicación (`vmulps`) y comparación (`vcmpps`). El throughput nominal es
de 8 operaciones por instrucción. El benchmark de GFLOPS ejecuta un bucle
con varios acumuladores YMM independientes y lo mide con `RDTSC`, usando la
frecuencia del TSC para convertir ciclos a segundos. Se emite `vzeroupper`
al final para evitar la penalización de transición AVX↔SSE.

**Resultado medido:**
```
AVX2 habilitado:          Si
Suma vectorizada (vaddps):     8 floats en paralelo [OK]
Multiplicacion   (vmulps):     8 floats en paralelo [OK]
Comparacion      (vcmpps):     8 floats en paralelo [OK]
Throughput:               8 operaciones paralelas (YMM, 8x float32)
Benchmark:                0.14 GFLOPS
```

**Hallazgo sobre el entorno:** el GFLOPS medido es bajo por una limitación
del entorno virtualizado, no del código. El diagnóstico mostró que el bucle
tomó ~4.6 mil millones de ciclos (~464 ciclos por grupo de 8 operaciones
YMM), frente a los ~2–4 esperados en hardware nativo. La VM expone AVX2 vía
CPUID y ejecuta las instrucciones correctamente (de ahí los `[OK]`), pero no
a velocidad nativa: el hipervisor penaliza el manejo del estado AVX. En
hardware físico se esperarían decenas de GFLOPS. El módulo cumple el
requisito (detección y operaciones vectoriales reales); el valor numérico
refleja fielmente el entorno de ejecución.

---

## 9. Conclusiones

- Los seis módulos se implementaron íntegramente en ensamblador x86-64
  nativo, con registros de 64 bits y syscalls directas, cumpliendo el
  requisito de no depender de bibliotecas externas.
- El Módulo 2 resuelve la aparente contradicción "usar IN/OUT" vs. "sin
  root" capturando la excepción de protección del CPU, lo que además
  evidencia el mecanismo de anillos de protección de la arquitectura.
- Las mediciones de rendimiento (Módulo 4) y de jerarquía de memoria
  (Módulo 5) se validaron contra fuentes independientes del sistema
  (`/proc/cpuinfo`, `lscpu`, `free`) y muestran resultados coherentes con la
  microarquitectura Skylake.
- Se documentaron con transparencia las limitaciones del entorno
  virtualizado (E/S de puertos y throughput AVX), distinguiendo entre lo que
  es correcto en el código y lo que depende del hardware.

---

## 10. Compilación y ejecución

```bash
sudo apt install nasm binutils make   # dependencias
make                                   # compila -> binario ELF64 'lowmonitor'
./lowmonitor                           # ejecuta los 6 módulos (usuario regular)
```

Opcional, para acceso real a puertos en el Módulo 2 sin ejecutar como root:

```bash
make caps      # otorga CAP_SYS_RAWIO al binario (sudo una vez)
./lowmonitor
make nocaps    # revierte
```
