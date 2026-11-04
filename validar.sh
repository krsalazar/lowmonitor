#!/usr/bin/env bash
# ==========================================================
# validar.sh - Validacion cruzada de LowMonitor
#
# Contrasta lo que reporta el binario 'lowmonitor' (escrito en
# ensamblador) contra herramientas NATIVAS de Linux, para
# demostrar que los resultados son veridicos.
#
# Por cada modulo se muestra, lado a lado:
#   - lo que mide LowMonitor
#   - lo que reporta la herramienta estandar equivalente
#
# No requiere root. Uso:
#   chmod +x validar.sh
#   ./validar.sh
# ==========================================================

set -u

ROJO=$'\033[31m'; VERDE=$'\033[32m'; AZUL=$'\033[34m'; NEG=$'\033[0m'; NEGR=$'\033[1m'

titulo() { echo; echo "${NEGR}${AZUL}=== $* ===${NEG}"; }
sub()    { echo "${NEGR}$*${NEG}"; }

# ----------------------------------------------------------
# 0. Preparacion: compilar si hace falta
# ----------------------------------------------------------
cd "$(dirname "$0")" || exit 1

if [ ! -x ./lowmonitor ]; then
    echo "Binario no encontrado; compilando con make..."
    make >/dev/null 2>&1 || { echo "${ROJO}Error al compilar${NEG}"; exit 1; }
fi

# Capturar la salida del programa una sola vez
SALIDA="$(./lowmonitor 2>/dev/null)"

echo "${NEGR}LowMonitor - Validacion cruzada contra herramientas nativas de Linux${NEG}"
echo "Fecha: $(date)"
echo "Host:  $(uname -srm)"

# ==========================================================
# Modulo 1 - Identificacion del CPU
# ==========================================================
titulo "Modulo 1: Identificacion del CPU"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 1/,/^$/p' | grep -E 'Procesador|Arquitectura|Extensiones'

sub "Fuente nativa (lscpu / /proc/cpuinfo):"
lscpu | grep -E 'Model name|Arquitectura|Architecture' | sed 's/^/  /'
echo -n "  Flags SIMD: "
grep -m1 -oE '(sse2?|avx2?|avx512[a-z]*)' /proc/cpuinfo | sort -u | tr '\n' ' '; echo
echo "  (Compara el nombre del procesador y que SSE/SSE2/AVX/AVX2 coincidan)"

# ==========================================================
# Modulo 2 - Puertos E/S
# ==========================================================
titulo "Modulo 2: Monitor de puertos E/S"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 2/,/^$/p' | grep -E 'Modo:|Puerto|IN |OUT ' | head -12

sub "Fuente nativa (/proc/ioports - mapa de puertos del kernel):"
if [ -r /proc/ioports ]; then
    coincidencias="$(grep -iE '0060|0061|03f8|keyboard|serial' /proc/ioports)"
    if [ -n "$coincidencias" ]; then
        echo "$coincidencias" | sed 's/^/  /'
        echo "  (Un usuario sin privilegios ve las direcciones como 0000-0000:"
        echo "   el kernel OCULTA los rangos reales, igual que bloquea el acceso"
        echo "   directo. Aun asi confirma que 'keyboard' existe como recurso"
        echo "   reservado. Con sudo se verian las direcciones 0060, 0061, 03f8.)"
    else
        echo "  (no se listan esos rangos para este usuario)"
    fi
else
    echo "  /proc/ioports no legible por este usuario"
fi
echo "  Conclusion: IN/OUT directas requieren CAP_SYS_RAWIO; por eso"
echo "  LowMonitor reporta [DENEGADO] como usuario normal. Coherente con"
echo "  que el kernel reserve y proteja estos puertos."

# ==========================================================
# Modulo 3 - Diagnostico de memoria
# ==========================================================
titulo "Modulo 3: Diagnostico de memoria"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 3/,/^$/p' | grep -E 'Patron|Memoria total'

