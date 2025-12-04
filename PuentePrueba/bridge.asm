; bridge.asm
.386
.model flat, stdcall
.stack 4096


; Definir estructura
EnemigoSI STRUCT
    x           DWORD ?
    y           DWORD ?
    speed       DWORD ?
    direction   DWORD ?
    is_alive    DWORD ?
EnemigoSI ENDS

DisparoJugador STRUCT
    x           DWORD ?
    y           DWORD ?
    is_active   DWORD ?    ; 0 = inactivo, 1 = activo
    speed       DWORD ?
    tipo        DWORD ?    ; 0 = jugador, 1 = enemigo
DisparoJugador ENDS



SIZE_ENEMIGO EQU 20  ; 5 campos * 4 bytes = 20 bytes

SIZE_DISPARO_JUGADOR EQU 20  ; 5 campos * 4 bytes

MAX_DISPAROS_JUGADOR EQU 5   ; M?ximo 5 balas en pantalla
MAX_DISPAROS_ENEMIGOS EQU 20
HEIGHT_SCREEN EQU 600
.data
MAX_ENEMIGOS EQU 21
; Tama?os de sprites
ENEMY_WIDTH EQU 32    ; Ancho del enemigo
ENEMY_HEIGHT EQU 16   ; Alto del enemigo
BULLET_WIDTH EQU 5    ; Ancho de la bala
BULLET_HEIGHT EQU 15  ; Alto de la bala

; Espaciado entre enemigos
ENEMY_SPACING_X EQU 40   ; 40 p?xeles entre enemigos (32 + 8)
ENEMY_SPACING_Y EQU 25   ; 25 p?xeles entre filas (16 + 9)

; Arrays de disparos
disparos_enemigos DisparoJugador MAX_DISPAROS_ENEMIGOS DUP(<>)
disparos_jugador DisparoJugador MAX_DISPAROS_JUGADOR DUP(<>)

disparo_timer DWORD 0
DISPARO_INTERVAL EQU 120  ; Frames entre disparos (2 segundos a 60 FPS)
PROBABILIDAD_DISPARO EQU 15  ; 15% de probabilidad por enemigo

; Puntuacion
puntuacion_actual DWORD 0
puntos_por_enemigo DWORD 1000


; Array de enemigos
enemigos_array EnemigoSI MAX_ENEMIGOS DUP(<>)
enemigo_count DWORD 0

; Variables para la formacion
formation_direction DWORD 1  ; 1 = derecha, -1 = izquierda
should_descend DWORD 0       ; 0 = no, 1 = s? bajar
formation_speed DWORD 7
descenso_distancia DWORD 20  ; Cuánto bajan al tocar bordes

left_bound DWORD 9999
right_bound DWORD -9999


; ===== VARIABLES DE DIFICULTAD =====
nivel_dificultad DWORD 1  ; Nivel actual (1 = fácil, 2 = medio, 3 = difícil)
velocidad_base DWORD 7    ; Velocidad base de los enemigos
velocidad_disparos_enemigos DWORD 5  ; Velocidad base de balas enemigas
probabilidad_disparo_base DWORD 15   ; Probabilidad base de disparo (%)

.code
PUBLIC pruebaPuente, moverJugadorAsm, definirValorAsm
PUBLIC actualizarPosicionEnemigosAsm, initEnemigos, updateAllEnemigos, getEnemigoData
PUBLIC crearDisparoJugador, actualizarDisparosJugador, getDisparoJugadorData
PUBLIC checkColisionBalaEnemigo, updateColisiones, getEnemigosVivos
PUBLIC getPuntuacion, addPuntuacion, resetPuntuacion, checkColisionConPuntos
PUBLIC crearDisparoEnemigo, actualizarDisparosEnemigos, getDisparoEnemigoData, intentarDisparoEnemigo
PUBLIC checkColisionBalaEnemigoJugador, checkColisionEnemigoJugador, checkEnemigosEnBase
PUBLIC getNivelDificultad, setNivelDificultad, actualizarDificultad

; Esta es la primera funcion que hice, por miedo a que le pasara algo a mi archivo la mantuve, no fue la mejor idea tbh
pruebaPuente PROC a:DWORD, b:DWORD
    mov eax, a
    add eax, b
    ret 8
pruebaPuente ENDP
; ===== MODIFICAR initEnemigos para usar formation_speed =====
initEnemigos PROC rows:DWORD, cols:DWORD
    PUSH ebx
    PUSH esi
    PUSH edi
    PUSH ecx
    
    ; Calcular total de enemigos
    MOV eax, rows
    MOV ebx, cols
    MUL ebx
    MOV enemigo_count, eax
    
    ; Establecer nivel inicial (fácil)
    MOV nivel_dificultad, 1
    CALL actualizarDificultad
    
    XOR ecx, ecx

