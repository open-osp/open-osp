import sys

from flask import render_template, request, session, redirect

from app import app, pagedown
from forms import PageDownForm, LoginForm
from utils import authenticate_user

@app.route('/properties/')
def index():
    if session.get('logged_in'):
        return redirect('/properties/edit')
    else:
        return redirect('/properties/login')

@app.route('/properties/login', methods=['GET', 'POST'])
def login_properties():
    session.permanent = True

    form = LoginForm()

    context = {
        'form': form
    }

    if request.method == 'POST':
        if form.validate_on_submit():
            username = request.form.get('username')
            password = request.form.get('password')
            authenticated = authenticate_user(username, password)
            context['error'] = 'Succesfully logged in!'

            if not authenticated:
                context['error'] = 'Invalid credentials!'
            else:
                redirect('/properties')

    return render_template('login.html', **context)


@app.route('/properties/edit', methods=['GET', 'POST'])
def edit_properties():
    oscar_properties = open('oscar_mcmaster_bc.properties', 'r+')

    form = PageDownForm()
    form.pagedown.data = oscar_properties.read()

    context = {
        'form': form,
    }

    if request.method == 'POST':
        if form.validate_on_submit():
            markdown = request.form.get('pagedown')

            oscar_properties = open('oscar_mcmaster_bc.properties', 'w')
            oscar_properties.write(markdown)
            oscar_properties.truncate()

            form.pagedown.data = markdown
            context['submitted'] = True
            context["form"] = form

    return render_template('index.html', **context)
