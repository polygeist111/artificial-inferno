"""
Module to handle all actions dealing with image files
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

image_directory = "data/images/"
audio_directory = "data/audio/"

def saveImageFromPost(imageIn: FileStorage):
    """
    Validates and saves image POSTed to the API
    """
    write_time = time.time()
    new_file_path = f"{image_directory}/image_{write_time}.jpg"

    # If image buffer is full, delete a random file
    directory_has_space = validateDirectorySize(image_directory, global_vars.IMAGE_MAX_COUNT, True)
    if directory_has_space == 1:
        # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
        # This is a safety delay to ensure an image currently being downloaded by another request is not deleted prior
        console_out(f"Image buffer would be overflowed by file uploaded at {write_time}, queuing a random image file for deletion.", LogLevel.WARN)
        timer = threading.Timer(global_vars.FILE_DELETION_DELAY, deleteResource, args = (getRandomFileInDirectory(image_directory),)) # type: ignore
        timer.start()
    elif directory_has_space == 2:
        console_out(f"Image buffer would be significantly overflowed by file uploaded at {write_time}, deleting a random image file immediately.", LogLevel.WARN)
        deleteResource(getRandomFileInDirectory(image_directory)) # if the image buffer is being overflowed, delete a file immediately at risk of failing a user request

    try:
        imageIn.save(new_file_path)
    except Exception as e:
        return [1, e]
    
    if filetype.is_image(new_file_path):
        kind = filetype.guess(new_file_path)
        if not (kind and kind.mime == "image/jpeg"):
            deleteResource(new_file_path)
            console_out(f"Uploaded file at {new_file_path} will not be saved: The file is an image, but filetype must be 'image/jpeg', not '{kind.mime if kind else 'an unknown type'}'.", LogLevel.FAILURE)
            return [2] # fail because non jpg image
    else:
        deleteResource(new_file_path)
        console_out(f"Uploaded file at {new_file_path} will not be saved: The file is not an image.", LogLevel.FAILURE)
        return [3] # fail because nonimage file
    
    return [0] # success, jpg image
    


def getImageFromBuffer() -> str:
    """
    Returns the path to a random image in the buffer (for immediate serving), and queues it for local deletion
    """
    # Choose a random file from the image directory
    random_file_path = getRandomFileInDirectory(image_directory)

    # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
    timer = threading.Timer(global_vars.FILE_DELETION_DELAY, deleteResource, args = (random_file_path,)) # type: ignore
    timer.start()

    return random_file_path



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
    image_files = listDirectoryFiles(image_directory)
    image_length = len(image_files)
    while image_length > global_vars.IMAGE_MAX_COUNT:
        deleteResource(getRandomFileInDirectory(image_directory))
        image_length -= 1

    # prune audio folder
    audio_files = listDirectoryFiles(audio_directory)
    audio_length = len(audio_files)
    while audio_length > global_vars.AUDIO_MAX_COUNT:
        deleteResource(getRandomFileInDirectory(audio_directory))
        audio_length -= 1
        