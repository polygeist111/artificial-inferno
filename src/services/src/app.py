"""
Entrypoint for Poisoner API
"""

### Imports
# Standard
from apis import api

# Third Party
from flask import Flask

# Local
from core.messaging import console_out, LogLevel
from core.markov import initMarkovGenerator
from core.filehandling import initializeFileBuffers



app = Flask(__name__)
api.init_app(app)

console_out("Initializing Markov Generator", LogLevel.INFO)
initMarkovGenerator() # on app load, read in all corpus files
console_out("Initializing File Buffers", LogLevel.INFO)
initializeFileBuffers() # on app load, remove any excess files in buffer
console_out("Running App", LogLevel.INFO)

if __name__ == '__main__':
    # if called by running python file, executes this
    # if called by flask run [options], bypasses this
    app.run(host='0.0.0.0', port = 5000, debug = True)