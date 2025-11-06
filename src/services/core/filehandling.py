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

image_directory = "data/images/"

def saveImageFromPost(imageIn: FileStorage):
    write_time = time.time()
    new_file_path = f"{image_directory}/image_{write_time}.jpg"
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
    # Get a list of all files and subdirectories in the given path
    all_images = os.listdir(image_directory)

    # Filter out directories, keeping only files
    images = [entry for entry in all_images if os.path.isfile(os.path.join(image_directory, entry))]

    if not images:
        console_out(f"No files found in directory '{image_directory}'.", LogLevel.FAILURE)
        return "No image found"

    # Choose a random file from the list
    random_filename = random.choice(images)

    # Construct the full path to the random file
    random_file_path = os.path.join(image_directory, random_filename)

    # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
    timer = threading.Timer(30, deleteResource, args = (random_file_path,)) # type: ignore
    timer.start()
    
    print(f"\n\n{random_file_path}\n\n")
    return random_file_path



def deleteResource(filepath) -> bool:
    if os.path.exists(filepath):
        os.remove(filepath)
        console_out(f"File at {filepath} successfully deleted.", LogLevel.SUCCESS)
        return True
    console_out(f"Filepath {filepath} cannot be deleted, does not exist", LogLevel.FAILURE)
    return False

# TODO: consider breaking random file selection out into core helper function, same with file deletion
# TODO: add constraints on file addition, like corpora buffer