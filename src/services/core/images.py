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

#Local

image_directory = "data/images/"

def saveImageFromPost(imageIn: FileStorage):
    write_time = time.time()
    new_file_path = f"{image_directory}/corpus_{write_time}"
    try:
        imageIn.save(new_file_path)
        return [True]
    except Exception as e:
        return [False, e]
    


def getImageFromBuffer() -> str:
    # Get a list of all files and subdirectories in the given path
    all_images = os.listdir(image_directory)

    # Filter out directories, keeping only files
    images = [entry for entry in all_images if os.path.isfile(os.path.join(image_directory, entry))]

    if not images:
        print(f"No files found in directory '{image_directory}'.")
        return "No image found"

    # Choose a random file from the list
    random_filename = random.choice(images)

    # Construct the full path to the random file
    random_file_path = os.path.join(image_directory, random_filename)

    # Schedule returned image for deletion in 30 seconds (assumes this is sufficient time for a download)
    timer = threading.Timer(30, deleteUsedResource(random_file_path))
    timer.start()

    return random_file_path



def deleteUsedResource(filepath) -> bool:
    if os.path.exists(filepath):
        os.remove(filepath)
        return True
    print(f"Filepath {filepath} cannot be deleted, does not exist")
    return False

# TODO: consider breaking random file selection out into core helper function, same with file deletion
# TODO: add constraints on file addition, like corpora buffer