sub "Fuente nativa (free / /proc/meminfo):"
free -m | awk '/Mem:/ {print "  RAM total (free):     " $2 " MB"}'
awk '/MemTotal/ {printf "  MemTotal (/proc):     %d MB\n", $2/1024}' /proc/meminfo
echo "  (Compara 'Memoria total' de LowMonitor con estos valores)"

# ==========================================================
# Modulo 4 - Rendimiento del CPU
# ==========================================================
titulo "Modulo 4: Monitor de rendimiento del CPU"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 4/,/^$/p' | grep -E 'Frecuencia|Ciclos|Instruc|CPI|IPC'

sub "Fuente nativa (/proc/cpuinfo, lscpu):"
grep -m1 'cpu MHz' /proc/cpuinfo | sed 's/^/  /'
lscpu | grep -iE 'MHz|BogoMIPS' | sed 's/^/  /'
echo "  (La 'Frecuencia (TSC)' de LowMonitor debe acercarse a 'cpu MHz')"

# Si existe 'perf', ofrecer una medicion real de IPC como contraste
if command -v perf >/dev/null 2>&1; then
    sub "Contraste de IPC con 'perf' (instrucciones reales retiradas):"
    perf stat -e instructions,cycles ./lowmonitor >/dev/null 2>perf.tmp
    grep -E 'insn per cycle|instructions|cycles' perf.tmp | sed 's/^/  /'
    rm -f perf.tmp
else
    echo "  (Instala 'linux-perf' para contrastar IPC con perf stat)"
fi

# ==========================================================
# Modulo 5 - Jerarquia de memoria
# ==========================================================
titulo "Modulo 5: Gestion jerarquica de memoria"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 5/,/^$/p' | grep -E 'Registros|L1|L2|L3|RAM'

sub "Fuente nativa (lscpu / /sys - tamanos de cache del sistema):"
lscpu | grep -iE 'L1d|L1i|L2|L3' | sed 's/^/  /'
echo "  Tamanos por nivel segun /sys:"
for idx in /sys/devices/system/cpu/cpu0/cache/index*; do
    [ -r "$idx/level" ] || continue
    lvl=$(cat "$idx/level"); typ=$(cat "$idx/type"); sz=$(cat "$idx/size")
    echo "    L$lvl ($typ): $sz"
done
echo "  (Los tamanos usados por LowMonitor para cada nivel deben caber"
echo "   dentro de estas capacidades; la latencia crece L1<L2<L3<RAM)"

# ==========================================================
# Modulo 6 - SIMD AVX2
# ==========================================================
titulo "Modulo 6: Operaciones SIMD (AVX2)"

sub "LowMonitor reporta:"
echo "$SALIDA" | sed -n '/Modulo 6/,$p' | grep -E 'AVX2|vaddps|vmulps|vcmpps|Throughput|Benchmark'

sub "Fuente nativa (/proc/cpuinfo - soporte AVX2):"
if grep -qm1 avx2 /proc/cpuinfo; then
    echo "  ${VERDE}avx2 presente en los flags del CPU${NEG} -> coincide con 'AVX2 habilitado: Si'"
else
    echo "  avx2 NO presente -> LowMonitor deberia reportar 'No'"
fi
echo "  (El GFLOPS depende del hardware; en VM suele ser bajo por el"
echo "   manejo del estado AVX del hipervisor)"

# ==========================================================
titulo "Resumen"
echo "Compara cada bloque 'LowMonitor reporta' con su 'Fuente nativa'."
echo "Coincidencias esperadas:"
echo "  M1: nombre de CPU y extensiones SIMD"
echo "  M3: memoria total (MB)"
echo "  M4: frecuencia aproximada"
echo "  M5: jerarquia de cache y progresion de latencias"
echo "  M6: soporte de AVX2"
echo
echo "${NEGR}Validacion completada.${NEG}"
