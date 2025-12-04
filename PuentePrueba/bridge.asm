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

SIZE_ENEMIGO EQU 20  ; 5 campos * 4 bytes = 20 bytes

.data
MAX_ENEMIGOS EQU 10

; Array de enemigos
enemigos_array EnemigoSI MAX_ENEMIGOS DUP(<>)
enemigo_count DWORD 0

; Variables para la formación
formation_direction DWORD 1  ; 1 = derecha, -1 = izquierda
should_descend DWORD 0       ; 0 = no, 1 = sí bajar
formation_speed DWORD 2

left_bound DWORD 9999
right_bound DWORD -9999

.code
PUBLIC pruebaPuente, moverJugadorAsm, definirValorAsm, actualizarPosicionEnemigosAsm
PUBLIC initEnemigos, updateAllEnemigos, getEnemigoData

; pruebaPuente: recibe (int a, int b) -> devuelve a + b
pruebaPuente PROC a:DWORD, b:DWORD
    mov eax, a
    add eax, b
    ret 8
pruebaPuente ENDP

; Función para inicializar enemigos
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
    ; Calcular dirección en memoria: índice * SIZE_ENEMIGO
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]

    ; Calcular fila y columna
    MOV eax, ecx
    XOR edx, edx
    DIV cols          ; eax = fila, edx = columna

    ; Guardar fila en ebx temporalmente
    PUSH eax
    
    ; Calcular x = col * 60 + 50
    MOV eax, edx      ; eax = columna
    IMUL eax, 60
    ADD eax, 50
    MOV [esi + EnemigoSI.x], eax
    
    ; Calcular y = fila * 60 + 50
    POP eax           ; recuperar fila
    IMUL eax, 60
    ADD eax, 50
    MOV [esi + EnemigoSI.y], eax
    
    ; Configurar velocidad y dirección
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

; ===== VERIFICAR LÍMITES DE LA FORMACIÓN =====
checkFormationBounds PROC
    PUSH ebx
    PUSH esi
    PUSH ecx
    
    MOV left_bound, 9999
    MOV right_bound, -9999

    XOR ecx, ecx
    
bounds_loop:
    ; Calcular posición en array
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; Solo enemigos vivos
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE bounds_next
    
    ; Obtener posición x
    MOV eax, [esi + EnemigoSI.x]
    
    ; Actualizar límite izquierdo
    CMP eax, left_bound
    JGE check_right
    MOV left_bound, eax
    
check_right:
    ; Actualizar límite derecho
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
    
    ; 1. Encontrar límites de la formación
    CALL checkFormationBounds
    
    ; 2. Verificar si la formación tocó los bordes
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
    ; Verificar límite derecho (añadir ancho del sprite)
    ADD edx, 50
    CMP edx, ancho_pantalla
    JL update_enemies
    
    ; Tocó límite derecho
    MOV formation_direction, -1
    MOV should_descend, 1
    
update_enemies:
    ; 3. Actualizar cada enemigo
    XOR ecx, ecx

update_loop:
    ; Calcular posición en array
    MOV eax, ecx
    MOV edx, SIZE_ENEMIGO
    MUL edx
    LEA esi, enemigos_array[eax]
    
    ; Verificar si está vivo
    CMP DWORD PTR [esi + EnemigoSI.is_alive], 0
    JE next_enemigo

    ; Mover en X
    MOV eax, [esi + EnemigoSI.x]
    MOV ebx, formation_speed
    MOV edx, formation_direction
    IMUL ebx, edx
    ADD eax, ebx
    MOV [esi + EnemigoSI.x], eax

    ; Actualizar dirección individual
    MOV eax, formation_direction
    MOV [esi + EnemigoSI.direction], eax
    
    ; Descenso si está activado
    CMP should_descend, 0
    JE next_enemigo
    
    ; Bajar enemigo 20 píxeles
    MOV eax, [esi + EnemigoSI.y]
    ADD eax, 20
    MOV [esi + EnemigoSI.y], eax
    
next_enemigo:
    INC ecx
    CMP ecx, enemigo_count
    JL update_loop
    
    ; Desactivar descenso para el próximo frame
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
    
    ; Calcular posición en array
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
    
    MOV eax, 1  ; éxito
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
    MOV edx, [ebx]      ; edx = dirección (1 o -1)

    IMUL ecx, edx       ; ecx = velocidad * dirección
    ADD eax, ecx        ; eax = x + velocidad * dirección
    
    ; Guardar nuevo x
    MOV [esi], eax

    ; ===== VERIFICAR LÍMITES =====
    
    ; Primero verificar límite izquierdo (x <= 0)
    CMP eax, 0
    JG verificar_derecho  ; Si x > 0, saltar a verificar derecho
    
    ; ===== TOCÓ LÍMITE IZQUIERDO =====
    MOV edx, [ebx]      ; Cargar dirección actual
    NEG edx             ; Invertir dirección
    MOV [ebx], edx      ; Guardar nueva dirección
    
    ; Mover hacia abajo
    MOV ecx, [edi]      ; Cargar y actual
    ADD ecx, 20         ; Añadir 20 píxeles
    MOV [edi], ecx      ; Guardar nuevo y
    
    ; Corregir x para que no sea negativo
    MOV DWORD PTR [esi], 0
    JMP fin_funcion
    
verificar_derecho:
    ; Verificar límite derecho (x >= ancho - 50)
    MOV edx, ancho      ; Cargar ancho de pantalla
    SUB edx, 50         ; Restar ancho del sprite
    
    CMP eax, edx        ; Comparar x con (ancho - 50)
    JL fin_funcion      ; Si x < (ancho-50), terminar
    
    ; ===== TOCÓ LÍMITE DERECHO =====
    MOV edx, [ebx]      ; Cargar dirección actual
    NEG edx             ; Invertir dirección
    MOV [ebx], edx      ; Guardar nueva dirección
    
    ; Mover hacia abajo
    MOV ecx, [edi]      ; Cargar y actual
    ADD ecx, 20         ; Añadir 20 píxeles
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

END