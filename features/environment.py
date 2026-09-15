import os


def before_scenario(context, scenario):
    context.base_url = os.getenv("PETSTORE_BASE_URL")
    context.headers = {}
    context.body = None
    context.response = None
