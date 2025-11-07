"""
Globals and hardcoded sample values for program execution
"""

### Imports
# Standard
from enum import Enum

# Third Party
from markovify import Text as markovText

# Local



### Configurable Constants
CORPUS_MAX_COUNT = 10001 # 1 is reserved for seed corpus, others are user-generated
IMAGE_MAX_COUNT = 5 # TODO: should be 50 for production use
AUDIO_MAX_COUNT = 5 # TODO: should be 50 for production use
FILE_DELETION_DELAY = 30 # seconds after serving to delete a file
# Filepaths
IMAGE_DIRECTORY = "data/images/"
AUDIO_DIRECTORY = "data/audio/"
CORPORA_DIRECTORY = "data/corpora/"

### Runtime Vars
#markov_chain: Optional[markovText] = None
markov_chain: markovText
corpus_count: int = 0

# Colors
class Colors(Enum):
    """
    Enum definition of most common ANSI color escapes
    """
    # Standard
    STANDARD_BLACK = "\033[30m"
    STANDARD_RED = "\033[31m"
    STANDARD_GREEN = "\033[32m"
    STANDARD_YELLOW = "\033[33m"
    STANDARD_BLUE = "\033[34m"
    STANDARD_PURPLE = "\033[35m"
    STANDARD_CYAN = "\033[36m"
    STANDARD_WHITE = "\033[37m"

    # Background
    BACKGROUND_BLACK = "\033[40m"
    BACKGROUND_RED = "\033[41m"
    BACKGROUND_GREEN = "\033[42m"
    BACKGROUND_YELLOW = "\033[43m"
    BACKGROUND_BLUE = "\033[44m"
    BACKGROUND_PURPLE = "\033[45m"
    BACKGROUND_CYAN = "\033[46m"
    BACKGROUND_WHITE = "\033[47m"

    # Special
    RESET = "\033[0m"
    ESC_IN_LINE = "\033[K"
