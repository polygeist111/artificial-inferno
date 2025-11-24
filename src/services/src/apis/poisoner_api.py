"""
API definition for poisoner functions
"""

### Imports
# Standard
import random
from http import HTTPStatus

# Third Party
from flask import request, send_file
from flask_restx import Namespace, Resource
from werkzeug.datastructures import FileStorage

# Local
import core.markov
import core.images
import core.audio


poison_ns = Namespace("poison", description="Poisoning operations")



text_in_parser = poison_ns.parser()
text_in_parser.add_argument("content", 
                            type=str)

text_out_parser = poison_ns.parser()
text_out_parser.add_argument("numsentences", 
                             type=int)

@poison_ns.route("/text")
class PoisonTextApi(Resource):
    """
    API for processing poison text data
    """

    @poison_ns.response(HTTPStatus.OK.value, "Object added")
    @poison_ns.expect(text_in_parser)
    def post(self):
        r"""
        Add input string to the corpus buffer and active markov chain
        Pass input as a string named "content"

        Example usage:
        curl -X POST \                        
            -H "Content-Type: application/json" \
            -d '{"content": "This is an example sentence to be uploaded to the markov chain."}' \
            127.0.0.1:5000/poison/text
        """
        args = text_in_parser.parse_args()
        # Add to the model.
        core.markov.addToCorpus(args["content"])
        return "Resource added", 201
    
    @poison_ns.expect(text_out_parser)
    def get(self):
        r"""
        Return a generated string of X (1 <= X <= 100, default 3) sentences from the markov chain
        Pass number of sentences in JSON as an int named "numsentences"
        If generating numsentences fails, it will try to fall back to 3 sentences. 
        If that also fails, it will return an error string.

        Example usage:
        curl -X GET \
            -H "Content-Type: application/json" \
            -d '{"numsentences": 5}' \
            127.0.0.1:5000/poison/text
        """
        args = text_out_parser.parse_args()
        numsentences = args["numsentences"] or 3
        if numsentences < 1: numsentences = 1
        if numsentences > 100: numsentences = 100
        # Pull sentences from the model
        output = core.markov.getXSentences(numsentences)
        # If it fails on user number, falls back to three sentences
        # If that also fails, will return the error message
        if output[:5] == "ERROR":
            output = core.markov.getXSentences(3)
        return output



image_in_parser = poison_ns.parser()
image_in_parser.add_argument("image", 
                             type = FileStorage, 
                             location = "files", 
                             required = True, 
                             help = "Image file to upload to poisoner API")

@poison_ns.route("/images")
class PoisonImagesApi(Resource):
    """
    API for processing poison image data
    """

    @poison_ns.response(HTTPStatus.OK.value, "Object added")
    @poison_ns.expect(image_in_parser)
    def post(self):
        r"""
        Adds input image (not link, actual image) to the poison buffer
        NOTE: does not poison images. Assumes they have been tampered with ahead of time.

        Example usage:
        curl -X POST \
            -F "image=@dev-help/samples-input/rhino_owl_mask_gridview.jpeg" \
            127.0.0.1:5000/poison/images
        """
        if "image" not in request.files:
            poison_ns.abort(400, "No image file provided")

        image_file = request.files["image"]

        if not image_file.filename:
            poison_ns.abort(400, "No selected file")

        status = core.images.saveImageFromPost(image_file)
        status_length = len(status)
        if status_length == 1 and status[0] == 0:
            return "Resource added", 201
        elif status_length == 2 and status[0] == 1:
            poison_ns.abort(500, f"Error processing image: {str(status[1])}")
        elif status_length == 1 and status[0] == 2:
            poison_ns.abort(400, f"Error processing image: must be jpg")
        elif status_length == 1 and status[0] == 3:
            poison_ns.abort(400, f"Error processing file: must be image file (jpg)")
        else:
            poison_ns.abort(500, f"Error processing image: bad function return") # this should never happen
        
    
    # @poison_ns.expect(image_out_parser)
    def get(self):
        r"""
        Return an image and remove it from the buffer

        Example usage:
        curl -v --output dev-help/samples-output/requested-img.jpg -X GET \
            127.0.0.1:5000/poison/images
        """
        image_path = core.images.getImageFromBuffer()
        
        if image_path == "File not found":
            poison_ns.abort(404, "Image not found: server image buffer is currently empty.")
        elif image_path == "Bad path":
            poison_ns.abort(500, f"Error serving image: bad internal filepath")
            
        return send_file(image_path, as_attachment = True)



audio_in_parser = poison_ns.parser()
audio_in_parser.add_argument("audio", 
                             type = FileStorage, 
                             location = "files", 
                             required = True, 
                             help = "Audio file to upload to poisoner API")
audio_out_parser = poison_ns.parser()
audio_out_parser.add_argument("clip_duration", 
                             type=int)

@poison_ns.route("/audio")
class PoisonAudioApi(Resource):
    """
    API for processing poison audio data
    """

    @poison_ns.response(HTTPStatus.OK.value, "Object added")
    @poison_ns.expect(audio_in_parser)
    def post(self):
        r"""
        Adds input audio (not link, actual audio) to the poison buffer
        NOTE: does not poison audio in the classical sense. 
        Instead, chunks them out by time sections, shuffles, and reorganizes them

        Example usage:
        curl -X POST \
            -F "audio=@dev-help/samples-input/rhino_owl_mask_gridview.jpeg" \
            127.0.0.1:5000/poison/audio
        """
        if "audio" not in request.files:
            poison_ns.abort(400, "No audio file provided")

        audio_file = request.files["audio"]

        if not audio_file.filename:
            poison_ns.abort(400, "No selected file")

        status = core.audio.saveAudioFromPost(audio_file)
        status_length = len(status)
        if status_length == 1 and status[0] == 0:
            return "Resource added", 201
        elif status_length == 2 and status[0] == 1:
            poison_ns.abort(500, f"Error processing audio: {str(status[1])}")
        elif status_length == 1 and status[0] == 2:
            poison_ns.abort(400, f"Error processing audio: must be mp3")
        elif status_length == 1 and status[0] == 3:
            poison_ns.abort(400, f"Error processing file: must be an audio file (mp3)")
        else:
            poison_ns.abort(500, f"Error processing audio: bad function return") # this should never happen
        
    
    # @poison_ns.expect(image_out_parser)
    def get(self):
        r"""
        Return a stitched audio clip of X (1 <= X <= 100, default 3) seconds from the audio buffer
        Pass number of seconds of audio in JSON as an int named "clip_duration"
        If returning clip_duration seconds of audio fails, it will return a shorter clip of the max possible size in the buffer. 
        If that also fails, it will return an error string.

        Example usage:
        curl -v --output dev-help/samples-output/requested-audio.mp3 -X GET \
            -H "Content-Type: application/json" \
            -d '{"clip_duration": 5}' \
            127.0.0.1:5000/poison/audio
        """
        args = audio_out_parser.parse_args()
        clip_duration = args["clip_duration"] or random.choice(range(3, 11))
        if clip_duration < 1: clip_duration = 1
        if clip_duration > 100: clip_duration = 100

        audio_path = core.audio.getAudioFromBuffer(clip_duration)
        
        if audio_path == "File not found":
            poison_ns.abort(404, "Audio not found: server audio buffer is currently empty.")
        elif audio_path == "Bad path":
            poison_ns.abort(500, f"Error serving audio: bad internal filepath")
            
        return send_file(audio_path, as_attachment = True)
