import ctypes
from ctypes import WinDLL, c_int, c_void_p, POINTER

dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")

# Prueba básica
prueba = dll.pruebaPuente
prueba.argtypes = (c_int, c_int)
prueba.restype = c_int

# Movimiento jugador
moverJugador = dll.moverJugadorAsm
moverJugador.argtypes = [c_int, c_int, c_int]
moverJugador.restype = c_int

definirValor = dll.definirValorAsm
definirValor.argtypes = [c_int]
definirValor.restype = c_int

# Enemigos
init_enemigos = dll.initEnemigos
init_enemigos.argtypes = [c_int, c_int]
init_enemigos.restype = None

actualizarPosicionEnemigos = dll.actualizarPosicionEnemigosAsm
actualizarPosicionEnemigos.argtypes = [
    POINTER(c_int),  # pos_x (puntero a int)
    POINTER(c_int),  # pos_y (puntero a int)
    c_int,           # velocidad
    POINTER(c_int),  # dir (puntero a int)
    c_int            # ancho
]

update_all_enemigos = dll.updateAllEnemigos
update_all_enemigos.argtypes = [c_int]
update_all_enemigos.restype = None

get_enemigo_data = dll.getEnemigoData
get_enemigo_data.argtypes = [c_int, POINTER(c_int), POINTER(c_int), POINTER(c_int)]
get_enemigo_data.restype = c_int
# DISPAROS DEL JUGADOR - ¡SOLO ESTAS TRES!
crear_disparo_jugador = dll.crearDisparoJugador
crear_disparo_jugador.argtypes = [c_int, c_int]
crear_disparo_jugador.restype = None

actualizar_disparos_jugador = dll.actualizarDisparosJugador
actualizar_disparos_jugador.argtypes = []
actualizar_disparos_jugador.restype = None

get_disparo_jugador_data = dll.getDisparoJugadorData
get_disparo_jugador_data.argtypes = [c_int, POINTER(c_int), POINTER(c_int), POINTER(c_int)]
get_disparo_jugador_data.restype = c_int

check_colision_bala_enemigo = dll.checkColisionBalaEnemigo
check_colision_bala_enemigo.argtypes = []
check_colision_bala_enemigo.restype = c_int

update_colisiones = dll.updateColisiones
update_colisiones.argtypes = []
update_colisiones.restype = c_int

get_enemigos_vivos = dll.getEnemigosVivos
get_enemigos_vivos.argtypes = []
get_enemigos_vivos.restype = c_int

get_puntuacion = dll.getPuntuacion
get_puntuacion.argtypes = []
get_puntuacion.restype = c_int

add_puntuacion = dll.addPuntuacion
add_puntuacion.argtypes = [c_int]
add_puntuacion.restype = None

reset_puntuacion = dll.resetPuntuacion
reset_puntuacion.argtypes = []
reset_puntuacion.restype = None

check_colision_con_puntos = dll.checkColisionConPuntos
check_colision_con_puntos.argtypes = []
check_colision_con_puntos.restype = c_int

crear_disparo_enemigo = dll.crearDisparoEnemigo
crear_disparo_enemigo.argtypes = [c_int, c_int]
crear_disparo_enemigo.restype = None

actualizar_disparos_enemigos = dll.actualizarDisparosEnemigos
actualizar_disparos_enemigos.argtypes = []
actualizar_disparos_enemigos.restype = None

get_disparo_enemigo_data = dll.getDisparoEnemigoData
get_disparo_enemigo_data.argtypes = [c_int, POINTER(c_int), POINTER(c_int), POINTER(c_int)]
get_disparo_enemigo_data.restype = c_int

intentar_disparo_enemigo = dll.intentarDisparoEnemigo
intentar_disparo_enemigo.argtypes = []
intentar_disparo_enemigo.restype = None

check_colision_bala_enemigo_jugador = dll.checkColisionBalaEnemigoJugador
check_colision_bala_enemigo_jugador.argtypes = [c_int, c_int, c_int, c_int]
check_colision_bala_enemigo_jugador.restype = c_int

if (prueba(5,20)==25):
    prueba_completa = "cargado."
else:
    prueba_completa = "fallo."

print("dll...", prueba_completa)
