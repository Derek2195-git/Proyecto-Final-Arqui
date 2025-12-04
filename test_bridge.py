import ctypes
from ctypes import WinDLL, c_int, c_void_p, POINTER

dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")

prueba = dll.pruebaPuente
prueba.argtypes = (c_int, c_int)
prueba.restype = c_int
moverJugador = dll.moverJugadorAsm
definirValor = dll.definirValorAsm
actualizarPosicionEnemigos = dll.actualizarPosicionEnemigosAsm
actualizarPosicionEnemigos.argtypes = [
    POINTER(c_int),  # pos_x (puntero a int)
    POINTER(c_int),  # pos_y (puntero a int)
    c_int,           # velocidad
    POINTER(c_int),  # dir (puntero a int)
    c_int            # ancho
]

init_enemigos = dll.initEnemigos
init_enemigos.argtypes = [c_int, c_int]
init_enemigos.restype = None

update_all_enemigos = dll.updateAllEnemigos
update_all_enemigos.argtypes = [c_int]
update_all_enemigos.restype = None

get_enemigo_data = dll.getEnemigoData
get_enemigo_data.argtypes = [c_int, POINTER(c_int), POINTER(c_int), POINTER(c_int)]
get_enemigo_data.restype = c_int


if (prueba(5,20)==25):
    prueba_completa = "cargado."
else:
    prueba_completa = "fallo."

print("dll...", prueba_completa)