init_loop:
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]

    ; Calcular fila y columna
    MOV eax, ecx
    XOR edx, edx
    DIV cols

    ; Guardar fila
    PUSH eax
    
    ; Calcular x
    MOV eax, edx
    MOV ebx, ENEMY_SPACING_X
    MUL ebx
    ADD eax, 30
    MOV [esi + EnemigoSI.x], eax
    
    ; Calcular y
    POP eax
    MOV ebx, ENEMY_SPACING_Y
    MUL ebx
    ADD eax, 120
    MOV [esi + EnemigoSI.y], eax
    
    ; Configurar velocidad actual (usar formation_speed)
    MOV eax, formation_speed
    MOV [esi + EnemigoSI.speed], eax
    
    MOV eax, formation_direction
    MOV [esi + EnemigoSI.direction], eax
    
    MOV DWORD PTR [esi + EnemigoSI.is_alive], 1

    INC ecx
    CMP ecx, enemigo_count
    JL init_loop
    
    POP ecx
    POP edi
    POP esi
    POP ebx
    RET 8
initEnemigos ENDP

; ===== VERIFICAR L?MITES DE LA FORMACI?N =====
checkFormationBounds PROC
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    MOV left_bound, 9999
    MOV right_bound, -9999

    XOR ecx, ecx
    
bounds_loop:
    ; Calcular posici?n en array
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; Solo enemigos vivos
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE bounds_next
    
    ; Obtener posici?n x
    MOV eax, [esi + EnemigoSI.x]
    
    ; Actualizar l?mite izquierdo
    CMP eax, left_bound
    JGE check_right
    MOV left_bound, eax
    
check_right:
    ; Actualizar l?mite derecho
    CMP eax, right_bound
    JLE bounds_next
    MOV right_bound, eax

bounds_next:
    INC ecx
    CMP ecx, enemigo_count
    JL bounds_loop
    
    POP ecx
    POP esi
    POP ebx
    RET
checkFormationBounds ENDP

; ===== MODIFICAR updateAllEnemigos para usar descenso_distancia =====
updateAllEnemigos PROC ancho_pantalla:DWORD
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    ; 1. Actualizar dificultad según enemigos restantes
    CALL actualizarDificultad
    
    ; 2. Encontrar límites de la formación
    CALL checkFormationBounds
    
    ; 3. Verificar si la formación tocó los bordes
    MOV eax, left_bound
    MOV edx, right_bound
    
    ; Verificar límite izquierdo
    CMP eax, 10
    JG check_right_bound
    
    ; Tocó límite izquierdo
    MOV formation_direction, 1
    MOV should_descend, 1
    JMP update_enemies

check_right_bound:
    ; Verificar límite derecho
    ADD edx, ENEMY_WIDTH
    CMP edx, ancho_pantalla
    JL update_enemies
    
    ; Tocó límite derecho
    MOV formation_direction, -1
    MOV should_descend, 1
    
update_enemies:
    ; 4. Actualizar cada enemigo
    XOR ecx, ecx

update_loop:
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE next_enemigo

    ; Actualizar velocidad según dificultad actual
    MOV eax, formation_speed
    MOV [esi + EnemigoSI.speed], eax

    ; Mover en X
    MOV eax, [esi + EnemigoSI.x]
    MOV ebx, [esi + EnemigoSI.speed]
    MOV edx, formation_direction
    IMUL ebx, edx
    ADD eax, ebx
    MOV [esi + EnemigoSI.x], eax

    ; Actualizar dirección
    MOV eax, formation_direction
    MOV [esi + EnemigoSI.direction], eax
    
    ; Descenso si está activado
    CMP should_descend, 0
    JE next_enemigo
    
    ; Bajar enemigo (distancia según dificultad)
    MOV eax, [esi + EnemigoSI.y]
    ADD eax, descenso_distancia
    MOV [esi + EnemigoSI.y], eax
    
next_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL update_loop
    
    ; Desactivar descenso
    MOV should_descend, 0
    
    POP ecx
    POP esi
    POP ebx
    RET 4
updateAllEnemigos ENDP

; ===== OBTENER DATOS DE UN ENEMIGO =====
getEnemigoData PROC index:DWORD, out_x:PTR DWORD, out_y:PTR DWORD, out_alive:PTR DWORD
    MOV eax, index
    CMP eax, enemigo_count
    JGE error
    
    ; Calcular posici?n en array
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; Devolver datos
    MOV eax, [esi + EnemigoSI.x]
    MOV edx, out_x
    MOV [edx], eax
    
    MOV eax, [esi + EnemigoSI.y]
    MOV edx, out_y
    MOV [edx], eax
    
    MOV eax, [esi + EnemigoSI.is_alive]
    MOV edx, out_alive
    MOV [edx], eax
    
    MOV eax, 1  ; ?xito
    RET
    
