import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_maps_webservice/places.dart' as myPlace;
import 'package:http/http.dart' as http;
import 'package:location/location.dart' as myLoc;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MaterialApp(
        home: MyHomePage(),
      ),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key}) : super(key: key);

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  Completer<GoogleMapController> _controller = Completer();
  late LatLng initialLatLng;
  LatLng? destLatLng;
  late String originPlaceId;
  String? destPlaceId;
  Map<PolylineId, Polyline> polylines = {};
  List<LatLng> polylineCoordinates = [];
  Set<Marker> marker = {};
  late CameraPosition initialCamPos;
  bool loading = false;

  PolylinePoints polylinePoints = PolylinePoints();
  late PolylineResult result;
  myLoc.Location location = myLoc.Location();

  String distance = '';

  @override
  void initState() {
    super.initState();
    _checkGps();
  }

  setCurrentPos(var _data) async {
    initialLatLng = LatLng(_data.latitude, _data.longitude);
    // _initialController.text = '${_data.latitude}, ${_data.longitude}';
    List<Placemark> placemarks = await placemarkFromCoordinates(
        initialLatLng.latitude, initialLatLng.longitude);

    print('placemarks: ' + placemarks[0].toString());
    http.Response response = await http.get(Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json?latlng=${initialLatLng.latitude},${initialLatLng.longitude}&key=AIzaSyBp_LotALPZ3Tgsqh1MlkcPzF5u74WtC0U'));
    print('response: ' + response.body.toString());
    originPlaceId = jsonDecode(response.body)['results'][0]['place_id'];
    _initialController.text = placemarks[0].administrativeArea.toString();
  }

  void setInitialCamPos() async {
    var _data = await _determinePosition();
    await setCurrentPos(_data);
    initialCamPos = CameraPosition(
      target: initialLatLng,
      zoom: 14.4746,
    );
    setMarkers();
  }

  Future _checkGps() async {
    setState(() {
      loading = true;
    });
    if (!await location.serviceEnabled()) {
      bool _temp = await location.requestService();
      if (_temp) setInitialCamPos();
    } else {
      setInitialCamPos();
    }
  }

  Future<Position> _determinePosition() async {
    LocationPermission permission;

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return Future.error(
          'Location permissions are permanently denied, we cannot request permissions.');
    }

    return await Geolocator.getCurrentPosition();
  }

  void setMarkers() {
    marker.add(Marker(
      position: initialLatLng,
      markerId: MarkerId(
        'initial',
      ),
    ));

    if (destLatLng != null) {
      marker.add(Marker(
        position: destLatLng!,
        markerId: MarkerId(
          'dest',
        ),
      ));

      setPoints();
    } else {
      setState(() {
        loading = false;
      });
    }
  }

  void setPoints() async {
    result = await polylinePoints
        .getRouteBetweenCoordinates(
      'AIzaSyBp_LotALPZ3Tgsqh1MlkcPzF5u74WtC0U',
      PointLatLng(initialLatLng.latitude, initialLatLng.longitude),
      PointLatLng(destLatLng!.latitude, destLatLng!.longitude),
      travelMode: TravelMode.driving,
    )
        .catchError((e) {
      print('error: ' + e.toString());
    });
    print('data: ' + result.points.toSet().toString());
    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }
    _addPolyLine();
  }

  _addPolyLine() {
    PolylineId id = PolylineId("poly");
    Polyline polyline = Polyline(
        polylineId: id, color: Colors.red, points: polylineCoordinates);
    // polylines={};
    polylines[id] = polyline;
    setState(() {
      loading = false;
    });
  }

  TextEditingController _initialController = TextEditingController();
  TextEditingController _destController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: loading
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: [
                GoogleMap(
                  mapType: MapType.satellite,
                  initialCameraPosition: initialCamPos,
                  onMapCreated: (GoogleMapController controller) {
                    _controller.complete(controller);
                  },
                  polylines: Set<Polyline>.of(polylines.values),
                  markers: marker,
                ),
                Positioned(
                  top: 100,
                  right: 0,
                  child: Container(
                      padding: EdgeInsets.all(
                        8.0,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black,
                      ),
                      child: Text(
                        'Distance: $distance',
                        style: TextStyle(
                          color: Colors.white,
                        ),
                      )),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: ElevatedButton(
                    onPressed: () {
                      showModalBottomSheet(
                        isScrollControlled: true,
                        context: context,
                        builder: (context) => StatefulBuilder(
                          builder: (context, setState) => Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    MediaQuery.of(context).viewInsets.bottom),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextField(
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Start',
                                      suffixIcon: IconButton(
                                        onPressed: () async {
                                          var _t = await Geolocator
                                              .getCurrentPosition();
                                          setCurrentPos(_t);
                                          setMarkers();
                                          setState(() {});
                                        },
                                        icon: Icon(
                                          Icons.gps_fixed,
                                        ),
                                      ),
                                    ),
                                    controller: _initialController,
                                  ),
                                  SizedBox(height: 20),
                                  TextField(
                                    onTap: () async {
                                      const kGoogleApiKey =
                                          "AIzaSyBp_LotALPZ3Tgsqh1MlkcPzF5u74WtC0U";

                                      myPlace.Prediction? p =
                                          await PlacesAutocomplete.show(
                                              context: context,
                                              apiKey: kGoogleApiKey,
                                              mode: Mode
                                                  .overlay, // Mode.fullscreen
                                              language: "en",
                                              types: [],
                                              strictbounds: false,
                                              components: [
                                                myPlace.Component(
                                                    myPlace.Component.country,
                                                    "in")
                                              ]);
                                      _destController.text = p!.description!;
                                      List<Location> locations =
                                          await locationFromAddress(
                                              p.description!);
                                      destPlaceId = p.placeId;

                                      destLatLng = LatLng(locations[0].latitude,
                                          locations[0].longitude);
                                      setState(() {});
                                    },
                                    decoration: InputDecoration(
                                      border: OutlineInputBorder(),
                                      labelText: 'Destination',
                                    ),
                                    controller: _destController,
                                  ),
                                  SizedBox(
                                    height: 30,
                                  ),
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (destLatLng != null) {
                                        Navigator.pop(context);
                                        print('Origin: ' + originPlaceId);
                                        print(destPlaceId);
                                        http.Response response = await http.get(
                                            Uri.parse(
                                                "https://maps.googleapis.com/maps/api/distancematrix/json?units=metric&origins=place_id:$originPlaceId&destinations=place_id:$destPlaceId&key=AIzaSyBp_LotALPZ3Tgsqh1MlkcPzF5u74WtC0U"));
                                        print(response.body);
                                        distance =
                                            jsonDecode(response.body)['rows']
                                                    [0]['elements'][0]
                                                ['distance']['text'];
                                        setMarkers();
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'choose destination',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(),
                                    child: Text(
                                      'Show Directions',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    child: Text(
                      'Set destination',
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
