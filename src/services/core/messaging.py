"""
Message formatter for all production console output
"""

#
# Created by Thalia Wood on 11/04/25
#

### Imports
#Standard
import enum as Enum

# Third Party

# Local
import global_vars



class LogLevel(Enum):
    """
    Definition for log levels and their associated colors
    """
    SUCCESS = global_vars.Colors.STANDARD_GREEN
    FAILURE = global_vars.Colors.STANDARD_RED
    INFO = global_vars.Colors.STANDARD_WHITE
    WARN = global_vars.Colors.BACKGROUND_YELLOW
    ERROR = global_vars.Colors.BACKGROUND_RED



def console_out(message: str, level: LogLevel, newline: bool = True, exit_code: int = 0):
    """
    Standard formatter for logged messages
    All production messages should be run through this
    All debugging messages should be printed normally
    """

    # Add custom error messages for codes as list expands
    error_prefix = ""
    match exit_code:
        case 0:
            error_prefix = ""
        case 1:
            error_prefix = "ERROR: Unknown.\n"

    # Assemble output message with color escapes
    output_message = f"{level.value}{error_prefix}{message}{global_vars.Colors.RESET}"

    # Print with or without newline
    if newline:
        print(output_message)
    else:
        print(output_message, end = "")
