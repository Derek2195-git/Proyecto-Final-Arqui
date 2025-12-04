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
pygame.mixer.music.load(
    r"C:\Users\Keraf\OneDrive\Documentos\GitHub\Proyecto-Final-Arqui\recursos\Expedition33_GestralBeach.mp3")
# pygame.mixer.music.play(-1)

WIDTH = 400
HEIGHT = 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Space Invaders")

player_img = pygame.image.load("recursos/naveprincipal.png").convert_alpha()
player_img = pygame.transform.scale(player_img, (50, 50))

enemy_frames = []
for i in range(1, 12):
    img = pygame.image.load(f"recursos/Alien_{i:03}.png").convert_alpha()
    img = pygame.transform.scale(img, (32, 16))
    enemy_frames.append(img)

enemy_frame_index = 0
last_anim_update = 0
anim_delay = 100

player_x = WIDTH // 2
player_y = HEIGHT - 50
player_speed = 3
VIDAS_JUGADOR = 3
game_over = False

# Variables para controlar disparo
disparo_presionado = False
cooldown_disparo = 0
maximo_disparos = 5

puntuacion = 0
font = pygame.font.SysFont(None, 24)


# Crear imagen de bala
def crear_bala():
    surface = pygame.Surface((5, 15), pygame.SRCALPHA)
    pygame.draw.rect(surface, (0, 255, 0), (0, 0, 5, 15))
    pygame.draw.rect(surface, (200, 255, 200), (1, 3, 3, 9))
    return surface


# Versión de debugging para colisiones
def debug_colisiones():
    player_rect = pygame.Rect(player_x, player_y, 50, 50)

    for i in range(20):
        x = c_int()
        y = c_int()
        active = c_int()

        if get_disparo_enemigo_data(i, byref(x), byref(y), byref(active)):
            if active.value:
                bala_rect = pygame.Rect(x.value, y.value, 5, 15)

                # Dibujar rectángulos de debug
                pygame.draw.rect(screen, (255, 255, 0), player_rect, 2)  # Amarillo para jugador
                pygame.draw.rect(screen, (255, 0, 255), bala_rect, 2)  # Magenta para balas

                # Verificar colisión manualmente
                if player_rect.colliderect(bala_rect):
                    print(f"¡COLISIÓN MANUAL DETECTADA! Bala {i} en ({x.value}, {y.value})")
                    return True
    return False

bala_img = crear_bala()

# Inicializar juego
init_enemigos(2, 5)
reset_puntuacion()

# Bucle principal
clock = pygame.time.Clock()
FPS = 60
running = True
last_enemy_update = 0
enemy_delay = 760  # ms
last_shot_update = 0  # <-- Añade esto para control de disparos enemigos
shot_delay = 580  # <-- Disparos enemigos cada 400ms

