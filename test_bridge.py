from ctypes import WinDLL, c_int

dll = WinDLL(r"C:\Users\Keraf\source\repos\PuentePrueba\Debug\PuentePrueba.dll")

prueba = dll.pruebaPuente
prueba.argtypes = (c_int, c_int)
prueba.restype = c_int
moverJugador = dll.moverJugadorAsm

if (prueba(5,20)==25):
    prueba_completa = "cargado."
else:
    prueba_completa = "fallo."

print("dll...", prueba_completa)
