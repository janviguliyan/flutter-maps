import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

void main() {
  runApp(const MyApp());
}

CameraPosition _initialLocation =
    CameraPosition(target: LatLng(28.7041, 77.1025));

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
      home: ShowRoute(),
    );
  }
}

class MapRoute extends StatefulWidget {
  const MapRoute({super.key});

  @override
  State<MapRoute> createState() => _MapRouteState();
}

class _MapRouteState extends State<MapRoute> {
  var fromLocation;
  var toLocation;

  @override
  Widget build(BuildContext context) {
    // Determining the screen width & height
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Find Route",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.deepPurpleAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Container(
          height: height,
          width: width,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: fromLocation,
                  decoration: InputDecoration(labelText: 'From'),
                ),
                TextField(
                  controller: toLocation,
                  decoration: InputDecoration(labelText: 'To'),
                ),
                ElevatedButton(
                  onPressed: () {
                    print("submitted");
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => ShowRoute()),
                    );
                  },
                  child: Text("Submit"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ShowRoute extends StatefulWidget {
  const ShowRoute({super.key});

  @override
  State<ShowRoute> createState() => _ShowRouteState();
}

class _ShowRouteState extends State<ShowRoute> {
  late GoogleMapController mapController;

  // For storing the current position
  Position? _currentPosition;
  late bool servicePermission = false;
  late LocationPermission permission;

  String _currentAddress = '';
  String _startAddress = '';
  String _destinationAddress = '';

  final startAddressController = TextEditingController();
  final destinationAddressController = TextEditingController();

  final startAddressFocusNode = FocusNode();
  final desrinationAddressFocusNode = FocusNode();

  Set<Marker> markers = {};

  _getAddress() async {
    try {
      // Places are retrieved using the coordinates
      List<Placemark> p = await placemarkFromCoordinates(
          _currentPosition!.latitude, _currentPosition!.longitude);

      // Taking the most probable result
      Placemark place = p[0];

      setState(() {
        // Structuring the address
        _currentAddress =
            "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";

        // Update the text of the TextField
        startAddressController.text = _currentAddress;

        // Setting the user's present location as the starting address
        _startAddress = _currentAddress;
      });
    } catch (e) {
      print(e);
    }
  }

  // Method for retrieving the current location
  _getCurrentLocation() async {
    servicePermission = await Geolocator.isLocationServiceEnabled();

    if (!servicePermission) {
      print("Service Disabled");
    }

    permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high)
        .then((Position position) async {
      setState(() {
        // Store the position in the variable
        _currentPosition = position;

        print('CURRENT POS: $_currentPosition');

        // For moving the camera to current location
        mapController.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(position.latitude, position.longitude),
              zoom: 18.0,
            ),
          ),
        );
      });
      await _getAddress();
    }).catchError((e) {
      print("in catch block: $e");
    });
  }

  Widget _textField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required String hint,
    required double width,
    required Icon prefixIcon,
    Widget? suffixIcon,
    required Function(String) locationCallback,
  }) {
    return Container(
      width: width * 0.8,
      child: TextField(
        onChanged: (value) {
          locationCallback(value);
        },
        controller: controller,
        focusNode: focusNode,
        decoration: InputDecoration(
          prefixIcon: prefixIcon,
          suffixIcon: suffixIcon,
          labelText: label,
          filled: false,
          // fillColor: Colors.white,
          enabledBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.grey.shade400,
              width: 2,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: const BorderRadius.all(
              Radius.circular(10.0),
            ),
            borderSide: BorderSide(
              color: Colors.blue.shade300,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.all(15),
          hintText: hint,
        ),
      ),
    );
  }

  // Method for calculating the distance between two places
  Future<bool?> _calculateDistance() async {
    try {
      // Retrieving placemarks from addresses
      List<Location>? startPlacemark = await locationFromAddress(_startAddress);
      List<Location>? destinationPlacemark =
          await locationFromAddress(_destinationAddress);

      // Use the retrieved coordinates of the current position,
      // instead of the address if the start position is user's
      // current position, as it results in better accuracy.
      double startLatitude = _startAddress == _currentAddress
          ? _currentPosition!.latitude
          : startPlacemark[0].latitude;

      double startLongitude = _startAddress == _currentAddress
          ? _currentPosition!.longitude
          : startPlacemark[0].longitude;

      double destinationLatitude = destinationPlacemark[0].latitude;
      double destinationLongitude = destinationPlacemark[0].longitude;

      String startCoordinatesString = '($startLatitude, $startLongitude)';
      String destinationCoordinatesString =
          '($destinationLatitude, $destinationLongitude)';

      // Set<Marker> markers = {
      //   // Start Location Marker
      //   Marker(
      //     markerId: MarkerId(startCoordinatesString),
      //     position: LatLng(startLatitude, startLongitude),
      //     infoWindow: InfoWindow(
      //       title: 'Start $startCoordinatesString',
      //       snippet: _startAddress,
      //     ),
      //     icon: BitmapDescriptor.defaultMarker,
      //   ),

      //   // Destination Location Marker
      //   Marker(
      //     markerId: MarkerId(destinationCoordinatesString),
      //     position: LatLng(destinationLatitude, destinationLongitude),
      //     infoWindow: InfoWindow(
      //       title: 'Destination $destinationCoordinatesString',
      //       snippet: _destinationAddress,
      //     ),
      //     icon: BitmapDescriptor.defaultMarker,
      //   )
      // };

      // Start Location Marker
      Marker startMarker = Marker(
        markerId: MarkerId(startCoordinatesString),
        position: LatLng(startLatitude, startLongitude),
        infoWindow: InfoWindow(
          title: 'Start $startCoordinatesString',
          snippet: _startAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Destination Location Marker
      Marker destinationMarker = Marker(
        markerId: MarkerId(destinationCoordinatesString),
        position: LatLng(destinationLatitude, destinationLongitude),
        infoWindow: InfoWindow(
          title: 'Destination $destinationCoordinatesString',
          snippet: _destinationAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );

      // Adding the markers to the list
      markers.add(startMarker);
      markers.add(destinationMarker);

      print(
        'START COORDINATES: ($startLatitude, $startLongitude)',
      );
      print(
        'DESTINATION COORDINATES: ($destinationLatitude, $destinationLongitude)',
      );

      return true;
    } catch (e) {
      print(e);
    }
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    var height = MediaQuery.of(context).size.height;
    var width = MediaQuery.of(context).size.width;

    return Scaffold(
      // appBar: AppBar(
      //   title: const Row(
      //     children: [
      //       // IconButton(
      //       //   onPressed: () {
      //       //     print("go back");
      //       //     Navigator.pop(context);
      //       //   },
      //       //   icon: Icon(Icons.arrow_back),
      //       // ),
      //       Text(
      //         "Find Route",
      //         style: TextStyle(
      //           color: Colors.white,
      //           fontWeight: FontWeight.bold,
      //         ),
      //       ),
      //     ],
      //   ),
      //   backgroundColor: Colors.deepPurpleAccent,
      // ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Center(
          child: Container(
            height: height,
            width: width,
            child: Stack(
              children: [
                GoogleMap(
                  markers: Set<Marker>.from(markers),
                  initialCameraPosition:
                      _initialLocation, // required parameter used for loading the map on initial start-up
                  myLocationEnabled:
                      true, // shows current location with blue dot
                  myLocationButtonEnabled:
                      false, // used to bring the user location to the center of the camera view
                  mapType: MapType
                      .normal, // for specifying the displayed map type (normal, satellite, hybrid or terrain)
                  zoomGesturesEnabled:
                      true, // whether the map view should respond to zoom gestures
                  zoomControlsEnabled:
                      false, // whether to show zoom controls (only applicable for Android)
                  onMapCreated: (GoogleMapController controller) {
                    mapController = controller;
                  }, // callback for when the map is ready to use
                ),
                // zoom buttons
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 10.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        ClipOval(
                          child: Material(
                            color: Colors.deepPurple, // button color
                            child: InkWell(
                              splashColor:
                                  Colors.blue.shade100, // inkwell color
                              child: const SizedBox(
                                width: 50,
                                height: 50,
                                child: Icon(
                                  Icons.add,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                mapController.animateCamera(
                                  CameraUpdate.zoomIn(),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ClipOval(
                          child: Material(
                            color: Colors.deepPurple, // button color
                            child: InkWell(
                              splashColor:
                                  Colors.blue.shade100, // inkwell color
                              child: const SizedBox(
                                width: 50,
                                height: 50,
                                child: Icon(
                                  Icons.remove,
                                  color: Colors.white,
                                ),
                              ),
                              onTap: () {
                                mapController.animateCamera(
                                  CameraUpdate.zoomOut(),
                                );
                              },
                            ),
                          ),
                        )
                      ],
                    ),
                  ),
                ),
                // Show the place input fields & button for showing the route
                SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white70,
                          borderRadius: BorderRadius.all(
                            Radius.circular(20.0),
                          ),
                        ),
                        width: width * 0.9,
                        child: Padding(
                          padding:
                              const EdgeInsets.only(top: 10.0, bottom: 10.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                'Places',
                                style: TextStyle(fontSize: 20.0),
                              ),
                              SizedBox(height: 10),
                              _textField(
                                  label: 'Start',
                                  hint: 'Choose starting point',
                                  prefixIcon: Icon(Icons.looks_one),
                                  suffixIcon: IconButton(
                                    icon: Icon(Icons.my_location),
                                    onPressed: () {
                                      startAddressController.text =
                                          _currentAddress;
                                      _startAddress = _currentAddress;
                                    },
                                  ),
                                  controller: startAddressController,
                                  focusNode: startAddressFocusNode,
                                  width: width,
                                  locationCallback: (String value) {
                                    setState(() {
                                      print("start address called");
                                      _startAddress = value;
                                    });
                                  }),
                              SizedBox(height: 10),
                              _textField(
                                  label: 'Destination',
                                  hint: 'Choose destination',
                                  prefixIcon: Icon(Icons.looks_two),
                                  controller: destinationAddressController,
                                  focusNode: desrinationAddressFocusNode,
                                  width: width,
                                  locationCallback: (String value) {
                                    setState(() {
                                      _destinationAddress = value;
                                    });
                                  }),
                              SizedBox(height: 10),
                              // Visibility(
                              //   visible: _placeDistance == null ? false : true,
                              //   child: Text(
                              //     'DISTANCE: $_placeDistance km',
                              //     style: TextStyle(
                              //       fontSize: 16,
                              //       fontWeight: FontWeight.bold,
                              //     ),
                              //   ),
                              // ),
                              SizedBox(height: 5),
                              ElevatedButton(
                                onPressed: (_startAddress != '' &&
                                        _destinationAddress != '')
                                    ? () async {
                                        // startAddressFocusNode.unfocus();
                                        // desrinationAddressFocusNode.unfocus();
                                        // setState(() {
                                        //   if (markers.isNotEmpty) markers.clear();
                                        //   if (polylines.isNotEmpty)
                                        //     polylines.clear();
                                        //   if (polylineCoordinates.isNotEmpty)
                                        //     polylineCoordinates.clear();
                                        //   _placeDistance = null;
                                        // });

                                        // _calculateDistance().then((isCalculated) {
                                        //   if (isCalculated) {
                                        //     ScaffoldMessenger.of(context)
                                        //         .showSnackBar(
                                        //       SnackBar(
                                        //         content: Text(
                                        //             'Distance Calculated Sucessfully'),
                                        //       ),
                                        //     );
                                        //   } else {
                                        //     ScaffoldMessenger.of(context)
                                        //         .showSnackBar(
                                        //       SnackBar(
                                        //         content: Text(
                                        //             'Error Calculating Distance'),
                                        //       ),
                                        //     );
                                        //   }
                                        // });
                                      }
                                    : null,
                                // color: Colors.red,
                                // shape: RoundedRectangleBorder(
                                //   borderRadius: BorderRadius.circular(20.0),
                                // ),
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Text(
                                    'Show Route'.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // current location button
                SafeArea(
                  child: Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 10.0, bottom: 10.0),
                      child: ClipOval(
                        child: Material(
                          color: Colors.deepPurple, // button color
                          child: InkWell(
                            splashColor:
                                Colors.orange.shade100, // inkwell color
                            child: const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(
                                Icons.my_location,
                                color: Colors.white,
                              ),
                            ),
                            onTap: () {
                              mapController.animateCamera(
                                CameraUpdate.newCameraPosition(
                                  CameraPosition(
                                    target: LatLng(
                                      _currentPosition!.latitude,
                                      _currentPosition!.longitude,
                                    ),
                                    zoom: 18.0,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
