import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:maps/location_service.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
// import 'package:geocoding/geocoding.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_config/flutter_config.dart';

Future<void> main() async {
  await dotenv.load(fileName: "lib/.env");
  WidgetsFlutterBinding.ensureInitialized(); // Required by FlutterConfig
  await FlutterConfig.loadEnvVariables();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: MapSample(),
    );
  }
}

class MapSample extends StatefulWidget {
  const MapSample({super.key});

  @override
  State<MapSample> createState() => MapSampleState();
}

class MapSampleState extends State<MapSample> {
  final Completer<GoogleMapController> _controller =
      Completer<GoogleMapController>();

  TextEditingController _originController = TextEditingController();
  TextEditingController _destinationController = TextEditingController();

  Set<Marker> _markers = Set<Marker>();
  Set<Polygon> _polygons = Set<Polygon>();
  Set<Polyline> _polylines = Set<Polyline>();
  List<LatLng> polygonLatLngs = <LatLng>[];

  int _polygonIdCounter = 1;
  int _polylineIdCounter = 1;

  // loads inital position of camera when it launches
  CameraPosition _initialPosition = CameraPosition(
    target: LatLng(37.42796133580664, -122.085749655962),
    zoom: 14.4746,
  );

  Future<Position> _getCurrentPosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Request the user to enable location services
      return Future.error('Location services are disabled.');
    }

    // Request permission to access the user's location
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    // If permissions are granted, get the user's current position
    return await Geolocator.getCurrentPosition();
  }

  @override
  void initState() {
    super.initState();
    _getCurrentPosition().then((position) {
      // Update the map's camera position to the user's current location
      _controller.future.then((controller) {
        controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 14.0,
            ),
          ),
        );
      });
    });
    // _setMarker(LatLng(37.42796133580664, -122.085749655962));
  }

  void _setMarker(LatLng point) {
    setState(() {
      _markers.add(
        Marker(
          markerId: MarkerId('marker'),
          position: point,
        ),
      );
    });
  }

  void _setPolygon() {
    final String polygonIdVal = 'polygon_$_polygonIdCounter';
    _polygonIdCounter++;

    _polygons.add(
      Polygon(
        polygonId: PolygonId(
          polygonIdVal,
        ),
        points: polygonLatLngs,
        strokeWidth: 3,
        fillColor: Colors.transparent,
      ),
    );
  }

  void _setPolyline(List<PointLatLng> points) {
    final String polylineIdVal = 'polyline_$_polylineIdCounter';
    _polylineIdCounter++;

    _polylines.add(
      Polyline(
        polylineId: PolylineId(polylineIdVal),
        width: 3,
        color: Colors.blue,
        points: points
            .map(
              (point) => LatLng(point.latitude, point.longitude),
            )
            .toList(),
      ),
    );
  }

  void _clearPreviousData() {
    setState(() {
      _markers.clear();
      _polygons.clear();
      _polylines.clear();
      polygonLatLngs.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Maps'),
        backgroundColor: Color.fromARGB(255, 125, 106, 232),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _originController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Choose start location',
                        ),
                        onChanged: (value) {
                          print(value);
                          // prints the value every time user types something in the text field
                        },
                      ),
                      TextFormField(
                        controller: _destinationController,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Choose destination',
                        ),
                        onChanged: (value) {
                          print(
                              value); // prints the value every time user types something in the text field
                        },
                      )
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () async {
                    _clearPreviousData(); // Clear previous data

                    var direction = await LocationService().getDirection(
                        _originController.text, _destinationController.text);

                    _goToPlace(
                      direction['start_location']['lat'],
                      direction['start_location']['lng'],
                      direction['bounds_ne'],
                      direction['bounds_sw'],
                    );

                    _goToPlace(
                      direction['end_location']['lat'],
                      direction['end_location']['lng'],
                      direction['bounds_ne'],
                      direction['bounds_sw'],
                    ); // changes the position of camera

                    _setPolyline(direction['polyline_decoded']);
                    // var place = await LocationService()
                    //     .getPlace(_searchController.text);
                  },
                  icon: Icon(Icons.search),
                ),
              ],
            ),
          ),
          // Padding(
          //   padding: const EdgeInsets.all(8.0),
          //   child: Row(
          //     children: [
          //       Expanded(
          //           child: TextFormField(
          //         controller: _searchController,
          //         textCapitalization: TextCapitalization.words,
          //         decoration: InputDecoration(
          //           hintText: 'Search by City',
          //         ),
          //         onChanged: (value) {
          //           print(
          //               value); // prints the value every time user types something in the text field
          //         },
          //       )),
          //       // IconButton(
          //       //   onPressed: () async {
          //       //     var place = await LocationService()
          //       //         .getPlace(_searchController.text);
          //       //     _goToPlace(place); // changes the position of camera
          //       //   },
          //       //   icon: Icon(Icons.search),
          //       // ),
          //     ],
          //   ),
          // ),
          Expanded(
            child: GoogleMap(
              markers: _markers,
              polygons: _polygons,
              polylines: _polylines,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              mapType: MapType.normal,
              initialCameraPosition: _initialPosition,
              onMapCreated: (GoogleMapController controller) {
                _controller.complete(controller);
              },
              onTap: (point) {
                setState(() {
                  polygonLatLngs.add(point); // add points to list
                  _setPolygon(); // starts to draw line after 3 points
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  // changes position of map according to city we search
  Future<void> _goToPlace(
    // Map<String, dynamic> place
    double lat,
    double lng,
    Map<String, dynamic> bounds_Ne,
    Map<String, dynamic> bounds_Sw,
  ) async {
    // final double lat = place['geometry']['location']['lat'];
    // final double lng = place['geometry']['location']['lng'];
    // we get under geometry in it location to extract the longitude and latitude of that place in response
    // geometry: {location: {lat: 28.7040592, lng: 77.10249019999999}

    final GoogleMapController controller = await _controller.future;
    await controller.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(lat, lng),
        zoom: 12,
      ),
    ));

    controller.animateCamera(CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(bounds_Sw['lat'], bounds_Sw['lng']),
          northeast: LatLng(bounds_Ne['lat'], bounds_Ne['lng']),
        ),
        25));

    _setMarker(LatLng(lat, lng));
  }
}


