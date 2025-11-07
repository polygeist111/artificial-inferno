"""
Module to handle image-specific actions
"""

### Imports
# Standard
import time
import threading

# Third Party
from werkzeug.datastructures import FileStorage
import filetype

# Local
import global_vars
from core.messaging import console_out, LogLevel
import core.filehandling as filehandling

def saveImageFromPost(imageIn: FileStorage):
    """
    Validates and saves image POSTed to the API
    """
    image_directory = global_vars.IMAGE_DIRECTORY
    write_time = time.time()
    new_file_path = f"{image_directory}/image_{write_time}.jpg"

    # If image buffer is full, delete a random file
    directory_has_space = filehandling.validateDirectorySize(image_directory, global_vars.IMAGE_MAX_COUNT, True)
    if directory_has_space == 1:
        # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
        # This is a safety delay to ensure an image currently being downloaded by another request is not deleted prior
        console_out(f"Image buffer would be overflowed by file uploaded at {write_time}, queuing a random image file for deletion.", LogLevel.WARN)
        timer = threading.Timer(global_vars.FILE_DELETION_DELAY, deleteResource, args = (getRandomFileInDirectory(image_directory),)) # type: ignore
        timer.start()
    elif directory_has_space == 2:
        console_out(f"Image buffer would be significantly overflowed by file uploaded at {write_time}, deleting a random image file immediately.", LogLevel.WARN)
        filehandling.deleteResource(filehandling.getRandomFileInDirectory(image_directory)) # if the image buffer is being overflowed, delete a file immediately at risk of failing a user request

    try:
        imageIn.save(new_file_path)
    except Exception as e:
        return [1, e]
    
    if filetype.is_image(new_file_path):
        kind = filetype.guess(new_file_path)
        if not (kind and kind.mime == "image/jpeg"):
            filehandling.deleteResource(new_file_path)
            console_out(f"Uploaded file at {new_file_path} will not be saved: The file is an image, but filetype must be 'image/jpeg', not '{kind.mime if kind else 'an unknown type'}'.", LogLevel.FAILURE)
            return [2] # fail because non jpg image
    else:
        filehandling.deleteResource(new_file_path)
        console_out(f"Uploaded file at {new_file_path} will not be saved: The file is not an image.", LogLevel.FAILURE)
        return [3] # fail because nonimage file
    
    return [0] # success, jpg image
    


def getImageFromBuffer() -> str:
    """
    Returns the path to a random image in the buffer (for immediate serving), and queues it for local deletion
    """
    # Choose a random file from the image directory
    random_file_path = filehandling.getRandomFileInDirectory(global_vars.IMAGE_DIRECTORY)

    # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
    timer = threading.Timer(global_vars.FILE_DELETION_DELAY, deleteResource, args = (random_file_path,)) # type: ignore
    timer.start()

    return random_file_path