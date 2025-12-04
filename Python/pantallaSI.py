import pygame
from ctypes import *
from test_bridge import *

try:
    dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")
except Exception as e:
    print("DLL no encontrada")
    dll = None


pygame.init()
pygame.mixer.init()
pygame.mixer.music.load(r"C:\Users\Keraf\OneDrive\Documentos\GitHub\Proyecto-Final-Arqui\recursos\Expedition33_GestralBeach.mp3")
#pygame.mixer.music.play(-1)
WIDTH = 400
HEIGHT = 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Space Invaders")
player_img = pygame.image.load("recursos/naveprincipal.png").convert_alpha()
player_img = pygame.transform.scale(player_img, (50, 50))

enemy_frames = []
for i in range(1,12):
    img = pygame.image.load(f"recursos/Alien_{i:03}.png").convert_alpha()
    img = pygame.transform.scale(img, (32, 16))  # si quieres mantener tamaño
    enemy_frames.append(img)

enemy_frame_index = 0
last_anim_update = 0
anim_delay = 100

player_x = WIDTH // 2
player_y = HEIGHT - 50
player_speed = 3

# Variables para controlar disparo (evitar disparo continuo)
disparo_presionado = False
cooldown_disparo = 0  # Cooldown en frames
maximo_disparos = 5

puntuacion = 0
font = pygame.font.SysFont(None, 24)

# Crear imagen de bala (simple rectángulo verde)
def crear_bala():
    surface = pygame.Surface((5, 15), pygame.SRCALPHA)
    # Cuerpo verde
    pygame.draw.rect(surface, (0, 255, 0), (0, 0, 5, 15))
    # Centro blanco brillante
    pygame.draw.rect(surface, (200, 255, 200), (1, 3, 3, 9))
    return surface

bala_img = crear_bala()

# Inicializar juego
init_enemigos(2, 5)  # 2 filas, 5 columnas = 10 enemigos
reset_puntuacion()

# Bucle principal
clock = pygame.time.Clock()
FPS = 60
running = True
last_enemy_update = 0
enemy_delay = 1050  # ms

while running:
    current_time = pygame.time.get_ticks()
    # Eventos
    for event in pygame.event.get():
        if event.type == pygame.QUIT:
            running = False
        if event.type == pygame.KEYDOWN:
            if event.key == pygame.K_ESCAPE:
                running = False
            if event.key == pygame.K_r:  # <-- Añadí tecla R para reiniciar
                reset_puntuacion()
                init_enemigos(2, 5)
                print("Juego reiniciado")

    # Movimiento del jugador
    keys = pygame.key.get_pressed()
    direccion = 0
    if keys[pygame.K_LEFT]:
        direccion = -1
    if keys[pygame.K_RIGHT]:
        direccion = 1

    player_x = moverJugador(player_x, direccion, player_speed)
    player_x = max(0, min(player_x, WIDTH - 50))
    # Solo disparar si se presiona ESPACIO y no hay cooldown
    if keys[pygame.K_SPACE] and not disparo_presionado and cooldown_disparo == 0:
        crear_disparo_jugador(player_x, player_y)
        print(f"¡Disparo! Posición: ({player_x}, {player_y})")
        disparo_presionado = True
        cooldown_disparo = 64  # 15 frames de cooldown (~0.25 segundos)

    elif not keys[pygame.K_SPACE]:
        disparo_presionado = False

    # Reducir cooldown
    if cooldown_disparo > 0:
        cooldown_disparo -= 1

    actualizar_disparos_jugador()

    # ===== VERIFICAR COLISIONES (¡AÑADE ESTO!) =====
    enemigos_eliminados = update_colisiones()

    if enemigos_eliminados > 0 and enemigos_eliminados < 10:
        # Obtener puntuación actual desde MASM
        puntuacion = get_puntuacion()
        print(f"¡{enemigos_eliminados} enemigo(s) eliminado(s)! Puntuación: {puntuacion}")

    # ===== ACTUALIZAR ENEMIGOS =====
    if current_time - last_enemy_update >= enemy_delay:
        update_all_enemigos(WIDTH)
        last_enemy_update = current_time

    # ===== ACTUALIZAR ANIMACIÓN =====
    if current_time - last_anim_update >= anim_delay:
        enemy_frame_index = (enemy_frame_index + 1) % len(enemy_frames)
        last_anim_update = current_time

    # ===== DIBUJAR =====
    screen.fill((0, 0, 0))  # Fondo azul oscuro

    # Dibujar jugador
    screen.blit(player_img, (player_x, player_y))

    # Dibujar enemigos
    enemigos_vivos = 0
    for i in range(10):  # 10 enemigos (2x5)
        x = c_int()
        y = c_int()
        alive = c_int()

        if get_enemigo_data(i, byref(x), byref(y), byref(alive)):
            if alive.value:
                screen.blit(enemy_frames[enemy_frame_index], (x.value, y.value))
                enemigos_vivos += 1

    # Dibujar balas
    for i in range(maximo_disparos):
        x = c_int()
        y = c_int()
        active = c_int()

        if get_disparo_jugador_data(i, byref(x), byref(y), byref(active)):
            if active.value:
                # Dibujar bala como rectángulo verde
                pygame.draw.rect(screen, (0, 255, 0), (x.value, y.value, 5, 15))

        # ===== MOSTRAR INFORMACIÓN =====

    # Cooldown
    if cooldown_disparo > 0:
        texto_cooldown = f"Cooldown: {cooldown_disparo / 60:.2f}s"
        superficie_cooldown = font.render(texto_cooldown, True, (255, 200, 200))
        screen.blit(superficie_cooldown, (WIDTH - 150, 10))
    # Instrucciones
    texto_inst = "ESPACIO: Disparar | FLECHAS: Moverse | ESC: Salir"
    superficie_inst = font.render(texto_inst, True, (200, 200, 200))
    screen.blit(superficie_inst, (WIDTH // 2 - 150, HEIGHT - 30))

    # Enemigos restantes
    texto_enemigos = f"Enemigos: {enemigos_vivos}/10"
    superficie_enemigos = font.render(texto_enemigos, True, (255, 200, 200))
    screen.blit(superficie_enemigos, (WIDTH - 150, 40))

    puntuacion = get_puntuacion()  # <-- ¡ESTO ES IMPORTANTE!
    texto_puntos = f"Puntos: {puntuacion}"
    superficie_puntos = font.render(texto_puntos, True, (255, 255, 255))
    screen.blit(superficie_puntos, (10, 10))

    # Victoria si no quedan enemigos
    if enemigos_vivos == 0:
        texto_victoria = "¡VICTORIA!"
        superficie_victoria = font.render(texto_victoria, True, (0, 255, 0))
        screen.blit(superficie_victoria, (WIDTH // 2 - 60, HEIGHT // 2 - 50))
        texto_reinicio = "Presiona R para reiniciar"
        superficie_reinicio = font.render(texto_reinicio, True, (200, 200, 0))
        screen.blit(superficie_reinicio, (WIDTH // 2 - 100, HEIGHT // 2))

    pygame.display.flip()
    clock.tick(FPS)
pygame.quit()