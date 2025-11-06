"""
Message formatter for all production console output
"""

### Imports
#Standard
from enum import Enum

# Third Party

# Local
from global_vars import Colors



class LogLevel(Enum):
    """
    Definition for log levels and their associated colors
    """
    SUCCESS =  Colors.STANDARD_GREEN.value
    FAILURE =  Colors.STANDARD_RED.value
    INFO =  Colors.STANDARD_WHITE.value
    USAGE =  Colors.STANDARD_PURPLE.value
    WARN = f"{ Colors.BACKGROUND_YELLOW.value}{ Colors.ESC_IN_LINE.value}"
    ERROR = f"{ Colors.BACKGROUND_RED.value}{ Colors.ESC_IN_LINE.value}"



def console_out(message: str, level: LogLevel, newline: bool = True, exit_code: int = 0, usage: str = ""):
    """
    Standard formatter for logged messages
    All production messages should be run through this
    All debugging messages should be printed normally
    Providing an exit code *will* exit the entire program, so do so only where needed, even for errors
    """

    # Add custom error messages for codes as list expands
    error_prefix = "ERROR - "
    match exit_code:
        case 0:
            error_prefix = ""
        case 1:
            error_prefix += "Unknown:\n"
        case 2:
            error_prefix += "Missing argument(s)\n"
        case 3:
            error_prefix += "Incorrect Password\n"
        case 4:
            error_prefix += "Invalid Input\n"
        case 5:
            error_prefix += "Bad filetype\n"

    # Format usage_str
    if usage != "":
        usage = f"{Colors.STANDARD_BLUE.value}Usage:{Colors.RESET.value}{Colors.STANDARD_PURPLE.value}{usage}{Colors.RESET.value}\n"

    # Assemble output message with color escapes
    output_message = f"{usage}{level.value}{error_prefix}{message}{Colors.RESET.value}"


    # Print with or without newline
    if newline:
        print(output_message)
    else:
        print(output_message, end = "")
    
    # Kill program on error
    if exit_code != 0:
        exit(exit_code)
