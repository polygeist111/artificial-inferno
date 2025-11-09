"""
Module to handle audio-specific actions
"""

### Imports
# Standard
import time

# Third Party
from werkzeug.datastructures import FileStorage
import filetype

# Local
import global_vars
from core.messaging import console_out, LogLevel
import core.filehandling as filehandling



def saveAudioFromPost(audioIn: FileStorage):
    """
    Validates and saves audio POSTed to the API
    """
    audio_directory = global_vars.AUDIO_DIRECTORY
    write_time = time.time()
    new_file_path = f"{audio_directory}/audio_{write_time}.mp3"

    # If image buffer is full, delete a random file
    filehandling.validateDirectorySize(audio_directory, global_vars.AUDIO_MAX_COUNT, True, True)

    try:
        audioIn.save(new_file_path)
    except Exception as e:
        return [1, e]
    
    if filetype.is_audio(new_file_path):
        kind = filetype.guess(new_file_path)
        if not (kind and kind.mime == "audio/mpeg"):
            filehandling.deleteResource(new_file_path)
            console_out(f"Uploaded file at '{new_file_path}' will not be saved: The file is an audio file, but filetype must be 'image/mpeg' e.g. MP3, not '{kind.mime if kind else 'an unknown type'}'.", LogLevel.FAILURE)
            return [2] # fail because non mpeg audio
    else:
        filehandling.deleteResource(new_file_path)
        console_out(f"Uploaded file at '{new_file_path}' will not be saved: The file is not an audio file.", LogLevel.FAILURE)
        return [3] # fail because nonaudio file
    
    return [0] # success, mpeg audio
    


def getAudioFromBuffer():
    return filehandling.serveRandomFileFromBuffer(global_vars.AUDIO_DIRECTORY)