error:
    XOR eax, eax  ; error
    RET 16
getEnemigoData ENDP

moverJugadorAsm PROC posActual:DWORD, direccion:DWORD, speed:DWORD
    MOV eax, posActual
    CMP direccion, -1
    JE mover_izquierda
    CMP direccion, 1
    JE mover_derecha
    JMP terminar_movimiento
    
mover_izquierda:
    SUB eax, speed
    JMP terminar_movimiento
    
mover_derecha:
    ADD eax, speed
    
terminar_movimiento:
    RET 12
moverJugadorAsm ENDP

definirValorAsm PROC valor:DWORD
    MOV eax, valor
    RET 4
definirValorAsm ENDP

actualizarPosicionEnemigosAsm PROC pos_x:PTR DWORD, pos_y:PTR DWORD, velocidad:DWORD, dir:PTR DWORD, ancho:DWORD
    PUSH ebx
    PUSH esi
    PUSH edi

    ; Cargar punteros
    MOV esi, pos_x      ; esi = &x
    MOV edi, pos_y      ; edi = &y
    MOV ebx, dir        ; ebx = &direction
    
    ; Self.x += self.speed * self.direction
    MOV eax, [esi]      ; eax = x actual
    MOV ecx, velocidad  ; ecx = velocidad
    MOV edx, [ebx]      ; edx = direcci?n (1 o -1)

    IMUL ecx, edx       ; ecx = velocidad * direcci?n
    ADD eax, ecx        ; eax = x + velocidad * direcci?n
    
    ; Guardar nuevo x
    MOV [esi], eax

    ; ===== VERIFICAR L?MITES =====
    
    ; Primero verificar l?mite izquierdo (x <= 0)
    CMP eax, 0
    JG verificar_derecho  ; Si x > 0, saltar a verificar derecho
    
    ; ===== TOC? L?MITE IZQUIERDO =====
    MOV edx, [ebx]      ; Cargar direcci?n actual
    NEG edx             ; Invertir direcci?n
    MOV [ebx], edx      ; Guardar nueva direcci?n
    
    ; Mover hacia abajo
    MOV ecx, [edi]      ; Cargar y actual
    ADD ecx, 20         ; A?adir 20 p?xeles
    MOV [edi], ecx      ; Guardar nuevo y
    
    ; Corregir x para que no sea negativo
    MOV DWORD PTR [esi], 0
    JMP fin_funcion
    
verificar_derecho:
    ; Verificar l?mite derecho (x >= ancho - 50)
    MOV edx, ancho      ; Cargar ancho de pantalla
    SUB edx, 50         ; Restar ancho del sprite
    
    CMP eax, edx        ; Comparar x con (ancho - 50)
    JL fin_funcion      ; Si x < (ancho-50), terminar
    
    ; ===== TOC? L?MITE DERECHO =====
    MOV edx, [ebx]      ; Cargar direcci?n actual
    NEG edx             ; Invertir direcci?n
    MOV [ebx], edx      ; Guardar nueva direcci?n
    
    ; Mover hacia abajo
    MOV ecx, [edi]      ; Cargar y actual
    ADD ecx, 20         ; A?adir 20 p?xeles
    MOV [edi], ecx      ; Guardar nuevo y
    
    ; Corregir x para que no se salga
    MOV eax, ancho
    SUB eax, 50
    MOV [esi], eax
    
fin_funcion:
    POP edi
    POP esi
    POP ebx
    RET 20
actualizarPosicionEnemigosAsm ENDP

crearDisparoJugador PROC pos_x:DWORD, pos_y:DWORD
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    ; Buscar slot libre
    XOR ecx, ecx
    