// CameraPosition _initialLocation =
//     CameraPosition(target: LatLng(28.7041, 77.1025));

// // need to make Marker object to access it
  // static final Marker _kGooglePlexMarker = Marker(
  //   markerId: MarkerId('_kGooglePlex'),
  //   infoWindow: InfoWindow(
  //       title:
  //           'Google Plex'), // user can click on marker and check info about the location
  //   icon: BitmapDescriptor.defaultMarker,
  //   position: LatLng(37.42796133580664, -122.085749655962),
  // );
  //
  // static final Polyline _kPolyline = Polyline(
  //   polylineId: PolylineId('_kPolyline'),
  //   points: [
  //     LatLng(37.42796133580664, -122.085749655962),
  //     LatLng(37.43296265331129, -122.08832357078792),
  //   ], // since its a line only 2 points
  //   width: 4,
  // );
  //
  // static final Polygon _kPolygon = Polygon(
  //   polygonId: PolygonId('_kPolygon'),
  //   points: [
  //     LatLng(37.43296265331129, -122.08832357078792),
  //     LatLng(37.42796133580664, -122.085749655962),
  //     LatLng(37.418, -122.092),
  //     LatLng(37.435, -122.092),
  //   ], // since its a point need more than 2 points
  //   strokeWidth: 4,
  //   fillColor: Colors.transparent,
  // );

// in google maos widget
// markers: {
              //   _kGooglePlexMarker,
              //   // _kLakeMarker,
              // },
              // polylines: {
              //   _kPolyline,
              // },
              // polygons: {
              //   _kPolygon,
              // },

// floatingActionButton: FloatingActionButton.extended(
      //   onPressed: _goToTheLake,
      //   label: const Text('To the lake!'),
      //   icon: const Icon(Icons.directions_boat),
      // ),

  // Future<void> _goToTheLake() async {
  //   final GoogleMapController controller = await _controller.future;
  //   await controller.animateCamera(CameraUpdate.newCameraPosition(_kLake));
  // }
