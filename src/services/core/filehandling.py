"""
Module to handle all general file handling actions
"""

### Imports
# Standard
import os
import time
import threading
import random

# Third Party
from werkzeug.datastructures import FileStorage
import filetype
from pydub import AudioSegment

#Local
from core.messaging import console_out, LogLevel
import global_vars



def deleteResource(filepath: str) -> bool:
    """
    Safely removes a resource at the given path
    """
    if os.path.exists(filepath):
        os.remove(filepath)
        directory_name = f"{os.path.split(filepath)[0]}/"
        incrementBufferDirectoryCountByPath(directory_name, True)
        console_out(f"File '{filepath}' successfully deleted.", LogLevel.SUCCESS)
        return True
    console_out(f"File '{filepath}' cannot be deleted, does not exist", LogLevel.FAILURE)
    return False



def listDirectoryFiles(directory_path: str) -> list[str]:
    """
    Lists all files (only files) in a given directory
    """
    filenames: list[str] = []
    if os.path.exists(directory_path):
        filenames = [entry for entry in os.listdir(directory_path) if os.path.isfile(os.path.join(directory_path, entry))]
    else:
        console_out(f"Filepath {directory_path} cannot be counted, does not exist", LogLevel.ERROR, exit_code = 6)
    return filenames



def getRandomFileInDirectory(directory_path: str) -> str:
    """
    Returns the full path to one file in a given directory, or an empty string if the directory contains no files
    """
    selected_file = "File not found"
    files = listDirectoryFiles(directory_path)
    if len(files) > 0:
        selected_file = os.path.join(directory_path, random.choice(files))
    return selected_file



def initializeFileBuffers():
    """
    Ensures program is prepared for all buffer operations
    Clears delivery and intake directories if any files got stuck there
    Ensures working count of files in each buffer is accurate
    """

    # Empty the ephemeral directories
    global_vars.delivery_count = trimDirectory(global_vars.DELIVERY_DIRECTORY, 0)
    global_vars.intake_count = trimDirectory(global_vars.INTAKE_DIRECTORY, 0)
    # trim buffers to max size
    global_vars.audio_count = trimDirectory(global_vars.AUDIO_DIRECTORY, global_vars.AUDIO_MAX_COUNT)
    global_vars.corpus_count = trimDirectory(global_vars.CORPORA_DIRECTORY, global_vars.CORPUS_MAX_COUNT)
    global_vars.image_count = trimDirectory(global_vars.IMAGE_DIRECTORY, global_vars.IMAGE_MAX_COUNT)




def moveFile(file_to_move: str, destination_directory: str) -> str:
    """
    Move the given file to the given directory
    Returns new path if successful, "Invalid path(s)" if otherwise
    """
    error_message = "Invalid path(s)"
    if not os.path.exists(file_to_move):
        console_out(f"Failed to move file '{file_to_move}' to directory '{destination_directory}' because source file does not exist.", LogLevel.FAILURE)
        return error_message
    if not os.path.exists(destination_directory):
        console_out(f"Failed to move file '{file_to_move}' to directory '{destination_directory}' because destination directory does not exist.", LogLevel.FAILURE)
        return error_message
    
    new_path = os.path.join(destination_directory, os.path.basename(file_to_move))
    os.rename(file_to_move, new_path)
    console_out(f"Successfully changed file location from '{file_to_move}' to '{new_path}'.", LogLevel.SUCCESS)
    return new_path


def serveFile(file_to_serve: str) -> str:
    """
    Move file to the serving directory and mark it for deletion after a set timeframe
    Returns new path if successful, "Invalid path(s)" if otherwise
    """
    error_message = "Invalid path(s)"
    if not os.path.exists(file_to_serve):
        console_out(f"Failed to execute serving steps on file '{file_to_serve}' because path is invalid", LogLevel.FAILURE)
        return error_message
    
    # move file to serving directory
    new_path = moveFile(file_to_serve, global_vars.DELIVERY_DIRECTORY)
    if new_path == "Invalid path(s)":
        console_out(f"Failed to execute serving steps on file '{file_to_serve}' because either it or the delivery directory path are invalid.", LogLevel.FAILURE)
        return error_message
    
    # mark it for timed deletion
    timer = threading.Timer(global_vars.FILE_DELETION_DELAY, deleteResource, args = (new_path,)) 
    timer.start()

    return new_path



