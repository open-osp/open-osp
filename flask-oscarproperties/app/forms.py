from flask_wtf import Form
from flask_pagedown.fields import PageDownField
from wtforms.fields import SubmitField, TextField, PasswordField
from wtforms.validators import DataRequired

class PageDownForm(Form):
    pagedown = PageDownField('Enter your markdown')
    submit = SubmitField('Submit')

class LoginForm(Form):
    username = TextField('Username', validators=[DataRequired()])
    password = PasswordField('Password', validators=[DataRequired()])
    submit = SubmitField('Submit')