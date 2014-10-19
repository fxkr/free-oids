import flask
import flask_wtf

from freeoids import app
from freeoids import backend


class RequestForm(flask_wtf.Form):
    recaptcha = flask_wtf.RecaptchaField()


@app.route("/")
def index():
    form = RequestForm()
    use_recaptcha = app.config.get('RECAPTCHA_ENABLED')
    if not use_recaptcha:
        del form.recaptcha

    return flask.render_template('index.html', form=form, use_recaptcha=use_recaptcha)

@app.route("/assignment", methods=["GET"])
def assignment_get():
    return flask.redirect(flask.url_for('index'))

@app.route("/assignment", methods=["POST"])
def assignment():
    form = RequestForm()
    use_recaptcha = app.config.get('RECAPTCHA_ENABLED')
    if not use_recaptcha:
        del form.recaptcha

    new_assignment = backend.assign_oid()
    if not form.validate_on_submit():
        return flask.redirect(flask.url_for('index'))
    return flask.render_template('assignment.html', assignment=new_assignment)

