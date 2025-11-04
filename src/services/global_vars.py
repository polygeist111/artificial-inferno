"""
Globals and hardcoded sample values for program execution
"""

### Imports
# Standard
import enum as Enum

# Third Party
from markovify import Text as markovText

# Local



### Configurable Constants
CORPUS_MAX_COUNT = 10001 # 1 is reserved for seed corpus, others are user-generated

### Runtime Vars
markov_chain: markovText = None
corpus_count: int = 0

# Colors
class Colors(Enum):
    """
    Enum definition of most common ANSI color escapes
    """
    # Standard
    STANDARD_BLACK = "\e[0;30m"
    STANDARD_RED = "\e[0;31m"
    STANDARD_GREEN = "\e[0;32m"
    STANDARD_YELLOW = "\e[0;33m"
    STANDARD_BLUE = "\e[0;34m"
    STANDARD_PURPLE = "\e[0;35m"
    STANDARD_CYAN = "\e[0;36m"
    STANDARD_WHITE = "\e[0;37m"

    # Background
    BACKGROUND_BLACK = "\e[0;40m"
    BACKGROUND_RED = "\e[0;41m"
    BACKGROUND_GREEN = "\e[0;42m"
    BACKGROUND_YELLOW = "\e[0;43m"
    BACKGROUND_BLUE = "\e[0;44m"
    BACKGROUND_PURPLE = "\e[0;45m"
    BACKGROUND_CYAN = "\e[0;46m"
    BACKGROUND_WHITE = "\e[0;47m"

    # Reset
    RESET = "\e[0m"
