import pygame
from ctypes import *

from Python.test_bridge import definirValor
from test_bridge import *

pygame.init()
pygame.mixer.init()
pygame.mixer.music.load(
    r"recursos/Musica_pluto.mp3")
pygame.mixer.music.play(-1)

WIDTH = 400
HEIGHT = 600
screen = pygame.display.set_mode((WIDTH, HEIGHT))
pygame.display.set_caption("Space Invaders")
fondo = pygame.image.load("recursos/HUDSI.png").convert_alpha()
fondo = pygame.transform.scale(fondo, (WIDTH, HEIGHT))
player_img = pygame.image.load("recursos/naveprincipal.png").convert_alpha()
player_img = pygame.transform.scale(player_img, (50, 50))

enemy_frames = []
for i in range(1, 12):
    img = pygame.image.load(f"recursos/Alien_{i:03}.png").convert_alpha()
    img = pygame.transform.scale(img, (32, 16))
    enemy_frames.append(img)

enemy_frame_index = 0
MAX_ENEMIGOS = 21
POSICIONES_ENEMIGOS = (3,7)
filas, columnas = POSICIONES_ENEMIGOS
last_anim_update = 0
anim_delay = 100

player_x = WIDTH // 2
player_y = HEIGHT - 60
player_speed = 3
VIDAS_JUGADOR = 3000
game_started = False
game_over = False
LIMITE_Y_BASE = player_y - 20

# Variables para controlar disparo
disparo_presionado = False
victoria_activada = False
cooldown_disparo = 0
maximo_disparos = 5

puntuacion = 0
font = pygame.font.SysFont(None, 24)

NIVEL_ACTUAL = 1
MAX_NIVELES = 3
enemigos_eliminados_nivel = 0


def avanzar_nivel():
    global NIVEL_ACTUAL, victoria_activada, enemy_delay, shot_delay

    if NIVEL_ACTUAL < MAX_NIVELES:
        NIVEL_ACTUAL += 1

        # Establecer dificultad en MASM
        set_nivel_dificultad(NIVEL_ACTUAL)

        # Re-inicializar enemigos
        init_enemigos(filas, columnas)

        print(f"¡AVANZANDO AL NIVEL {NIVEL_ACTUAL}!")

        # Ajustar velocidades
        if NIVEL_ACTUAL == 2:
            enemy_delay = 600
            shot_delay = 450
        elif NIVEL_ACTUAL == 3:
            enemy_delay = 450
            shot_delay = 300

        # El jugador mantiene sus vidas actuales (o puedes resetear a 3 si quieres)
        # VIDAS_JUGADOR = 3  # Opcional

    else:
        print("¡HAS COMPLETADO TODOS LOS NIVELES!")

    # Resetear bandera de victoria
    victoria_activada = False

# Crear imagen de bala
def crear_bala():
    surface = pygame.Surface((5, 15), pygame.SRCALPHA)
    pygame.draw.rect(surface, (0, 255, 0), (0, 0, 5, 15))
    pygame.draw.rect(surface, (200, 255, 200), (1, 3, 3, 9))
    return surface

bala_img = crear_bala()

# Inicializar juego
init_enemigos(filas, columnas)
reset_puntuacion()

# Bucle principal
clock = pygame.time.Clock()
FPS = 60
running = True
victoria = False
victoria_tiempo = 0
last_enemy_update = 0
enemy_delay = 50  # tiempo entre cada movimiento del enemigo
last_shot_update = 0  # <-- Añade esto para control de disparos enemigos
shot_delay = 580  # <-- Disparos enemigos cada 400ms

