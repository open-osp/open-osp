import os

from flask import session

def authenticate_user(username, password):
    env_username = str(os.environ.get('FLASK_USERNAME'))
    env_password = str(os.environ.get('FLASK_PASSWORD'))

    print("{}{}".format(username, password))
    print("{}{}".format(env_username, env_password))

    if username == env_username and password == env_password:
        session['logged_in'] = True
        return True
    else:
        
        return False