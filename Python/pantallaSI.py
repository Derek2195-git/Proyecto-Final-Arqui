import pygame
import enemigos

from ctypes import WinDLL, c_int, byref
from test_bridge import moverJugador, init_enemigos, update_all_enemigos, \
    get_enemigo_data
try:
    dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")
except Exception as e:
    print("DLL no encontrada")
    dll = None

# Creación de la ventana aqui
pygame.init()
pygame.mixer.init()
pygame.mixer.music.load("../recursos/Expedition33_GestralBeach.mp3")
#pygame.mixer.music.play(-1)
WIDTH = 400
HEIGHT = 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Space Invaders - La prueba")

player_img = pygame.image.load("../recursos/naveprincipal.png").convert_alpha()
enemy_img = pygame.image.load("../recursos/naveprincipal.png").convert_alpha()
player_img = pygame.transform.scale(player_img, (50, 50))
enemy_img = pygame.transform.scale(enemy_img, (50, 50))

# Datos rapidos para el jugador
player_x = WIDTH // 2
player_y = HEIGHT - 50
player_width = 50
player_height = 50
player_speed = 3

clock = pygame.time.Clock()
FPS = 60

# Cargamos el DLL aqui




if dll:
    init_enemigos(2,5)
enemigo = enemigos.Enemigos(10, 50, 1, enemy_img)
enemigo2 = enemigos.Enemigos(40, 50, 5, enemy_img)


# Bucle de juego?
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
    # Movimiento del jugador
    keys = pygame.key.get_pressed()
    direccion = 0
    if keys[pygame.K_LEFT]:
        direccion = -1
    if keys[pygame.K_RIGHT]:
        direccion = 1

    if dll:
        player_x = moverJugador(player_x, direccion, player_speed)

    # Limitar jugador a pantalla
    if player_x < 0:
        player_x = 0
    if player_x > WIDTH - 50:
        player_x = WIDTH - 50
    # Actualizar todos los enemigos (en MASM)
    if dll:
        update_all_enemigos(WIDTH)

    # Dibujar
    screen.fill((0, 0, 0))
    screen.blit(player_img, (player_x, player_y))
    if dll:
        for i in range(55):  # 5*11 = 55 enemigos
            x = c_int()
            y = c_int()
            alive = c_int()

            if get_enemigo_data(i, byref(x), byref(y), byref(alive)):
                if alive.value:
                    screen.blit(enemy_img, (x.value, y.value))

    pygame.display.flip()
    clock.tick(FPS)
    pygame.display.set_caption("Space Invaders - La prueba")
pygame.quit()