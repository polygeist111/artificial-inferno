"""
Entrypoint for Poisoner API
"""

### Imports
# Standard
from apis import api

# Third Party
from flask import Flask

# Local
from core.markov import initMarkovGenerator
from core.filehandling import initializeFileBuffers



app = Flask(__name__)
api.init_app(app)

initMarkovGenerator() # on app load, read in all corpus files
initializeFileBuffers() # on app load, remove any excess files in buffer

app.run(debug=True)