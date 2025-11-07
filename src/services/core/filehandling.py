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
        console_out(f"File at {filepath} successfully deleted.", LogLevel.SUCCESS)
        return True
    console_out(f"Filepath {filepath} cannot be deleted, does not exist", LogLevel.FAILURE)
    return False



def validateDirectorySize(directory_path: str, max_size: int, adding: bool) -> int:
    """
    Checks if a given directory contains fewer than the stated maximum number of files
    """
    files_in_dir = listDirectoryFiles(directory_path)
    new_dir_size = len(files_in_dir)
    if adding:
        new_dir_size += 1

    if new_dir_size <= max_size:
        return 0
    elif new_dir_size > max_size * 1.5: # safety check to prevent overflowing a directory buffer inside the file deletion window
        return 2
    return 1



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
    selected_file = ""
    files = listDirectoryFiles(directory_path)
    if len(files) > 0:
        selected_file = os.path.join(directory_path, random.choice(files))
    return selected_file



def pruneBufferedFiles():
    """
    When called, randomly deletes files in image and audio directories until they meet their maximums
    """
    # prune image folder
    image_files = listDirectoryFiles(global_vars.IMAGE_DIRECTORY)
    image_length = len(image_files)
    while image_length > global_vars.IMAGE_MAX_COUNT:
        deleteResource(getRandomFileInDirectory(global_vars.IMAGE_DIRECTORY))
        image_length -= 1

    # prune audio folder
    audio_files = listDirectoryFiles(global_vars.AUDIO_DIRECTORY)
    audio_length = len(audio_files)
    while audio_length > global_vars.AUDIO_MAX_COUNT:
        deleteResource(getRandomFileInDirectory(global_vars.AUDIO_DIRECTORY))
        audio_length -= 1
        