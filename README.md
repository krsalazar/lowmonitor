# LowMonitor

Herramienta de diagnóstico y monitorización de hardware escrita en
**ensamblador x86-64** para Linux, sin dependencias externas. Se comunica
con el sistema operativo mediante syscalls directas y produce un único
binario ELF64.

LowMonitor inspecciona el procesador y la memoria a través de seis módulos:
identificación del CPU, acceso a puertos de E/S, prueba de integridad de
memoria, medición de rendimiento con el contador de ciclos, análisis de la
jerarquía de caché y operaciones vectoriales SIMD.

---

## Índice

- [Características](#características)
- [Requisitos](#requisitos)
- [Instalación](#instalación)
- [Uso](#uso)
- [Módulos](#módulos)
- [Acceso a puertos de E/S](#acceso-a-puertos-de-es)
- [Validación](#validación)
- [Estructura del proyecto](#estructura-del-proyecto)

---

## Características

- Escrito 100 % en ensamblador x86-64 (NASM), sin libc.
- Corre como usuario regular; no requiere privilegios de root.
- Detección de CPU y extensiones SIMD vía `CPUID`.
- Acceso real a puertos de E/S con `IN`/`OUT`, con manejo de la excepción
  de protección cuando no hay privilegios.
- Medición de rendimiento con `RDTSC` (frecuencia, CPI, IPC).
- Análisis de latencia de caché por *pointer chasing*.
- Operaciones vectoriales AVX2 sobre registros YMM de 256 bits.

---

## Requisitos

| Componente | Detalle |
|---|---|
| Arquitectura | x86-64 (AMD64 / Intel 64) |
| Sistema operativo | Linux de 64 bits |
| Ensamblador | NASM 2.15+ |
| Enlazador | GNU ld (binutils) |
| Build | GNU make |

---

## Instalación

```bash
# Dependencias (Debian/Ubuntu)
sudo apt install nasm binutils make

# Compilar
make
```

La compilación genera el binario `lowmonitor`. Para limpiar los artefactos:

```bash
make clean
```

---

## Uso

```bash
./lowmonitor
```

Ejecuta los seis módulos en secuencia e imprime los resultados. No requiere
argumentos ni privilegios.

```text
--- Modulo 1: Identificacion del CPU ---
Procesador: Intel Core Processor (Skylake)
Arquitectura: x86_64
Extensiones: SSE SSE2 AVX AVX2

--- Modulo 3: Diagnostico de memoria ---
Patron 0xAA:              PASADA (0 errores)
Patron 0x55:              PASADA (0 errores)
Patron incremental:       PASADA (0 errores)
Memoria total:            7943 MB detectada

--- Modulo 4: Monitor de rendimiento del CPU ---
Frecuencia (TSC):         1.00 GHz
CPI promedio:             0.34
IPC:                      2.90

--- Modulo 5: Gestion jerarquica de memoria ---
L1 cache:   3.04 ciclos/acceso   (16 KB)
L2 cache:   7.52 ciclos/acceso   (256 KB)
L3 cache:   10.84 ciclos/acceso  (8 MB)
RAM:        175.25 ciclos/acceso (64 MB)
```

*(Salida abreviada; los valores dependen del hardware.)*

---

## Módulos

| # | Módulo | Descripción |
|---|---|---|
| 1 | Identificación del CPU | Nombre comercial del procesador (`CPUID`) y extensiones SSE, SSE2, AVX, AVX2, AVX-512. |
| 2 | Puertos de E/S | `IN`/`OUT` en 8/16/32 bits sobre puertos estándar (teclado 60h, panel 61h, COM1 3F8h) con verificación de estado. |
| 3 | Diagnóstico de memoria | Prueba de integridad con patrones 0xAA, 0x55 e incremental; conteo de bits corruptos. RAM total vía `sysinfo`. |
| 4 | Rendimiento del CPU | `RDTSC`: frecuencia del contador, ciclos totales, CPI e IPC. |
| 5 | Jerarquía de memoria | Latencia por nivel (registros, L1, L2, L3, RAM) por *pointer chasing* con recorrido permutado. |
| 6 | SIMD (AVX2) | Suma, multiplicación y comparación vectoriales sobre YMM (256 bits); estimación de throughput. |

---

## Acceso a puertos de E/S

Las instrucciones `IN`/`OUT` son privilegiadas: el kernel solo las permite a
procesos con la capability `CAP_SYS_RAWIO`. LowMonitor las ejecuta de todos
modos; sin privilegios, el CPU lanza una excepción de protección general
(#GP, vector 13) que el programa captura con un manejador de `SIGSEGV` y
reporta de forma controlada, sin abortar. Así usa `IN`/`OUT` reales sin
necesidad de ejecutarse como root.

Estados reportados:

| Estado | Significado |
|---|---|
| `[OK]` | `IN`: el puerto respondió (valor ≠ 0xFF). `OUT`: se ejecutó sin excepción. |
| `[--]` | `IN`: se leyó 0xFF (bus flotante, sin respuesta). |
| `[DENEGADO] excepcion vector 13` | El CPU bloqueó la instrucción por falta de permiso. |

Para leer los valores reales de los puertos sin ejecutar como root, se puede
conceder solo esa capability al binario (opcional):

```bash
make caps      # setcap cap_sys_rawio+ep (requiere sudo una vez)
./lowmonitor
make nocaps    # revierte
```

---

## Validación

El script `validar.sh` contrasta cada módulo contra herramientas nativas del
sistema para verificar que los resultados son reales:

```bash
./validar.sh
```

| Módulo | Contrastado con |
|---|---|
| 1 | `lscpu`, `/proc/cpuinfo` |
| 2 | `/proc/ioports` |
| 3 | `free`, `/proc/meminfo` |
| 4 | `/proc/cpuinfo`; `perf` si está disponible |
| 5 | `lscpu`, `/sys/.../cache` |
| 6 | `/proc/cpuinfo` |

---

## Estructura del proyecto

```
lowmonitor/
├── main.asm                Punto de entrada; orquesta los módulos
├── modulo1_cpu.asm         Identificación del CPU
├── modulo2_ioports.asm     Puertos de E/S
├── modulo3_memoria.asm     Diagnóstico de memoria
├── modulo4_rendimiento.asm Rendimiento del CPU (RDTSC)
├── modulo5_jerarquia.asm   Jerarquía de memoria
├── modulo6_simd.asm        Operaciones SIMD (AVX2)
├── utils.asm               Rutinas compartidas (print_string, print_uint, print_fixed2)
├── Makefile                Build y targets auxiliares
├── validar.sh              Validación cruzada contra herramientas del sistema
├── docs/                   Reporte técnico (PDF)
└── README.md
```

Cada módulo es un archivo independiente que expone su rutina con `global` y
consume las utilidades compartidas mediante `extern`; el enlazador une todos
los objetos en un solo binario.
