<!DOCTYPE html>
<html lang="fr">
<head>
    <title>Tracking GPS</title>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0">

    <link rel="stylesheet" href="{{url_for('static', filename='css/leaflet.css')}}" />
    <script src="{{url_for('static', filename='js/leaflet.js')}}"></script>
    <script src="{{url_for('static', filename='js/leaflet-realtime.js')}}"></script>
    <script src="{{url_for('static', filename='js/jquery-min.js')}}"></script>
    <style type="text/css">
        body { margin:0; padding:0; }
        #map { position:absolute; top:0; bottom:0; width:100%; }
    </style>
</head>
<body>
    <div id="map"></div>
    <script>
        /*
        custom icons, optionnal when plotting markers.
        specify size, properties...
        */
        var LeafIcon = L.Icon.extend({
            options: {
                iconSize:  [32, 37],
                iconAnchor: [16, 37],
                popupAnchor: [0, -37]
            }
        });
        var Drapeau = L.Icon.extend({
            options: {
                iconSize:  [32, 37],
                iconAnchor: [0, 37],
                popupAnchor: [0, -37]
            }
        });
        var poiBlue = new LeafIcon({iconUrl: "{{url_for('static', filename='icons/poi_blue.png')}}" }),
            poiGreen = new LeafIcon({iconUrl: "{{url_for('static', filename='icons/poi_green.png')}}" }),
            poiRed = new LeafIcon({iconUrl: "{{url_for('static', filename='icons/poi_red.png')}}" }),
            depart = new Drapeau({iconUrl: "{{url_for('static', filename='icons/flag_green.png')}}" }),
            arrivee = new Drapeau({iconUrl: "{{url_for('static', filename='icons/flag_red.png')}}" });


        /*
        creating the map container and associated datas
        */
        // POIs is a list of lists: (name, lat, lon, color)
        var poi = {{ poi }};

        /*
        we have to center the map.
        centering the map to the 1st POI coordinates if any,
        (0, 0) otherwise
        */
        if (poi.length != 0)
            var center = L.latLng(poi[0][1], poi[0][2])
        else
            var center = L.latLng(0, 0)

        var map = L.map('map', {
                        center: center,
                        zoom: 11
                        }),
            realtime = L.realtime({
                /* URL for GEOjson data
                here a fake ISS tracking with a single point,
                but you can serve several points, as much as you need.
                */
				//url: 'https://wanderdrone.appspot.com/',
                url: '{{url_for('track')}}',
                /*
                if GEOjson hosted on another domain.
                may (must?) require additionnal configuration on host server
                */
                crossOrigin: true,
                type: 'json'
            }, {
                // 1 sec refresh
                interval: 1000
            }).addTo(map);


        /*
        create the map layer, the "tiles"
        online, from a "tile server":
        'http://{s}.tile.osm.org/{z}/{x}/{y}.png'

        MUCH, **MUCH** better serve tiles from apache/nginx than flask,
        but just in case, via flask static files:
        'static/mapTiles/{z}/{x}/{y}.png'
        */
        L.tileLayer('http://{s}.tile.osm.org/{z}/{x}/{y}.png', {
            attribution: '&copy; <a href="http://osm.org/copyright">OpenStreetMap</a> contributors'
        }).addTo(map);


        /*
        make updates work and fun:
        updating coordinates, change/update pop-up
        */
        realtime.on('update', function(e) {
            var coordPart = function(v, dirs) {
                    return dirs.charAt(v >= 0 ? 0 : 1) +
                        (Math.round(Math.abs(v) * 100) / 100).toString();
                },
                popupContent = function(fId) {
                    var feature = e.features[fId],
                        c = feature.geometry.coordinates;
                    var name = feature.properties.id
                    if (typeof name == 'undefined'  || name === null) {
                        var name = 'ISS'
                    }
                    else
                        var name = feature.properties.popupContent

                    return name + '<br>' +
                        coordPart(c[0], 'NS') + ', ' + coordPart(c[1], 'EW');
                },
                bindFeaturePopup = function(fId) {
                    realtime.getLayer(fId).bindPopup(popupContent(fId));
                },
                updateFeaturePopup = function(fId) {
                    realtime.getLayer(fId).getPopup().setContent(popupContent(fId));
                };
            var bounds = map.getBounds()
            map.fitBounds(bounds);

            Object.keys(e.enter).forEach(bindFeaturePopup);
            Object.keys(e.update).forEach(updateFeaturePopup);
        });


        /*
        plot POI supplied by flask poi variable.
        in my use case, race checkpoint, with some custom properties.
        */

        for (var i = 0; i < poi.length; i++) {
            circle = new L.circle([poi[i][1], poi[i][2]], 15, {color: 'green', weight: 1}).addTo(map);
            switch (poi[i][3]) {
                case "Waypoint":
                    marker = new L.marker( [poi[i][1], poi[i][2]], {icon: poiBlue}).bindPopup(poi[i][0]).addTo(map);
                    break;

                case "Green":
                    switch (poi[i][0].substring(0,3)) {
                        case "DSS":
                            marker = new L.marker( [poi[i][1], poi[i][2]], {icon: depart}).bindPopup(poi[i][0]).addTo(map);
                            break;
                        default:
                            marker = new L.marker( [poi[i][1], poi[i][2]], {icon: poiGreen}).bindPopup(poi[i][0]).addTo(map);
                        }
                    break;

                case "Red":
                    switch (poi[i][0].substring(0,3)) {
                        case "ASS":
                            marker = new L.marker( [poi[i][1], poi[i][2]], {icon: arrivee}).bindPopup(poi[i][0]).addTo(map);
                            break;
                        default:
                            marker = new L.marker( [poi[i][1], poi[i][2]], {icon: poiRed}).bindPopup(poi[i][0]).addTo(map);
                        }
                    break;
            }
        };


        /*
        optionnal polyline
        we build a track from the POI provided earlier.
        */
        var polyline = L.polyline([], {color: 'red', weight: 3});
        for (var i = 0; i < poi.length; i++) {
           polyline.addLatLng([poi[i][1], poi[i][2]]).addTo(map);
        }
        polyline.addTo(map)


        /*
        more options for the map
        */
        L.control.scale({
                metric: true,
                imperial: false,
                nautic: false
            }).addTo(map);

    </script>
</body>
</html>