# lowmonitor
Proyecto del curso Arquitectura de computadoras 2

Configuraciones iniciales:
Este proyecto se desarrollo en un entorno de Ubuntu, no es virtualizado, el equipo corre el sistema operativo de forma local.
Para iniciar, necesitamos instalar un ensamblador y enlazador, primero, actualizamos el sistema base con
sudo apt update && sudo apt upgrade

Ahora vamos a instalar NASM 2.15+ (o GAS) como ensamblador y GNU ld como enlazador.
sudo apt install nasm binutils

Tambien necesitamos una herramienta para compilar por medio de un archivo makefile:
sudo apt install make

teniendo estas herramientas instaladas, procedemos a compilar el código desarrollado, en la terminal, abierta en la carpeta donde se encuentra el còdigo, ejecutamos el comando:
make
esto va a generar un archivo llamado lowmonitor, posteriormente, ejecutamos este archivo desde la terminal:
./lowmonitor

## Permisos y Modulo 2 (puertos E/S)

El programa completo se ejecuta como usuario regular, sin sudo:

    ./lowmonitor

Las instrucciones IN/OUT solo se permiten a procesos con la capability
CAP_SYS_RAWIO. Sin ella, el Modulo 2 ejecuta igual cada operacion de E/S;
el CPU la bloquea con una excepcion de proteccion general (#GP, vector 13),
el programa la captura con un manejador de SIGSEGV y reporta el resultado
de cada operacion como `[DENEGADO] excepcion vector 13`.

Para ver los valores reales de los puertos sin ejecutar como root, se le
puede otorgar al binario solo esa capability (requiere sudo una vez y se
pierde al recompilar):

    make caps      # sudo setcap cap_sys_rawio+ep lowmonitor
    ./lowmonitor   # usuario normal, acceso real a puertos
    make nocaps    # quitar la capability

Estados posibles en el Modulo 2:

| Estado | Significado |
|---|---|
| `[OK]` | IN: el puerto respondio con un valor distinto de 0xFF. OUT: se ejecuto sin excepcion |
| `[--]` | IN: se leyo 0xFF (bus flotante, ningun dispositivo respondio) |
| `[DENEGADO] excepcion vector 13` | El CPU bloqueo la instruccion por falta de permiso de E/S |