while running:
    if not game_over:
        current_time = pygame.time.get_ticks()

        # Eventos
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                if event.key == pygame.K_r:  # Reiniciar
                    reset_puntuacion()
                    init_enemigos(2, 5)
                    VIDAS_JUGADOR = 3
                    game_over = False
                    player_x = WIDTH // 2
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

        # Disparo jugador
        if keys[pygame.K_SPACE] and not disparo_presionado and cooldown_disparo == 0:
            crear_disparo_jugador(player_x, player_y)
            disparo_presionado = True
            cooldown_disparo = 64

        elif not keys[pygame.K_SPACE]:
            disparo_presionado = False

        # Reducir cooldown
        if cooldown_disparo > 0:
            cooldown_disparo -= 1

        # ===== ACTUALIZAR DISPAROS =====
        actualizar_disparos_jugador()  # Mover balas jugador
        actualizar_disparos_enemigos()  # Mover balas enemigas CADA FRAME

        colision_masm = check_colision_bala_enemigo_jugador(int(player_x), int(player_y), 50, 50)
        if colision_masm:
            VIDAS_JUGADOR -= 1

        # ===== ACTUALIZAR ENEMIGOS =====
        if current_time - last_enemy_update >= enemy_delay:
            update_all_enemigos(WIDTH)
            last_enemy_update = current_time

        # ===== DISPAROS ENEMIGOS (separado del movimiento) =====
        if current_time - last_shot_update >= shot_delay:
            intentar_disparo_enemigo()
            last_shot_update = current_time

        # ===== VERIFICAR COLISIONES =====
        # 1. Balas jugador -> Enemigos
        enemigos_eliminados = update_colisiones()
        if enemigos_eliminados > 0:
            puntuacion = get_puntuacion()
            print(f"¡{enemigos_eliminados} enemigo(s) eliminado(s)! Puntuación: {puntuacion}")

        # 2. Balas enemigas -> Jugador
        if check_colision_bala_enemigo_jugador(int(player_x), int(player_y), 50, 50):
            VIDAS_JUGADOR -= 1
            print(f"¡Impactado! Vidas restantes: {VIDAS_JUGADOR}")

        if VIDAS_JUGADOR <= 0:
            game_over = True
            print("¡GAME OVER!")

        # ===== ACTUALIZAR ANIMACIÓN =====
        if current_time - last_anim_update >= anim_delay:
            enemy_frame_index = (enemy_frame_index + 1) % len(enemy_frames)
            last_anim_update = current_time

        # ===== DIBUJAR =====
        screen.fill((0, 0, 0))

        # Dibujar jugador
        screen.blit(player_img, (player_x, player_y))

        # Dibujar enemigos
        enemigos_vivos = 0
        for i in range(10):
            x = c_int()
            y = c_int()
            alive = c_int()

            if get_enemigo_data(i, byref(x), byref(y), byref(alive)):
                if alive.value:
                    screen.blit(enemy_frames[enemy_frame_index], (x.value, y.value))
                    enemigos_vivos += 1

        # Dibujar balas jugador
        for i in range(maximo_disparos):
            x = c_int()
            y = c_int()
            active = c_int()

            if get_disparo_jugador_data(i, byref(x), byref(y), byref(active)):
                if active.value:
                    pygame.draw.rect(screen, (0, 255, 0), (x.value, y.value, 5, 15))

        # Dibujar balas enemigas
        for i in range(20):
            x = c_int()
            y = c_int()
            active = c_int()

            if get_disparo_enemigo_data(i, byref(x), byref(y), byref(active)):
                if active.value:
                    pygame.draw.rect(screen, (255, 50, 50), (x.value, y.value, 5, 15))

        # ===== MOSTRAR INFORMACIÓN =====
        # Vidas
        texto_vidas = f"Vidas: {VIDAS_JUGADOR}"
        superficie_vidas = font.render(texto_vidas, True, (255, 100, 100))
        screen.blit(superficie_vidas, (WIDTH - 150, 70))

        # Cooldown
        if cooldown_disparo > 0:
            texto_cooldown = f"Cooldown: {cooldown_disparo / 60:.2f}s"
            superficie_cooldown = font.render(texto_cooldown, True, (255, 200, 200))
            screen.blit(superficie_cooldown, (WIDTH - 150, 10))

        # Enemigos restantes
        texto_enemigos = f"Enemigos: {enemigos_vivos}/10"
        superficie_enemigos = font.render(texto_enemigos, True, (255, 200, 200))
        screen.blit(superficie_enemigos, (WIDTH - 150, 40))

        # Puntuación
        puntuacion = get_puntuacion()
        texto_puntos = f"Puntos: {puntuacion}"
        superficie_puntos = font.render(texto_puntos, True, (255, 255, 255))
        screen.blit(superficie_puntos, (10, 10))

        # Instrucciones
        texto_inst = "ESPACIO: Disparar | FLECHAS: Moverse | ESC: Salir | R: Reiniciar"
        superficie_inst = font.render(texto_inst, True, (200, 200, 200))
        screen.blit(superficie_inst, (WIDTH // 2 - 180, HEIGHT - 30))

        # Victoria
        if enemigos_vivos == 0:
            texto_victoria = "¡VICTORIA!"
            superficie_victoria = font.render(texto_victoria, True, (0, 255, 0))
            screen.blit(superficie_victoria, (WIDTH // 2 - 60, HEIGHT // 2 - 50))
            texto_reinicio = "Presiona R para reiniciar"
            superficie_reinicio = font.render(texto_reinicio, True, (200, 200, 0))
            screen.blit(superficie_reinicio, (WIDTH // 2 - 100, HEIGHT // 2))

        # Game Over
        if game_over:
            texto_gameover = "GAME OVER"
            superficie_gameover = font.render(texto_gameover, True, (255, 0, 0))
            screen.blit(superficie_gameover, (WIDTH // 2 - 60, HEIGHT // 2 - 50))
            texto_reinicio = "Presiona R para reiniciar"
            superficie_reinicio = font.render(texto_reinicio, True, (200, 200, 0))
            screen.blit(superficie_reinicio, (WIDTH // 2 - 100, HEIGHT // 2))

    else:  # Si game_over = True
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                if event.key == pygame.K_r:  # Reiniciar desde game over
                    reset_puntuacion()
                    init_enemigos(2, 5)
                    VIDAS_JUGADOR = 3
                    game_over = False
                    player_x = WIDTH // 2
                    print("Juego reiniciado")

        # Mostrar pantalla de game over
        screen.fill((0, 0, 0))
        texto_gameover = "GAME OVER"
        superficie_gameover = font.render(texto_gameover, True, (255, 0, 0))
        screen.blit(superficie_gameover, (WIDTH // 2 - 60, HEIGHT // 2 - 50))

        texto_puntos_final = f"Puntuación final: {puntuacion}"
        superficie_puntos_final = font.render(texto_puntos_final, True, (255, 255, 255))
        screen.blit(superficie_puntos_final, (WIDTH // 2 - 80, HEIGHT // 2))

        texto_reinicio = "Presiona R para reiniciar"
        superficie_reinicio = font.render(texto_reinicio, True, (200, 200, 0))
        screen.blit(superficie_reinicio, (WIDTH // 2 - 100, HEIGHT // 2 + 50))

        texto_salir = "Presiona ESC para salir"
        superficie_salir = font.render(texto_salir, True, (200, 200, 200))
        screen.blit(superficie_salir, (WIDTH // 2 - 100, HEIGHT // 2 + 80))

    pygame.display.flip()
    clock.tick(FPS)

pygame.quit()