while running:
    if not game_started:
        screen.blit(fondo, (0, 0))

        texto_inicio = font.render("Presiona ENTER para comenzar", True, (255, 255, 255))
        screen.blit(texto_inicio, (WIDTH // 2 - 140, HEIGHT // 2))

        pygame.display.flip()

        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN and event.key == pygame.K_RETURN:
                game_started = True
                # Inicializa enemigos al empezar
                init_enemigos(filas, columnas)
                reset_puntuacion()
        clock.tick(FPS)
        continue
    if not game_over:
        current_time = pygame.time.get_ticks()

        # Eventos
        for event in pygame.event.get():
            if event.type == pygame.QUIT:
                running = False
            if event.type == pygame.KEYDOWN:
                if event.key == pygame.K_ESCAPE:
                    running = False
                if event.key == pygame.K_r and victoria == True:  # Reiniciar

                    init_enemigos(filas, columnas)
                    VIDAS_JUGADOR = 3
                    game_over = False
                    player_x = WIDTH // 2
                    print("Juego reiniciado")

        # Movimiento del jugador
        keys = pygame.key.get_pressed()
        direccion = 0
        if keys[pygame.K_LEFT]:
            direccion = definirValor(-1)
        if keys[pygame.K_RIGHT]:
            direccion = definirValor(1)

        player_x = moverJugador(player_x, direccion, player_speed)
        player_x = max(0, min(player_x, WIDTH - 50))

        # Disparo jugador
        if keys[pygame.K_SPACE] and not disparo_presionado and cooldown_disparo == 0:
            crear_disparo_jugador(player_x, player_y)
            disparo_presionado = True
            cooldown_disparo = definirValor(30)

        elif not keys[pygame.K_SPACE]:
            disparo_presionado = False

        # Reducir cooldown
        if cooldown_disparo > 0:
            cooldown_disparo = definirValor(cooldown_disparo-1)

        # ===== ACTUALIZAR DISPAROS =====
        actualizar_disparos_jugador()  # Mover balas jugador
        actualizar_disparos_enemigos()  # Mover balas enemigas CADA FRAME
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
            print(f"Vidas restantes: {VIDAS_JUGADOR}")
        if VIDAS_JUGADOR <= 0:
            game_over = True
            print("¡GAME OVER!")

            # ===== VERIFICAR SI ENEMIGOS LLEGARON A LA BASE =====
        if check_enemigos_en_base(LIMITE_Y_BASE):
            VIDAS_JUGADOR = 0
            game_over = True
            print("¡Los enemigos llegaron a la base! GAME OVER")

        # ===== ACTUALIZAR ANIMACIÓN =====
        if current_time - last_anim_update >= anim_delay:
            enemy_frame_index = (enemy_frame_index + 1) % len(enemy_frames)
            last_anim_update = current_time

        # ===== DIBUJAR =====
        screen.blit(fondo, (0, 0))
        # Dibujar jugador
        screen.blit(player_img, (player_x, player_y))

        # Dibujar enemigos
        enemigos_vivos = 0
        for i in range(MAX_ENEMIGOS):
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
        screen.blit(superficie_vidas, (WIDTH - 90, 20))

        # Zona segura

        # ===== MOSTRAR INFORMACIÓN =====
        # Vidas
        texto_zona_segura = f"SI LOS ALIENS LLEGAN AQUI PIERDES"
        superficie_zona_segura = font.render(texto_zona_segura, True, (250, 67, 121))
        screen.blit(superficie_zona_segura, (WIDTH/10 + 5, LIMITE_Y_BASE))

        # Enemigos restantes
        texto_enemigos = f"{enemigos_vivos}/{MAX_ENEMIGOS}"
        superficie_enemigos = font.render(texto_enemigos, True, (255, 200, 200))
        screen.blit(superficie_enemigos, (WIDTH - 70, 45))

        # Puntuación
        puntuacion = get_puntuacion()
        texto_puntos = f"Puntos: {puntuacion}"
        superficie_puntos = font.render(texto_puntos, True, (255, 255, 255))
        screen.blit(superficie_puntos, (20, 17))


        # Victoria
        if enemigos_vivos == 0 and not victoria_activada:
            victoria_activada = True
            victoria_tiempo = current_time  # Solo se establece UNA VEZ

        if victoria_activada:
            if NIVEL_ACTUAL < MAX_NIVELES:
                segundos_transcurridos = (current_time - victoria_tiempo) // 1000
                segundos_restantes = max(0, 3 - segundos_transcurridos)

                texto_victoria = f"¡NIVEL {NIVEL_ACTUAL} COMPLETADO!"
                superficie_victoria = font.render(texto_victoria, True, (0, 255, 0))
                screen.blit(superficie_victoria, (WIDTH // 2 - 100, HEIGHT // 2 - 50))
                if segundos_restantes > 0:
                    texto_siguiente = f"Siguiente nivel en {segundos_restantes}..."
                    superficie_siguiente = font.render(texto_siguiente, True, (200, 200, 0))
                    screen.blit(superficie_siguiente, (WIDTH // 2 - 120, HEIGHT // 2))
                else:
                    # Avanzar automáticamente después de 3 segundos
                    avanzar_nivel()
                    victoria_activada = False  # Resetear para el nuevo nivel
            else:
                texto_victoria = "¡VICTORIA!"
                superficie_victoria = font.render(texto_victoria, True, (0, 255, 0))
                screen.blit(superficie_victoria, (WIDTH // 2 - 60, HEIGHT // 2 - 50))
                texto_reinicio = "Presiona R para avanzar a otro nivel"
                victoria = True
                superficie_reinicio = font.render(texto_reinicio, True, (200, 200, 0))
                screen.blit(superficie_reinicio, (WIDTH // 2 - 160, HEIGHT // 2))


        # Game Over
        if game_over:
            texto_gameover = "GAME OVER"
            superficie_gameover = font.render(texto_gameover, True, (255, 0, 0))
            screen.blit(superficie_gameover, (WIDTH // 2 - 60, HEIGHT // 2 - 50))
            victoria = False
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

                    init_enemigos(filas, columnas)
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