; bridge.asm
.386
.model flat, stdcall
.stack 4096

PUBLIC pruebaPuente, moverJugadorAsm

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
END
