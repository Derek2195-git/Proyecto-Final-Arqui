import pygame
import test_bridge

from ctypes import WinDLL, c_int

from test_bridge import moverJugador

# Creación de la ventana aqui
pygame.init()
pygame.mixer.init()
pygame.mixer.music.load("Expedition33_GestralBeach.mp3")
pygame.mixer.music.play(-1)
WIDTH = 100
HEIGHT = 100
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Space Invaders - La prueba")

clock = pygame.time.Clock()
FPS = 60

# Cargamos el DLL aqui
try:
    dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")
except Exception as e:
    print("DLL no encontrada, prueba solo gráfica")
    dll = None

# Datos rapidos para el jugador
player_x = WIDTH // 2
player_y = HEIGHT - 50
player_width = 50
player_height = 50
player_speed = 3

# Cargar imagen de la nave
player_img = pygame.image.load("naveprincipal.png").convert_alpha()

# (Opcional) Redimensionar si está muy grande
player_img = pygame.transform.scale(player_img, (player_width, player_height))


# Bucle de juego?
running = True
while running:
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False

    keys = pygame.key.get_pressed()
    direccion = 0
    if keys[pygame.K_LEFT]:
        direccion = -1
    if keys[pygame.K_RIGHT]:
        direccion = 1

    player_x = moverJugador(player_x, direccion, player_speed)

    if player_x < 0:
        player_x = 0
    if player_x + player_width > WIDTH:
        player_x = WIDTH - player_width

    screen.fill((0, 0, 0))
    # Jugador
    #pygame.draw.rect(screen, (40, 222, 85), (player_x, player_y, player_width, player_height))
    screen.blit(player_img, (player_x, player_y))

    pygame.display.flip()
    clock.tick(FPS)
    pygame.display.set_caption("Space Invaders - La prueba")
pygame.quit()