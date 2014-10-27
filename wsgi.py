import os

from freeoids import app

app.config.from_pyfile(os.path.abspath('config.py'))

