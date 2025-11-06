"""
API initializer
"""

### Imports
# Standard

# Third Party
from flask_restx import Api

# Local
from .poisoner_api import poison_ns




api = Api(
    version='1.0',
    title='Artificial Inferno API',
    description='All endpoints for handling data poisoning, poison buffering, and tarpit monitoring for',
    doc='/docs/'  # Swagger UI endpoint
)

api.add_namespace(poison_ns, path="/poison")