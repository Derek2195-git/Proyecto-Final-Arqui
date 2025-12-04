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


.data
MAX_ENEMIGOS EQU 10
; Tama?os de sprites
ENEMY_WIDTH EQU 32    ; Ancho del enemigo
ENEMY_HEIGHT EQU 16   ; Alto del enemigo
BULLET_WIDTH EQU 5    ; Ancho de la bala
BULLET_HEIGHT EQU 15  ; Alto de la bala

; Espaciado entre enemigos
ENEMY_SPACING_X EQU 40   ; 40 p?xeles entre enemigos (32 + 8)
ENEMY_SPACING_Y EQU 25   ; 25 p?xeles entre filas (16 + 9)

; Arrays de disparos
disparos_jugador DisparoJugador MAX_DISPAROS_JUGADOR DUP(<>)

; Puntuacion
puntuacion_actual DWORD 0
puntos_por_enemigo DWORD 1000


; Array de enemigos
enemigos_array EnemigoSI MAX_ENEMIGOS DUP(<>)
enemigo_count DWORD 0

; Variables para la formaci?n
formation_direction DWORD 1  ; 1 = derecha, -1 = izquierda
should_descend DWORD 0       ; 0 = no, 1 = s? bajar
formation_speed DWORD 7

left_bound DWORD 9999
right_bound DWORD -9999

.code
PUBLIC pruebaPuente, moverJugadorAsm, definirValorAsm
PUBLIC actualizarPosicionEnemigosAsm, initEnemigos, updateAllEnemigos, getEnemigoData
PUBLIC crearDisparoJugador, actualizarDisparosJugador, getDisparoJugadorData
PUBLIC checkColisionBalaEnemigo, updateColisiones, getEnemigosVivos
PUBLIC getPuntuacion, addPuntuacion, resetPuntuacion, checkColisionConPuntos

; pruebaPuente: recibe (int a, int b) -> devuelve a + b
pruebaPuente PROC a:DWORD, b:DWORD
    mov eax, a
    add eax, b
    ret 8
pruebaPuente ENDP

; Funcion para inicializar enemigos
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
    
    XOR ecx, ecx

init_loop:
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]

    ; Calcular fila y columna
    MOV eax, ecx
    XOR edx, edx
    DIV cols          ; eax = fila, edx = columna

    ; Guardar fila
    PUSH eax
    
    ; Calcular x = col * ENEMY_SPACING_X + 30 (margen izquierdo)
    MOV eax, edx      ; eax = columna
    MOV ebx, ENEMY_SPACING_X
    MUL ebx
    ADD eax, 30       ; Margen izquierdo
    MOV [esi + EnemigoSI.x], eax
    
    ; Calcular y = fila * ENEMY_SPACING_Y + 50 (margen superior)
    POP eax           ; recuperar fila
    MOV ebx, ENEMY_SPACING_Y
    MUL ebx
    ADD eax, 50       ; Margen superior
    MOV [esi + EnemigoSI.y], eax
    
    ; Configurar velocidad y direcci?n
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

; ===== ACTUALIZAR TODOS LOS ENEMIGOS =====
updateAllEnemigos PROC ancho_pantalla:DWORD
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    ; 1. Encontrar l?mites de la formaci?n
    CALL checkFormationBounds
    
    ; 2. Verificar si la formaci?n toc? los bordes
    MOV eax, left_bound
    MOV edx, right_bound
    
    ; Verificar l?mite izquierdo
    CMP eax, 10
    JG check_right_bound
    
    ; Toc? l?mite izquierdo
    MOV formation_direction, 1
    MOV should_descend, 1
    JMP update_enemies

check_right_bound:
    ; Verificar l?mite derecho (a?adir ancho del sprite)
    ADD edx, ENEMY_WIDTH
    CMP edx, ancho_pantalla
    JL update_enemies
    
    ; Toc? l?mite derecho
    MOV formation_direction, -1
    MOV should_descend, 1
    
update_enemies:
    ; 3. Actualizar cada enemigo
    XOR ecx, ecx

update_loop:
    ; Calcular posici?n en array
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; Verificar si est? vivo
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE next_enemigo

    ; Mover en X
    MOV eax, [esi + EnemigoSI.x]
    MOV ebx, formation_speed
    MOV edx, formation_direction
    IMUL ebx, edx
    ADD eax, ebx
    MOV [esi + EnemigoSI.x], eax

    ; Actualizar direcci?n individual
    MOV eax, formation_direction
    MOV [esi + EnemigoSI.direction], eax
    
    ; Descenso si est? activado
    CMP should_descend, 0
    JE next_enemigo
    
    ; Bajar enemigo 20 p?xeles
    MOV eax, [esi + EnemigoSI.y]
    ADD eax, 20
    MOV [esi + EnemigoSI.y], eax
    
next_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL update_loop
    
    ; Desactivar descenso para el pr?ximo frame
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


END
