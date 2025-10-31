import markovify
from http import HTTPStatus
from flask_restx import Namespace, Resource, fields, reqparse
import core.markov

poison_ns = Namespace("poison", description="Poisoning operations")



text_in_parser = poison_ns.parser()
text_in_parser.add_argument("content", type=str)

text_out_parser = poison_ns.parser()
text_out_parser.add_argument("numsentences", type=int)



@poison_ns.route("/text")
class PoisonTextApi(Resource):
    """
    API for processing poison text data
    """

    @poison_ns.response(HTTPStatus.OK.value, "Object added")
    @poison_ns.expect(text_in_parser)
    def post(self) -> str:
        """
        Add input string to the corpus buffer and active markov chain
        Pass input as a string named "content"
        """
        args = text_in_parser.parse_args()
        # Add to the model.
        core.markov.addToCorpus(args["content"])
        return 201
    
    def get(self) -> str:
        """
        Return a generated string of X (default 3) sentences from the markov chain
        Pass number of sentences as an int named "numsentences"
        If generating numsentences fails, it will try to fall back to 3 sentences. 
        If that also fails, it will return an error string.
        """
        args = text_out_parser.parse_args()
        numsentences = args["numsentences"] or 3
        # Pull sentences from the model
        output = core.markov.getXSentences(numsentences)
        # If it fails on user number, falls back to three sentences
        # If that also fails, will return the error message
        if output[:5] == "ERORR":
            output = core.markov.getXSentences(3)
        return output