buscar_slot_jugador:    
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_jugador[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE slot_encontrado_jugador
    
    INC ecx
    CMP ecx, MAX_DISPAROS_JUGADOR
    JL buscar_slot_jugador
    
    ; No hay slots disponibles
    JMP fin_crear_jugador
    
slot_encontrado_jugador:
    ; Configurar disparo
    MOV eax, pos_x
    ADD eax, 25          ; Centrar en la nave (asumiendo nave de 50px)
    SUB eax, 2
    MOV [esi + DisparoJugador.x], eax
    
    MOV eax, pos_y
    SUB eax, 15
    MOV [esi + DisparoJugador.y], eax
    
    MOV DWORD PTR [esi + DisparoJugador.is_active], 1
    MOV DWORD PTR [esi + DisparoJugador.speed], 8
    
fin_crear_jugador:
    POP ecx
    POP esi
    POP ebx
    RET 8
crearDisparoJugador ENDP

; actualizarDisparosJugador: mueve todos los disparos activos
actualizarDisparosJugador PROC
    PUSH esi
    PUSH ecx
    
    XOR ecx, ecx
    
actualizar_loop_jugador:
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_jugador[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE siguiente_jugador
    
    ; Mover disparo hacia arriba
    MOV eax, [esi + DisparoJugador.y]
    SUB eax, [esi + DisparoJugador.speed]
    MOV [esi + DisparoJugador.y], eax
    
    ; Verificar si sali? de pantalla (arriba)
    CMP eax, 0
    JG siguiente_jugador
    
    ; Desactivar si sali?
    MOV DWORD PTR [esi + DisparoJugador.is_active], 0
    
siguiente_jugador:
    INC ecx
    CMP ecx, MAX_DISPAROS_JUGADOR
    JL actualizar_loop_jugador
    
    POP ecx
    POP esi
    RET
actualizarDisparosJugador ENDP

; getDisparoJugadorData: obtiene datos de un disparo del jugador
getDisparoJugadorData PROC index:DWORD, out_x:PTR DWORD, out_y:PTR DWORD, out_active:PTR DWORD
    MOV eax, index
    CMP eax, MAX_DISPAROS_JUGADOR
    JGE error_jugador
    
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_jugador[eax]
    
    MOV eax, [esi + DisparoJugador.x]
    MOV ebx, out_x
    MOV [ebx], eax
    
    MOV eax, [esi + DisparoJugador.y]
    MOV ebx, out_y
    MOV [ebx], eax
    
    MOV eax, [esi + DisparoJugador.is_active]
    MOV ebx, out_active
    MOV [ebx], eax
    
    MOV eax, 1
    RET
    
error_jugador:
    XOR eax, eax
    RET 16
getDisparoJugadorData ENDP
; ===== DETECCIÓN DE COLISIONES CON PUNTUACIÓN (VERSIÓN SIMPLIFICADA) =====
checkColisionBalaEnemigo PROC
    PUSH ebx
    PUSH esi
    PUSH edi
    PUSH ecx
    
    ; Para cada bala
    XOR ecx, ecx
    
simple_bala_loop:
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_jugador[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE simple_siguiente_bala
    
    ; Guardar índice de bala
    PUSH ecx
    
    ; Para cada enemigo
    XOR ecx, ecx
    
simple_enemigo_loop:
    MOV eax, ecx
    MOV ebx, SIZE_ENEMIGO
    MUL ebx
    LEA edi, enemigos_array[eax]
    
    CMP DWORD PTR [edi + EnemigoSI.is_alive], 0
    JE simple_siguiente_enemigo
    
    ; Verificar colisión
    MOV eax, [esi + DisparoJugador.x]
    ADD eax, BULLET_WIDTH
    CMP eax, [edi + EnemigoSI.x]
    JLE simple_siguiente_enemigo
    
    MOV eax, [edi + EnemigoSI.x]
    ADD eax, ENEMY_WIDTH
    CMP eax, [esi + DisparoJugador.x]
    JLE simple_siguiente_enemigo
    
    MOV eax, [esi + DisparoJugador.y]
    ADD eax, BULLET_HEIGHT
    CMP eax, [edi + EnemigoSI.y]
    JLE simple_siguiente_enemigo
    
    MOV eax, [edi + EnemigoSI.y]
    ADD eax, ENEMY_HEIGHT
    CMP eax, [esi + DisparoJugador.y]
    JLE simple_siguiente_enemigo
    
    ; ¡COLISIÓN!
    MOV DWORD PTR [edi + EnemigoSI.is_alive], 0
    MOV DWORD PTR [esi + DisparoJugador.is_active], 0
    
    ; Sumar puntos directamente
    ADD puntuacion_actual, 1000  ; o usa la variable puntos_por_enemigo
    
    ; Salir del loop de enemigos (esta bala ya colisionó)
    POP ecx
    JMP simple_siguiente_bala
    
simple_siguiente_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL simple_enemigo_loop
    
    ; Terminamos de revisar todos los enemigos para esta bala
    POP ecx
    
simple_siguiente_bala:
    INC ecx
    CMP ecx, MAX_DISPAROS_JUGADOR
    JL simple_bala_loop
    
    ; Retornar 0 (ya no nos importa el contador)
    XOR eax, eax
    
    POP ecx
    POP edi
    POP esi
    POP ebx
    RET
checkColisionBalaEnemigo ENDP

; Y cambia updateColisiones para usar esta:
updateColisiones PROC
    CALL checkColisionBalaEnemigo
    RET
updateColisiones ENDP

; ===== FUNCIÓN PARA OBTENER CANTIDAD DE ENEMIGOS VIVOS =====
; Retorna en eax: cantidad de enemigos vivos
getEnemigosVivos PROC
    PUSH esi
    PUSH ecx
    
    XOR eax, eax        ; contador
    XOR ecx, ecx        ; índice
    
vivos_loop:
    MOV edx, ecx
    IMUL edx, SIZE_ENEMIGO
    LEA esi, enemigos_array[edx]
    
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 1
    JNE siguiente_vivo
    INC eax
    
siguiente_vivo:
    INC ecx
    CMP ecx, enemigo_count
    JL vivos_loop
    
    POP ecx
    POP esi
    RET
getEnemigosVivos ENDP

; getPuntuacion: retorna la puntuación actual
getPuntuacion PROC
    MOV eax, puntuacion_actual
    RET
getPuntuacion ENDP

; addPuntuacion: añade puntos a la puntuación
addPuntuacion PROC puntos:DWORD
    MOV eax, puntos
    ADD puntuacion_actual, eax
    RET 4
addPuntuacion ENDP

; resetPuntuacion: reinicia la puntuación a 0
resetPuntuacion PROC
    MOV puntuacion_actual, 0
    RET
resetPuntuacion ENDP

; ===== FUNCIÓN DE COLISIÓN CON PUNTUACIÓN =====
checkColisionConPuntos PROC
    PUSH ebx
    PUSH esi
    PUSH edi
    PUSH ecx
    PUSH edx
    
    XOR edx, edx        ; edx = contador de eliminados
    
    ; Para cada bala
    XOR ecx, ecx
    
p_bala_loop:
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_jugador[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE p_siguiente_bala
    
    PUSH ecx
    XOR ecx, ecx
    
p_enemigo_loop:
    MOV eax, ecx
    MOV ebx, SIZE_ENEMIGO
    MUL ebx
    LEA edi, enemigos_array[eax]
    
    CMP DWORD PTR [edi + EnemigoSI.is_alive], 0
    JE p_siguiente_enemigo
    
    ; Verificar colisión
    MOV eax, [esi + DisparoJugador.x]
    ADD eax, BULLET_WIDTH
    CMP eax, [edi + EnemigoSI.x]
    JLE p_siguiente_enemigo
    
    MOV eax, [edi + EnemigoSI.x]
    ADD eax, ENEMY_WIDTH
    CMP eax, [esi + DisparoJugador.x]
    JLE p_siguiente_enemigo
    
    MOV eax, [esi + DisparoJugador.y]
    ADD eax, BULLET_HEIGHT
    CMP eax, [edi + EnemigoSI.y]
    JLE p_siguiente_enemigo
    
    MOV eax, [edi + EnemigoSI.y]
    ADD eax, ENEMY_HEIGHT
    CMP eax, [esi + DisparoJugador.y]
    JLE p_siguiente_enemigo
    
    ; ¡COLISIÓN!
    MOV DWORD PTR [edi + EnemigoSI.is_alive], 0
    MOV DWORD PTR [esi + DisparoJugador.is_active], 0
    
    ; Añadir puntos
    PUSH puntos_por_enemigo
    CALL addPuntuacion
    ADD esp, 4
    
    INC edx
    
    POP ecx
    JMP p_siguiente_bala
    
p_siguiente_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL p_enemigo_loop
    
    POP ecx
    
p_siguiente_bala:
    INC ecx
    CMP ecx, MAX_DISPAROS_JUGADOR
    JL p_bala_loop
    
    MOV eax, edx  ; retornar cantidad eliminada
    
    POP edx
    POP ecx
    POP edi
    POP esi
    POP ebx
    RET
checkColisionConPuntos ENDP
; ===== MODIFICAR crearDisparoEnemigo para usar velocidad variable =====
crearDisparoEnemigo PROC
    PUSH ebp
    MOV ebp, esp
    
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    ; Buscar slot libre
    XOR ecx, ecx
    
buscar_slot_enemigo:    
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_enemigos[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE slot_encontrado_enemigo
    
    INC ecx
    CMP ecx, MAX_DISPAROS_ENEMIGOS
    JL buscar_slot_enemigo
    
    JMP fin_crear_enemigo
    
slot_encontrado_enemigo:
    ; Obtener parámetros
    MOV eax, [ebp + 8]  ; pos_x
    MOV ebx, [ebp + 12] ; pos_y
    
    ; Configurar disparo
    ADD eax, 16
    SUB eax, 2
    MOV [esi + DisparoJugador.x], eax
    
    ADD ebx, ENEMY_HEIGHT
    MOV [esi + DisparoJugador.y], ebx
    
    MOV DWORD PTR [esi + DisparoJugador.is_active], 1
    
    ; ¡VELOCIDAD SEGÚN DIFICULTAD!
    MOV eax, velocidad_disparos_enemigos
    MOV [esi + DisparoJugador.speed], eax
    
    MOV DWORD PTR [esi + DisparoJugador.tipo], 1
    
fin_crear_enemigo:
    POP ecx
    POP esi
    POP ebx
    POP ebp
    RET 8
crearDisparoEnemigo ENDP
; ===== ACTUALIZAR DISPAROS ENEMIGOS (SIMPLIFICADO) =====
actualizarDisparosEnemigos PROC
    PUSH esi
    PUSH ecx
    
    XOR ecx, ecx
    
actualizar_loop_enemigo:
    MOV eax, ecx
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_enemigos[eax]
    
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE siguiente_enemigo
    
    ; Mover disparo hacia abajo
    MOV eax, [esi + DisparoJugador.y]
    ADD eax, [esi + DisparoJugador.speed]
    MOV [esi + DisparoJugador.y], eax
    
    ; Verificar si salió de pantalla (abajo)
    CMP eax, HEIGHT_SCREEN
    JL siguiente_enemigo
    
    ; Desactivar si salió
    MOV DWORD PTR [esi + DisparoJugador.is_active], 0
    
siguiente_enemigo:
    INC ecx
    CMP ecx, MAX_DISPAROS_ENEMIGOS
    JL actualizar_loop_enemigo
    
    POP ecx
    POP esi
    RET
actualizarDisparosEnemigos ENDP

; ===== OBTENER DATOS DE DISPARO ENEMIGO (SIMPLIFICADO) =====
getDisparoEnemigoData PROC
    ; Parámetros: index (4), out_x (4), out_y (4), out_active (4)
    PUSH ebp
    MOV ebp, esp
    
    PUSH esi
    PUSH ebx
    
    MOV eax, [ebp + 8]  ; index
    CMP eax, MAX_DISPAROS_ENEMIGOS
    JGE error_enemigo
    
    ; Calcular posición en array
    MOV ebx, SIZE_DISPARO_JUGADOR
    MUL ebx
    LEA esi, disparos_enemigos[eax]
    
    ; Devolver datos
    MOV eax, [esi + DisparoJugador.x]
    MOV ebx, [ebp + 12] ; out_x
    MOV [ebx], eax
    
    MOV eax, [esi + DisparoJugador.y]
    MOV ebx, [ebp + 16] ; out_y
    MOV [ebx], eax
    
    MOV eax, [esi + DisparoJugador.is_active]
    MOV ebx, [ebp + 20] ; out_active
    MOV [ebx], eax
    
    MOV eax, 1
    JMP fin_get_enemigo
    
error_enemigo:
    XOR eax, eax
    
fin_get_enemigo:
    POP ebx
    POP esi
    POP ebp
    RET 16  ; Limpiar 4 parámetros
getDisparoEnemigoData ENDP

; ===== MODIFICAR intentarDisparoEnemigo para mayor probabilidad según dificultad =====
intentarDisparoEnemigo PROC
    PUSH ebx
    PUSH esi
    PUSH ecx
    PUSH edi
    
    ; Contador de enemigos vivos
    CALL getEnemigosVivos
    MOV ebx, eax
    CMP ebx, 0
    JE fin_intento
    
    ; Calcular probabilidad base según dificultad
    MOV eax, nivel_dificultad
    CMP eax, 1
    JE prob_facil
    CMP eax, 2
    JE prob_medio
    CMP eax, 3
    JE prob_dificil
    
    ; Por defecto
    MOV eax, 15
    JMP tener_probabilidad
    
prob_facil:
    MOV eax, 10  ; 10% en fácil
    JMP tener_probabilidad
    
prob_medio:
    MOV eax, 20  ; 20% en medio
    JMP tener_probabilidad
    
prob_dificil:
    MOV eax, 30  ; 30% en difícil
    
tener_probabilidad:
    ; Guardar probabilidad
    PUSH eax
    
    ; Por cada enemigo vivo
    XOR ecx, ecx
    XOR edi, edi
    
enemigo_disparo_loop:
    MOV eax, ecx
    MOV esi, SIZE_ENEMIGO
    MUL esi
    LEA esi, enemigos_array[eax]
    
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE siguiente_enemigo_disparo
    
    ; Aleatoriedad
    MOV eax, [esi + EnemigoSI.x]
    ADD eax, [esi + EnemigoSI.y]
    ADD eax, ecx
    
    ; Obtener número 0-99
    XOR edx, edx
    PUSH ebx
    MOV ebx, 100
    DIV ebx
    MOV eax, edx
    POP ebx
    
    ; Comparar con probabilidad (que está en la pila en [esp+4])
    MOV edx, [esp]  ; Obtener probabilidad de la pila
    CMP eax, edx
    JG siguiente_enemigo_disparo  ; Si random > probabilidad, no disparar
    
disparar_enemigo:
    MOV eax, [esi + EnemigoSI.x]
    MOV ebx, [esi + EnemigoSI.y]
    PUSH ebx
    PUSH eax
    CALL crearDisparoEnemigo
    
    ; Permitir hasta 5 disparos por ciclo
    INC edi
    CMP edi, 5
    JGE fin_intento_pop
    
siguiente_enemigo_disparo:
    INC ecx
    CMP ecx, enemigo_count
    JL enemigo_disparo_loop
    
fin_intento_pop:
    ; Limpiar probabilidad de la pila
    POP eax
    
fin_intento:
    POP edi
    POP ecx
    POP esi
    POP ebx
    RET
intentarDisparoEnemigo ENDP

checkColisionBalaEnemigoJugador PROC
    ; Parámetros: jug_x, jug_y, jug_ancho, jug_alto
    PUSH ebp
    MOV ebp, esp
    
    PUSH esi
    PUSH ecx
    PUSH edx
    
    XOR ecx, ecx            ; índice
    
check_loop:
    ; Obtener bala
    MOV eax, ecx
    MOV edx, SIZE_DISPARO_JUGADOR
    MUL edx
    LEA esi, disparos_enemigos[eax]
    
    ; ¿Está activa?
    CMP DWORD PTR [esi + DisparoJugador.is_active], 0
    JE next_bullet
    
    ; === COLISIÓN SIMPLE ===
    ; Bala X entre jugador X y X+ancho?
    MOV eax, [esi + DisparoJugador.x]
    CMP eax, [ebp + 8]          ; jug_x
    JL next_bullet
    ADD eax, BULLET_WIDTH
    MOV edx, [ebp + 8]
    ADD edx, [ebp + 16]         ; jug_x + jug_ancho
    CMP eax, edx
    JG next_bullet
    
    ; Bala Y entre jugador Y y Y+alto?
    MOV eax, [esi + DisparoJugador.y]
    CMP eax, [ebp + 12]         ; jug_y
    JL next_bullet
    ADD eax, BULLET_HEIGHT
    MOV edx, [ebp + 12]
    ADD edx, [ebp + 20]         ; jug_y + jug_alto
    CMP eax, edx
    JG next_bullet
    
    ; ¡COLISIÓN!
    MOV DWORD PTR [esi + DisparoJugador.is_active], 0
    MOV eax, 1
    JMP done
    
next_bullet:
    INC ecx
    CMP ecx, MAX_DISPAROS_ENEMIGOS
    JL check_loop
    
    ; Sin colisiones
    MOV eax, 0
    
done:
    POP edx
    POP ecx
    POP esi
    POP ebp
    RET 16
checkColisionBalaEnemigoJugador ENDP

; ===== DETECCIÓN DE COLISIÓN ENEMIGO - JUGADOR (COMPLETAMENTE REESCRITA) =====
checkColisionEnemigoJugador PROC jugador_x:DWORD, jugador_y:DWORD, jugador_ancho:DWORD, jugador_alto:DWORD
    PUSH ebp
    MOV ebp, esp
    
    PUSH ebx
    PUSH esi
    PUSH ecx
    PUSH edx
    
    XOR ecx, ecx            ; índice
    MOV eax, 0              ; resultado = 0 (sin colisión)
    
colision_loop:
    ; Obtener enemigo
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; ¿Está vivo?
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE siguiente_enemigo
    
    ; ===== LÓGICA DE COLISIÓN CLARA =====
    ; Calcular límites del enemigo
    MOV eax, [esi + EnemigoSI.x]      ; eax = enemigo_x
    MOV ebx, eax
    ADD ebx, ENEMY_WIDTH              ; ebx = enemigo_x + ENEMY_WIDTH (derecha)
    
    ; Calcular límites del jugador
    MOV edx, [ebp + 8]                ; edx = jugador_x
    ADD edx, [ebp + 16]               ; edx = jugador_x + jugador_ancho (derecha)
    
    ; 1. Verificar si NO hay superposición en X
    
    CMP ebx, [ebp + 8]                
    JLE siguiente_enemigo             
    
    CMP eax, edx                      
    JGE siguiente_enemigo             
    
    ; 2. Verificar si NO hay superposición en Y
    ; Calcular límites verticales del enemigo
    MOV eax, [esi + EnemigoSI.y]      ; eax = enemigo_y
    MOV ebx, eax
    ADD ebx, ENEMY_HEIGHT             ; ebx = enemigo_y + ENEMY_HEIGHT (abajo)
    
    ; Calcular límites verticales del jugador
    MOV edx, [ebp + 12]               
    ADD edx, [ebp + 20]               
    
    CMP ebx, [ebp + 12]               
    JLE siguiente_enemigo             
    
    CMP eax, edx                      
    JGE siguiente_enemigo             
    
    ; ===== ¡COLISIÓN DETECTADA! =====
    MOV eax, 1
    JMP fin_colision
    
siguiente_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL colision_loop
    
    ; Si llegamos aquí, no hubo colisiones
    MOV eax, 0
    
fin_colision:
    POP edx
    POP ecx
    POP esi
    POP ebx
    POP ebp
    RET 16
checkColisionEnemigoJugador ENDP

; ===== VERIFICAR SI ALGÚN ENEMIGO LLEGÓ DEMASIADO ABAJO =====
; Retorna en eax: 1 si algún enemigo llegó al límite, 0 si no
checkEnemigosEnBase PROC limite_y:DWORD
    PUSH esi
    PUSH ecx
    
    ; Cargar límite en registro
    MOV ecx, limite_y
    
    XOR eax, eax            ; resultado = 0 (inicialmente)
    XOR edx, edx            ; índice = 0
    
check_loop_simple:
    ; Calcular posición del enemigo
    MOV esi, edx
    IMUL esi, SIZE_ENEMIGO
    LEA esi, enemigos_array[esi]
    
    ; ¿Está vivo?
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE next_enemy_simple
    
    ; ¿Su Y >= límite?
    MOV esi, [esi + EnemigoSI.y]
    CMP esi, ecx
    JL next_enemy_simple    ; Si y < límite, siguiente
    
    ; ¡Encontramos uno que pasó!
    MOV eax, 1
    JMP done_simple
    
next_enemy_simple:
    INC edx
    CMP edx, enemigo_count
    JL check_loop_simple
    
done_simple:
    POP ecx
    POP esi
    RET 4
checkEnemigosEnBase ENDP

; ===== FUNCIONES DE DIFICULTAD =====

; getNivelDificultad: retorna el nivel actual
getNivelDificultad PROC
    MOV eax, nivel_dificultad
    RET
getNivelDificultad ENDP

; setNivelDificultad: establece el nivel de dificultad
setNivelDificultad PROC nuevo_nivel:DWORD
    MOV eax, nuevo_nivel
    MOV nivel_dificultad, eax
    
    ; Actualizar variables según nivel
    CMP eax, 1
    JE nivel_facil
    CMP eax, 2
    JE nivel_medio
    CMP eax, 3
    JE nivel_dificil
    
    ; Por defecto, nivel fácil
nivel_facil:
    MOV formation_speed, 5      ; Velocidad lenta
    MOV velocidad_disparos_enemigos, 4  ; Balas lentas
    MOV descenso_distancia, 15  ; Bajan poco
    JMP fin_set_nivel
    
nivel_medio:
    MOV formation_speed, 7      ; Velocidad media
    MOV velocidad_disparos_enemigos, 6  ; Balas media velocidad
    MOV descenso_distancia, 20  ; Bajan normal
    JMP fin_set_nivel
    
nivel_dificil:
    MOV formation_speed, 9      ; Velocidad rápida
    MOV velocidad_disparos_enemigos, 8  ; Balas rápidas
    MOV descenso_distancia, 25  ; Bajan más
    JMP fin_set_nivel
    
fin_set_nivel:
    RET 4
setNivelDificultad ENDP

; actualizarDificultad: actualiza dificultad según enemigos restantes
actualizarDificultad PROC
    PUSH ebx
    
    ; Obtener cantidad de enemigos vivos
    CALL getEnemigosVivos
    MOV ebx, eax  ; ebx = enemigos vivos
    
    ; Calcular qué tan difícil debe ser
    ; Si quedan muchos enemigos -> fácil
    ; Si quedan pocos enemigos -> difícil
    
    CMP ebx, 15   ; Si quedan más de 15 enemigos
    JG muy_facil
    
    CMP ebx, 10   ; Si quedan entre 10 y 15
    JG dificultad_media
    
    CMP ebx, 5    ; Si quedan entre 5 y 10
    JG dificultad_alta
    
    ; Si quedan menos de 5 -> muy difícil
    MOV eax, 4    ; Nivel 4 (extremo)
    JMP aplicar_dificultad
    
muy_facil:
    MOV eax, 1    ; Nivel 1 (fácil)
    JMP aplicar_dificultad
    
dificultad_media:
    MOV eax, 2    ; Nivel 2 (medio)
    JMP aplicar_dificultad
    
dificultad_alta:
    MOV eax, 3    ; Nivel 3 (difícil)
    
aplicar_dificultad:
    ; Solo cambiar si es diferente al actual
    CMP eax, nivel_dificultad
    JE fin_actualizar
    
    ; Establecer nuevo nivel
    PUSH eax
    CALL setNivelDificultad
    
fin_actualizar:
    POP ebx
    RET
actualizarDificultad ENDP

END
