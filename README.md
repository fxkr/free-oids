# Free OIDs!

* Author: `Felix Kaiser <felix.kaiser@fxkr.net>`
* License: MIT license

[Object Identifiers (OIDs)][OID] are used to name objects.
OIDs consist of a node in a hierarchically-assigned namespace.
They are mostly used in [SNMP] and [LDAP].

This is a webservice that allows users to get OID prefixes assigned easily.
If you need an OID prefix, you can use our instance:

https://oid.entropia.de/

[OID]: https://en.wikipedia.org/wiki/Object_identifier
[SNMP]: https://en.wikipedia.org/wiki/Simple_Network_Management_Protocol
[LDAP]: https://en.wikipedia.org/wiki/Lightweight_Directory_Access_Protocol


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

