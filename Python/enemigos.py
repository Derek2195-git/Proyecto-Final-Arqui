from test_bridge import definirValor, actualizarPosicionEnemigos
WIDTH = 400

class Enemigos:
    def __init__(self, x, y, speed, image):
        self.x = definirValor(x)
        self.y = definirValor(y)
        self.speed = definirValor(speed)
        self.direction = definirValor(1)
        self.image = image
        self.width = self.image.get_width()
        self.height = self.image.get_height()

    def update(self):
        actualizarPosicionEnemigos(self.x, self.y, self.speed, self.direction, WIDTH)


    def draw(self, screen):
        screen.blit(self.image, (self.x, self.y))
