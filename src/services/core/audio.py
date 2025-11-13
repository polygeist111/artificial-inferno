"""
Module to handle audio-specific actions
"""

### Imports
# Standard
import time
import os

# Third Party
from werkzeug.datastructures import FileStorage
import filetype
import pydub # also need to make sure you've installed audioop-lts
from pydub.utils import make_chunks

# Local
import global_vars
from core.messaging import console_out, LogLevel
import core.filehandling as filehandling



def saveAudioFromPost(audioIn: FileStorage):
    """
    Validates and saves audio POSTed to the API
    """
    write_time = time.time()
    new_file_basename = f"audio_{write_time}.mp3"

    # check for type conformity
    if filetype.is_audio(audioIn):
        kind = filetype.guess(audioIn)
        if not (kind and kind.mime == "audio/mpeg"):
            console_out(f"Uploaded file '{audioIn.filename}' will not be saved: The file is an audio file, but filetype must be 'image/mpeg' e.g. MP3, not '{kind.mime if kind else 'an unknown type'}'.", LogLevel.FAILURE)
            return [2] # fail because non mpeg audio
    else:
        console_out(f"Uploaded file '{audioIn.filename}' will not be saved: The file is not an audio file.", LogLevel.FAILURE)
        return [3] # fail because nonaudio file
    
    # All below execution is only on correctly-typed files
    new_file_path = filehandling.addFileToBufferDirectory(global_vars.INTAKE_DIRECTORY, new_file_basename, audioIn)
    if new_file_path[:len("Exception: ")] != "Exception: ":
        subdivideAudio(new_file_path, 1000)
        return [0] # success, mpeg audio
    
    return [1, new_file_path[len("Exception: "):]] # fail on internal error
    


def getAudioFromBuffer():
    """
    Processes audio file from buffer to serve back to API
    """
    return filehandling.serveRandomFileFromBuffer(global_vars.AUDIO_DIRECTORY)



def subdivideAudio(audio_file_path: str, chunk_length_ms: int) -> bool:
    """
    Break an audio file (MP3) down into shorter subsections
    Takes the source filepath and subsection length in ms
    """
    # check path validity
    if not os.path.exists(audio_file_path):
        console_out(f"Cannot subdivide audio file '{audio_file_path}' because path is invalid", LogLevel.FAILURE)
        return False
    file_basename = os.path.basename(audio_file_path)
    
    # load into audio object
    audio = pydub.AudioSegment.from_file(audio_file_path, format = "mp3")

    chunks = make_chunks(audio, chunk_length_ms)
    # save the chunks as distinct files
    for i, chunk in enumerate(chunks):
        # Name each chunk file sequentially (-4 removes .mp3 from file basename)
        chunk_name = f"{file_basename[:-4]}_chunk_{i}.mp3"
        filehandling.addFileToBufferDirectory(global_vars.AUDIO_DIRECTORY, chunk_name, chunk)
    
    # remove intake file
    filehandling.deleteResource(audio_file_path)

    return True
