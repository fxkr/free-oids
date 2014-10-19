import flask

from freeoids import app
from freeoids import backend


@app.route("/")
def index():
    return flask.render_template('index.html')

@app.route("/assignment", methods=["GET"])
def assignment_get():
    return flask.redirect(flask.url_for('index'))

@app.route("/assignment", methods=["POST"])
def assignment():
    new_assignment = backend.assign_oid()
    return flask.render_template('assignment.html', assignment=new_assignment)

