import os
import freeoids

freeoids.app.config.from_pyfile(os.path.abspath('config.py'))
freeoids.app.run()

