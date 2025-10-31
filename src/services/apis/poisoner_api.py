import markovify
from http import HTTPStatus
from flask import request, send_file
from flask_restx import Namespace, Resource
from werkzeug.datastructures import FileStorage
import core.markov
import core.images

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
        """
        Add input string to the corpus buffer and active markov chain
        Pass input as a string named "content"
        """
        args = text_in_parser.parse_args()
        # Add to the model.
        core.markov.addToCorpus(args["content"])
        return "Resource added", 201
    
    @poison_ns.expect(text_out_parser)
    def get(self):
        """
        Return a generated string of X (1 <= X <= 100, default 3) sentences from the markov chain
        Pass number of sentences as an int named "numsentences"
        If generating numsentences fails, it will try to fall back to 3 sentences. 
        If that also fails, it will return an error string.
        """
        args = text_out_parser.parse_args()
        numsentences = args["numsentences"] or 3
        if numsentences < 1: numsentences = 1
        if numsentences > 100: numsentences = 100
        # Pull sentences from the model
        output = core.markov.getXSentences(numsentences)
        # If it fails on user number, falls back to three sentences
        # If that also fails, will return the error message
        if output[:5] == "ERORR":
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
    API for processing poison text data
    """

    @poison_ns.response(HTTPStatus.OK.value, "Object added")
    @poison_ns.expect(image_in_parser)
    def post(self):
        """
        Adds input image (not link, actual image) to the poison buffer
        NOTE: does not poison images. Assumes they have been tampered with ahead of time.
        """
        if "image" not in request.files:
            poison_ns.abort(400, "No image file provided")

        image_file = request.files['image']

        if not image_file.filename:
            poison_ns.abort(400, "No selected file")

        status = core.images.saveImageFromPost(image_file)
        if len(status) is 1 and status[0] is True:
            return "Resource added", 201
        elif len(status) is 2 and status[0] is False:
            poison_ns.abort(500, f"Error processing image: {str(status[1])}")
        else:
            poison_ns.abort(500, f"Error processing image (bad function return): {str(status[1])}") # this should never happen
        
    
    # @poison_ns.expect(image_out_parser)
    def get(self):
        """
        Return an image and remove it from the buffer
        """
        image_path = core.images.getImageFromBuffer()
        
        if image_path is "Image not found":
            poison_ns.abort(404, "Image not found")
            
        return send_file(image_path, as_attachment = True)
