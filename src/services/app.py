from flask import Flask
from apis import api

from core.markov import initMarkovGenerator

app = Flask(__name__)
api.init_app(app)

initMarkovGenerator() # on app load, read in all corpus files

app.run(debug=True)