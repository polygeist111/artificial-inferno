"""
Module to handle image-specific actions
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



def saveImageFromPost(imageIn: FileStorage):
    """
    Validates and saves image POSTed to the API
    """
    image_directory = global_vars.IMAGE_DIRECTORY
    write_time = time.time()
    new_file_path = f"{image_directory}/image_{write_time}.jpg"

    # If image buffer is full, delete a random file
    filehandling.validateDirectorySize(image_directory, global_vars.IMAGE_MAX_COUNT, True, True)

    try:
        imageIn.save(new_file_path)
    except Exception as e:
        return [1, e]
    
    if filetype.is_image(new_file_path):
        kind = filetype.guess(new_file_path)
        if not (kind and kind.mime == "image/jpeg"):
            filehandling.deleteResource(new_file_path)
            console_out(f"Uploaded file at '{new_file_path}' will not be saved: The file is an image, but filetype must be 'image/jpeg' e.g. JPG, not '{kind.mime if kind else 'an unknown type'}'.", LogLevel.FAILURE)
            return [2] # fail because non jpg image
    else:
        filehandling.deleteResource(new_file_path)
        console_out(f"Uploaded file at '{new_file_path}' will not be saved: The file is not an image.", LogLevel.FAILURE)
        return [3] # fail because nonimage file
    
    return [0] # success, jpg image
    


def getImageFromBuffer():
    return filehandling.serveRandomFileFromBuffer(global_vars.IMAGE_DIRECTORY)