import os
import re
import sys

from flask import Flask
from flask_pagedown import PageDown
from datetime import timedelta

app = Flask(__name__, template_folder="../templates")
pagedown = PageDown(app)

from views import *

app.config['SECRET_KEY'] = os.environ.get('FLASK_SECRET_KEY', 'SDAt62781d')
app.config['PERMANENT_SESSION_LIFETIME'] =  timedelta(minutes=5)

if __name__ == "__main__":
    app.run(host="0.0.0.0", debug=True)