# LowMonitor

Herramienta de diagnóstico y monitorización de hardware escrita en
**ensamblador x86-64 nativo para Linux**. Proyecto del curso de
Arquitectura de Computadoras 2 (Universidad Mariano Gálvez).

LowMonitor inspecciona el procesador y la memoria del sistema a través de
seis módulos independientes que demuestran el uso directo del set de
instrucciones x86-64, el acceso a puertos de E/S, la medición de
rendimiento con el contador de tiempo del CPU y las operaciones
vectoriales SIMD.

---

## Índice

- [Requisitos](#requisitos)
- [Instalación de herramientas](#instalación-de-herramientas)
- [Compilación](#compilación)
- [Ejecución](#ejecución)
- [Módulos](#módulos)
- [Permisos y el Módulo 2](#permisos-y-el-módulo-2)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Notas sobre el entorno de prueba](#notas-sobre-el-entorno-de-prueba)

---

## Requisitos

| Componente | Versión / detalle |
|---|---|
| Arquitectura | x86-64 nativo (AMD64 / Intel 64) |
| Sistema operativo | Linux de 64 bits |
| Ensamblador | NASM 2.15 o superior |
| Enlazador | GNU ld (binutils) |
| Automatización | GNU make |

El programa se ejecuta como **usuario regular**; no requiere privilegios de
root (ver [Permisos y el Módulo 2](#permisos-y-el-módulo-2)).

---

## Instalación de herramientas

En una distribución basada en Debian/Ubuntu:

```bash
sudo apt update
sudo apt install nasm binutils make
```

- `nasm`: ensamblador.
- `binutils`: incluye `ld`, el enlazador.
- `make`: ejecuta la compilación a partir del `Makefile`.

---

## Compilación

Desde la carpeta del proyecto:

```bash
make
```

Esto ensambla cada módulo a su objeto `.o` y los enlaza en un único binario
ELF64 llamado `lowmonitor`.

Para limpiar los artefactos de compilación:

```bash
make clean
```

---

## Ejecución

```bash
./lowmonitor
```

El programa ejecuta los seis módulos en orden e imprime los resultados en
pantalla. No necesita argumentos ni privilegios.

---

## Módulos

| # | Módulo | Qué hace |
|---|---|---|
| 1 | Identificación del CPU | Detecta el nombre comercial del procesador (CPUID) y las extensiones disponibles: SSE, SSE2, AVX, AVX2, AVX-512. |
| 2 | Monitor de puertos E/S | Ejecuta `IN`/`OUT` en anchos de 8, 16 y 32 bits sobre puertos estándar (teclado 60h, panel 61h, COM1 3F8h) y verifica el estado de cada operación. |
| 3 | Diagnóstico de memoria | Prueba la integridad de un bloque de memoria con los patrones 0xAA, 0x55 y una secuencia incremental, contando los bits corruptos. Reporta la RAM total vía `sysinfo`. |
| 4 | Rendimiento del CPU | Mide con `RDTSC` la frecuencia del contador de tiempo, los ciclos totales de un bloque de trabajo, el CPI promedio y el IPC. |
| 5 | Jerarquía de memoria | Mide la latencia de acceso (ciclos) de cada nivel: registros, L1, L2, L3 y RAM, usando *pointer chasing* con recorrido permutado. |
| 6 | Operaciones SIMD (bonus) | Demuestra operaciones vectoriales AVX2 (suma, multiplicación y comparación sobre registros YMM de 256 bits) y estima el throughput en GFLOPS. |

### Ejemplo de salida

```text
--- Modulo 1: Identificacion del CPU ---
Procesador: Intel Core Processor (Skylake)
Arquitectura: x86_64
Extensiones: SSE SSE2 AVX AVX2

--- Modulo 2: Monitor de puertos E/S ---
Modo: usuario regular (ioperm denegado, errno 1)
  IN/OUT se ejecutan igual; si el CPU los bloquea, la excepcion
  se captura y se reporta (vector 13 = #GP, proteccion general).
Puerto 60h (teclado): [DENEGADO] excepcion vector 13
...

--- Modulo 3: Diagnostico de memoria ---
Patron 0xAA:              PASADA (0 errores)
Patron 0x55:              PASADA (0 errores)
Patron incremental:       PASADA (0 errores)
Memoria total:            7943 MB detectada
Buffer probado:           1024 KB

--- Modulo 4: Monitor de rendimiento del CPU ---
Frecuencia (TSC):         1.00 GHz
Ciclos totales:           172300000
Instrucciones ejecutadas: 500000000
CPI promedio:             0.34
IPC:                      2.90

--- Modulo 5: Gestion jerarquica de memoria ---
Registros:  1.00 ciclos/acceso
L1 cache:   3.04 ciclos/acceso   (16 KB)
L2 cache:   7.52 ciclos/acceso   (256 KB)
L3 cache:   10.84 ciclos/acceso   (8 MB)
RAM:        175.25 ciclos/acceso   (64 MB)

--- Modulo 6: Operaciones SIMD (AVX2) ---
AVX2 habilitado:          Si
Suma vectorizada (vaddps):     8 floats en paralelo [OK]
Multiplicacion   (vmulps):     8 floats en paralelo [OK]
Comparacion      (vcmpps):     8 floats en paralelo [OK]
Throughput:               8 operaciones paralelas (YMM, 8x float32)
Benchmark:                0.14 GFLOPS
```

*(Los valores numéricos dependen del hardware y del entorno de ejecución.)*

---

## Permisos y el Módulo 2

El programa completo se ejecuta como **usuario regular, sin sudo y sin
ningún paso previo**, en cualquier equipo Linux x86-64:

```bash
make
./lowmonitor
```

Las instrucciones `IN`/`OUT` que acceden a puertos de hardware son
**privilegiadas**: el kernel de Linux solo las permite a procesos con la
capability `CAP_SYS_RAWIO`. El Módulo 2 ejecuta cada operación de E/S de
todos modos; si el proceso no tiene ese permiso, el CPU la bloquea con una
**excepción de protección general** (#GP, vector 13), que el programa
captura con un manejador de `SIGSEGV` y reporta de forma controlada. Así el
módulo cumple el requisito de usar `IN`/`OUT` reales **sin** necesidad de
ejecutar como root.

### Estados que reporta el Módulo 2

| Estado | Significado |
|---|---|
| `[OK]` | `IN`: el puerto respondió con un valor distinto de `0xFF`. `OUT`: se ejecutó sin excepción. |
| `[--]` | `IN`: se leyó `0xFF` (bus flotante; ningún dispositivo respondió). |
| `[DENEGADO] excepcion vector 13` | El CPU bloqueó la instrucción por falta del permiso de E/S. |

### Opcional: acceso real a los puertos sin root

Para que el Módulo 2 lea los **valores reales** de los puertos sin ejecutar
como root, se le puede otorgar al binario únicamente la capability
`CAP_SYS_RAWIO`. **No es necesario para ejecutar el programa**; requiere
sudo una vez por equipo y se pierde al recompilar:

```bash
make caps      # sudo setcap cap_sys_rawio+ep lowmonitor
./lowmonitor   # usuario normal, acceso real a puertos
make nocaps    # quitar la capability
```

Con la capability concedida, el módulo entra en "Modo: privilegiado" y
muestra `[OK]`/`[--]` según la respuesta real de cada puerto.

---

## Estructura del proyecto

```
lowmonitor/
├── main.asm               Punto de entrada (_start); llama a cada módulo en orden
├── modulo1_cpu.asm        Módulo 1: identificación del CPU
├── modulo2_ioports.asm    Módulo 2: monitor de puertos E/S
├── modulo3_memoria.asm    Módulo 3: diagnóstico de memoria
├── modulo4_rendimiento.asm Módulo 4: rendimiento del CPU (RDTSC)
├── modulo5_jerarquia.asm  Módulo 5: jerarquía de memoria
├── modulo6_simd.asm       Módulo 6: operaciones SIMD (AVX2)
├── utils.asm              Rutinas compartidas (print_string, print_uint, print_fixed2)
├── Makefile               Compilación y targets auxiliares (caps/nocaps)
└── README.md              Este documento
```

El código está organizado en módulos independientes: cada archivo expone su
rutina con `global` y usa las utilidades compartidas mediante `extern`. El
enlazador une todos los objetos en un solo binario.

---

## Validación cruzada

El script `validar.sh` contrasta lo que reporta LowMonitor contra
herramientas nativas de Linux, módulo por módulo, para demostrar que los
resultados son verídicos:

```bash
./validar.sh
```

| Módulo | Se compara contra |
|---|---|
| 1 CPU | `lscpu`, `/proc/cpuinfo` (nombre y extensiones SIMD) |
| 2 Puertos | `/proc/ioports` (mapa de puertos del kernel) |
| 3 Memoria | `free`, `/proc/meminfo` (RAM total) |
| 4 Rendimiento | `/proc/cpuinfo` (frecuencia); `perf` si está instalado (IPC) |
| 5 Jerarquía | `lscpu`, `/sys/.../cache` (tamaños de caché) |
| 6 SIMD | `/proc/cpuinfo` (soporte AVX2) |

No requiere root. Muestra, lado a lado, el valor de LowMonitor y el de la
fuente oficial del sistema para que la coincidencia sea evidente.

---

## Notas sobre el entorno de prueba

El proyecto fue desarrollado y validado en una máquina con Linux Debian
sobre un procesador Intel Skylake (x86-64). Algunos resultados dependen del
entorno:

- En máquinas **virtualizadas**, el acceso a puertos de E/S (Módulo 2) y las
  latencias de memoria (Módulo 5) pueden diferir del hardware físico.
- El Módulo 6 ejecuta las instrucciones AVX2 correctamente, pero en un
  entorno virtualizado el throughput en GFLOPS puede ser mucho menor que en
  hardware nativo, porque el hipervisor no siempre ejecuta las instrucciones
  vectoriales a velocidad nativa. El valor mostrado refleja el entorno real
  de ejecución.
