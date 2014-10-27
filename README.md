# OID Selfservice

* Author: `Felix Kaiser <felix.kaiser@fxkr.net>`
* License: MIT license

## How to run

1. Run `fetch_deps.sh` to download the Python and web dependencies
2. Copy `config.sample.py` to `config.py` and edit it.
3. Enter the Python virtual environment: `source .env/bin/activate`
4. Start it: `python2 launch.py`

## How to deploy

On Debian:

1. See how to run section.
2. Use nginx, install uswgi.
3. Put uswgi config in: `/etc/uwsgi/apps-available/freeoids.ini`:

        [uwsgi]
        plugins = python
        chdir = /srv/www/.../
        env = FREEOIDS_SETTINGS=/.../config.py
        virtualenv = /.../.env
        module = wsgi
        callable = app
        chmod-socket = 664
        uid = nginx
        gid = nginx

4. Enable it: `ln -s /etc/uwsgi/apps-available/freeoids.ini /etc/uwsgi/apps-enabled/`
5. Write nginx config. Put this outside the `server` section:

        upstream freeoids {
            server unix:///run/uwsgi/app/freeoids/socket;
        }

   And this inside the `server` section:

        location @freeoids {
            include uwsgi_params;
            uwsgi_pass freeoids;
        }


# Limitations

It's not webscale :)

