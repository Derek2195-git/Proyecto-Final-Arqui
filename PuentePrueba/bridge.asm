; bridge.asm
.386
.model flat, stdcall
.stack 4096

PUBLIC pruebaPuente, moverJugadorAsm, definirValorAsm, actualizarPosicionEnemigosAsm
.data
contador_descenso DWORD 20
y_destino DWORD 0

.code

; pruebaPuente: recibe (int a, int b) -> devuelve a + b
pruebaPuente PROC a:DWORD, b:DWORD
    mov eax, a
    add eax, b
    ret 8
pruebaPuente ENDP

moverJugadorAsm PROC posActual:DWORD, direccion:DWORD, speed:DWORD
    MOV eax, posActual
    MOV edx, direccion
    CMP edx, -1
    JE mover_izquierda
    CMP edx, 1
    JE mover_derecha
    JMP terminar_movimiento
    mover_izquierda:
        SUB eax, speed
        JMP terminar_movimiento
    mover_derecha:
        ADD eax, speed
        JMP terminar_movimiento

    terminar_movimiento:

    ret 8
moverJugadorAsm ENDP

definirValorAsm PROC valor:DWORD
    MOV eax, valor
    ret 8
definirValorAsm ENDP

actualizarPosicionEnemigosAsm PROC pos_x:PTR DWORD, pos_y:PTR DWORD, velocidad:DWORD, dir:PTR DWORD, ancho:DWORD
    
    ; x = esp + 4, y = esp + 8, velocidad = esp + 12, direccion = esp + 16, ancho = esp + 20 
    ; Guardamos los registros que se van a modificar
    PUSH ebx
    PUSH esi
    PUSH edi

    ; Cargamos punteros
    MOV esi, pos_x
    MOV edi, pos_y
    MOV ebx, dir
    ; Self.x += self.speed * self.direction
    MOV eax, [esi]
    MOV ecx, velocidad
    MOV edx, [ebx]

    IMUL ecx, edx
    ADD eax, ecx
    ; Devolvemos el resultado a pos_x
    MOV [esi], eax

    ; Verificamos los limites de la pantalla
    CMP eax, 0
    JG cambiar_direccion_enemigo
    ; Cambiamos la direccion si x <= 0
    MOV edx, [ebx]
    NEG edx
    MOV [ebx], ecx
    ; Mover hacia abajo 20 pixeles
    MOV ecx, [edi]
    call animarDescensoEnemigos
    MOV [edi], ecx

    ; Corregimos la posicion en x para evitar salirnos
    MOV DWORD PTR [esi], 0
    JMP acabar_actualizar_posicion_enemigos

    cambiar_direccion_enemigo:
        ; Si x >= ancho - 50 (asumiendo que todos los enemigos tienen 50 pixeles de ancho)
        MOV edx, ancho
        SUB edx, 50 ; Le restamos el ancho del sprite
        CMP eax, edx
        JL acabar_actualizar_posicion_enemigos

        ; Cambiamos la posicion en caso de que x >= ancho - 50
        MOV edx, [ebx]
        NEG edx
        MOV [ebx], edx

        ; Nos movemos unos 20 pixeles hacia abajo
        MOV ecx, [edi]
        call animarDescensoEnemigos
        MOV [edi], ecx

        ; Corregimos la posicion en x por si acaso
        MOV eax, ancho
        SUB eax, 50
        MOV [esi], eax

    acabar_actualizar_posicion_enemigos:
        ; Restauramos los registros que guardamos al inicio
        POP edi
        POP esi
        POP ebx

    ret 20
actualizarPosicionEnemigosAsm ENDP

animarDescensoEnemigos PROC
inicio_descenso_enemigos:
    MOV eax, [esi]          ; cargar contador
    CMP eax, 0
    JNE continuar_animacion
    
    ; Iniciar nueva animación (20 frames, 1 píxel por frame)
    MOV DWORD PTR [esi], 20  ; iniciar contador
    
    ; Calcular y objetivo
    MOV eax, [edi]          ; y actual
    ADD eax, 20             ; +20 píxeles
    MOV [ebx], eax          ; guardar y objetivo
    RET
    
continuar_animacion:
    ; Decrementar contador
    DEC eax
    MOV [esi], eax
    
    ; Mover y 1 píxel
    MOV ecx, [edi]          ; y actual
    INC ecx                 ; +1 píxel
    MOV [edi], ecx          ; actualizar
    RET
animarDescensoEnemigos ENDP

END
