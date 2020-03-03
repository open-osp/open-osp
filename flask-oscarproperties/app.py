
import markdown
import markdown.extensions.fenced_code
import os
import re
import sys

from flask import Flask, render_template

app = Flask(__name__)

@app.route('/')
def index():

    # Create markdown html
    properties_file = open("oscar_mcmaster_bc.properties", "r")
    md_template_string = markdown.markdown(
        properties_file.read(), extensions=["fenced_code"]
    )

    # get all variables in properties
    pattern = re.compile("^\w.*")
    matches = []
    with open('oscar_mcmaster_bc.properties', 'r') as file:
        for line in file:
            found = pattern.findall(line)
            print(found, file=sys.stderr)
            if found and len(found) > 0:
                matches = matches + found
    
    # generate key value pairs
    variables = {}
    for match in matches:
        values = match.split('=')
        variables[values[0]] = values[1]

    print(variables, file=sys.stderr)
    
    return render_template("index.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)