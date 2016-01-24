# !/usr/bin/python
# -*- coding: utf-8 -*-

import os

from flask import Flask, render_template, jsonify
from flask_compress import Compress
import geo
from natsort import natsorted
from operator import itemgetter

app = Flask(__name__)

# #################################
# config and init for flask plugins
# #################################

# Flask-compress
################

# gzip compression
# should be already done by apache/nginx, but just to be sure :)
compress = Compress()
compress.defaults = [
    ('COMPRESS_MIMETYPES', ['text/html', 'text/css', 'text/xml',
                            'application/json',
                            'application/javascript',
                            'application/pdf', 'image/svg+xml']),
    ('COMPRESS_DEBUG', True),
    ('COMPRESS_LEVEL', 6),
    ('COMPRESS_MIN_SIZE', 50)]
Compress(app)


################
# personal needs
################

# trim spaces from templates
app.jinja_env.trim_blocks = True
app.jinja_env.lstrip_blocks = True

# This is the path to the upload directory
app.config['UPLOAD_FOLDER'] = 'upload/'

###########################
# app fonctions and classes
###########################


class iterate_trace(object):
    """
    iterator from a waypoint file, return a dict with
    the chosen id, latitude and longitude.

    this file format is from a Garmin track file in TXT
    format, thanks to Mapsource export. make changes to
    this class to reflect your data.
    """

    def __init__(self, fichier, identification):
        self.fichier = fichier
        self.identification = identification

    def __iter__(self):
        with open(self.fichier) as f:
            for line in f:
                if line.startswith('Trackpoint'):
                    a = line.split()
                    lat, lon = geo.parse_position(a[1] + " " + a[2])
                    trace = {'id': self.identification, 'lat': lat, 'lon': lon}
                    yield trace


def get_poi():
    """
    get a txt file with GPS coordinates and other various infos.
    return a list of points: [name, lat, lon, color],
    natural-sorted by name and with some personal needs.

    this file format is from a Garmin waypoints file in TXT format,
    thanks to Mapsource export. make changes to this fonction
    to reflect your data.
    """
    try:
        poi = []
        with open(os.path.join(app.config['UPLOAD_FOLDER'], 'controle.txt'), 'r') as gps_poi:
            for line in gps_poi:
                if line.startswith('Waypoint'):
                    splitted_line = line.split()
                    name, color, latitude, longitude = splitted_line[1], splitted_line[-4], splitted_line[6], splitted_line[7]
                    point = geo.parse_position(latitude + " " + longitude)
                    poi.append([name, point[0], point[1], color])
    except:
        return list()

    # we want it sorted by name, real-life natural order
    poi = natsorted(poi, key=itemgetter(0))
    # start of the race is always at the end of the list on this file, should be on 1st place
    poi.insert(0, poi.pop())

    return poi


V1 = iter(iterate_trace(fichier = os.path.join(app.config['UPLOAD_FOLDER'], 'n1.txt'), identification = 1))
V2 = iter(iterate_trace(fichier = os.path.join(app.config['UPLOAD_FOLDER'], 'n3.txt'), identification = 2))


#########
# Routing
#########
# n.b: first, the route (@app.route, @app.errorhandler,....),
# THEN, decorators (@login.required, @mimerender,....)

@app.route('/')
def mapping():
    poi = get_poi()
    print(poi)
    return render_template('tracking.tpl', poi=poi)

# example of GEOjson "flask-ified"
# not needed if you have another source
@app.route('/track')
def track():

    voiture1 = V1.next()
    voiture2 = V2.next()
    voitures = {"type": "FeatureCollection", 
                "features": [
                               {"type": "Feature",
                                "properties": {
                                            "popupContent": "<b>opponent #1</b><br />minus & cortex<br />",
                                            "id": 1
                                            },
                                "geometry": {
                                    "type": "Point",
                                            "coordinates": [voiture1['lon'], voiture1['lat']]
                                        }
                                    },
                               {"type": "Feature",
                                "properties": {
                                            "popupContent": "<b>opponent #2</b><br />laurel & hardy<br />",
                                            "id": 2
                                            },
                                "geometry": {
                                    "type": "Point",
                                            "coordinates": [voiture2['lon'], voiture2['lat']]
                                        }
                                    }
                           ]
                }

    return jsonify(voitures)


if __name__ == '__main__':
    app.run(debug=True)
