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
