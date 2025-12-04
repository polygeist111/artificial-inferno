"""
API definition for poisoner functions
"""

### Imports
# Standard
from http import HTTPStatus

# Third Party
import requests
from flask import jsonify
from flask_restx import Namespace, Resource

# Local
from core.messaging import console_out, LogLevel


monitor_ns = Namespace("monitor", description="Tarpit monitoring operations")



@monitor_ns.route("/current/<path:catchall_path>")
class TarpitQueryPassthroughAPI(Resource):
    """
    API for directly querying current tarpit stats.
    This is a wrapper for calls made directly to the tarpit.
    """
    
    def get(self, catchall_path):
        """
        Usages:
        Overview - /monitor/current/stats
        Agent Strings - /monitor/current/stats/agents
        IP Addresses - /monitor/current/stats/addresses
        Complete Log - /monitor/current/stats/buffer
        You can request results after a given request with id X, you can suffix from/<X> to any of the above endpoints 
        """
        print(catchall_path)
        try:
            response = requests.get("http://division-la.gl.at.ply.gg:8666/" + catchall_path)
            response.raise_for_status()  # Raise an exception for bad status codes
            data = response.json()
            return jsonify(data)
        except requests.exceptions.RequestException as e:
            return jsonify({'error': str(e)}), 500

