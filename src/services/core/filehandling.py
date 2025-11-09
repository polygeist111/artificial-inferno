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

#Local
from core.messaging import console_out, LogLevel
import global_vars



def deleteResource(filepath: str) -> bool:
    """
    Safely removes a resource at the given path
    """
    if os.path.exists(filepath):
        os.remove(filepath)
        console_out(f"File '{filepath}' successfully deleted.", LogLevel.SUCCESS)
        return True
    console_out(f"File '{filepath}' cannot be deleted, does not exist", LogLevel.FAILURE)
    return False



def validateDirectorySize(directory_path: str, max_size: int, adding: bool = False, trim: bool = False) -> bool:
    """
    Checks if a given directory contains fewer than the stated maximum number of files
    If Adding is true, calculates size relative to addition op (i.e. actual size + 1)
    If Trim is true AND adding is true, the function will randomly drop a file from the directory if it's currently full
    Trim has no effect while adding is false
    """
    files_in_dir = listDirectoryFiles(directory_path)
    new_dir_size = len(files_in_dir)
    if adding:
        new_dir_size += 1

    if new_dir_size <= max_size:
        return True
    else:
        if adding and trim:
            console_out(f"Directory '{directory_path}' is full, and a file is to be added. Deleting one random file in the directory to make space.", LogLevel.INFO)
            deleteResource(getRandomFileInDirectory(directory_path))
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



def clearFileSendBuffer():
    """
    When called, empties the waiting folder for files that have been sent
    No files should be stuck there, except when the server is shut down while one is present
    """
    staged_files = listDirectoryFiles(global_vars.DELIVERY_DIRECTORY)
    for file in staged_files:
        deleteResource(file)



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



def serveRandomFileFromBuffer(target_directory) -> str:
    """
    Returns the path to a random image in the buffer (for immediate serving), and queues it for local deletion
    """
    # Choose a random file from the given directory
    random_file_path = getRandomFileInDirectory(target_directory)

    # Migrates to staging dir and schedules returned file for deletion in 30 seconds (assumes this is sufficient time for a download)
    if random_file_path != "File not found":
        staged_path = serveFile(random_file_path)
        if staged_path == "Invalid path(s)":
            console_out(f"Failed to serve chosen file '{random_file_path}' due to a bad path", LogLevel.FAILURE)
            return "Bad path"
    else:
        return "File not found"
    
    return staged_path