def serveRandomFileFromBuffer(target_directory: str) -> str:
    """
    Returns the path to a random image in the buffer (for immediate serving), and queues it for local deletion
    """
    # Choose a random file from the given directory
    random_file_path = getRandomFileInDirectory(target_directory)

    # Migrates to staging dir and schedules returned file for deletion in 30 seconds (assumes this is sufficient time for a download)
    if random_file_path != "File not found":
        staged_path = serveFile(random_file_path)
        if staged_path == "Invalid path(s)":
            console_out(f"Failed to serve chosen file '{random_file_path}' due to a bad path.", LogLevel.FAILURE)
            return "Bad path"
    else:
        return "File not found"
    
    return staged_path



def addFileToBufferDirectory(target_directory: str, new_file_basename: str, file: object) -> str:
    """
    Multi-type function to save a given file object to buffer
    Takes directory, new basename, and the file object (FileStorage or AudioSegment)
    Returns new file path
    """
    # validate directory existance
    if not os.path.exists(target_directory):
        console_out(f"Filepath '{target_directory}' cannot be referenced, does not exist.", LogLevel.ERROR, exit_code = 6)

    new_file_name = os.path.join(target_directory, new_file_basename)
    # validate input type and execute accordingly
    # note that the directory being a buffer dir is not checked explicitly, because the pre-save calls of incrementBufferDirectoryCountByPath(target_directory) will error the program if the path is not a buffer        
    dir_is_oversized: bool = incrementBufferDirectoryCountByPath(target_directory)[1]
    try:
        match file:
            case FileStorage():
                if dir_is_oversized:
                    deleteResource(getRandomFileInDirectory(target_directory))
                file.save(new_file_name)
                console_out(f"File saved as '{new_file_name}'", LogLevel.SUCCESS)
            case AudioSegment():
                if dir_is_oversized:
                    deleteResource(getRandomFileInDirectory(target_directory))
                file.export(new_file_name, format = "mp3")
                console_out(f"File saved as '{new_file_name}'", LogLevel.SUCCESS)
            case _:
                console_out(f"File cannot be saved to buffer, is not an accepted type (FileStorage | pydub.AudioSegment).", LogLevel.ERROR, exit_code = 5)       
    except Exception as e:
        console_out(f"Could not save file '{new_file_name}', an unexpected error occured: {e}.", LogLevel.WARN)
        incrementBufferDirectoryCountByPath(target_directory, True)
        return f"Exception: {e}"
    
    return new_file_name



def incrementBufferDirectoryCountByPath(target_directory: str, decrement: bool = False, unsafe: bool = False) -> tuple[int, bool]:
    """
    Adjusts tracking variable for buffer directory sizes
    Accepts the target directory, and optionally a bool to decrement instead of increment.
    By default, this will error if a non-buffer dir is provided, but it can be made to fail silently if "unsafe" is set to true
    Returns a tuple with the updated directory size, or -1 if the directory is not a buffer, and a bool indicating if this is over the set cap
    """
    adjustment = 1 if not decrement else -1
    match target_directory:
        case global_vars.AUDIO_DIRECTORY:
            global_vars.audio_count += adjustment
            return (global_vars.audio_count, global_vars.audio_count > global_vars.AUDIO_MAX_COUNT)
        case global_vars.CORPORA_DIRECTORY:
            global_vars.corpus_count += adjustment
            return (global_vars.corpus_count, global_vars.corpus_count > global_vars.CORPUS_MAX_COUNT)
        case global_vars.IMAGE_DIRECTORY:
            global_vars.image_count += adjustment
            return (global_vars.image_count, global_vars.image_count > global_vars.IMAGE_MAX_COUNT)
        case global_vars.INTAKE_DIRECTORY:
            global_vars.intake_count += adjustment
            return (global_vars.intake_count, global_vars.intake_count > global_vars.INTAKE_MAX_COUNT)
        case global_vars.DELIVERY_DIRECTORY:
            global_vars.delivery_count += adjustment
            return (global_vars.delivery_count, global_vars.delivery_count > global_vars.DELIVERY_MAX_COUNT)
        case _:
            if not unsafe:
                console_out(f"Target dirctory '{target_directory}' cannot be saved to, is not a buffer dir or does not exist", LogLevel.ERROR, exit_code = 6)
            return (-1, False)
        


def trimDirectory(target_directory: str, directory_file_max_count: int) -> int:
    """
    Deletes files in a directory until it is at the specified max count
    Returns the number of files left after trim
    """
    print(f"trimming directory {target_directory}")
    files = listDirectoryFiles(target_directory)

    while len(files) > directory_file_max_count:
        file_to_delete = random.choice(files)
        deleteResource(os.path.join(target_directory, file_to_delete))
        files.remove(file_to_delete)

    if files: 
        return len(files)
    else:
        return 0