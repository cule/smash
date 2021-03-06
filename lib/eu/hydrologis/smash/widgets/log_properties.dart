/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */

import 'dart:math';

import 'package:after_layout/after_layout.dart';
import 'package:dart_hydrologis_utils/dart_hydrologis_utils.dart';
import 'package:dart_jts/dart_jts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/plugin_api.dart';
import 'package:latlong/latlong.dart';
import 'package:map_elevation/map_elevation.dart';
import 'package:provider/provider.dart';
import 'package:rainbow_color/rainbow_color.dart';
import 'package:smash/eu/hydrologis/smash/gps/gps.dart';
import 'package:smash/eu/hydrologis/smash/models/project_state.dart';
import 'package:smash/eu/hydrologis/smash/util/elevcolor.dart';
import 'package:smash/eu/hydrologis/smash/widgets/log_list.dart';
import 'package:smashlibs/smashlibs.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

/// The log properties page.
class LogPropertiesWidget extends StatefulWidget {
  final Log4ListWidget _logItem;

  LogPropertiesWidget(this._logItem);

  @override
  State<StatefulWidget> createState() {
    return LogPropertiesWidgetState(_logItem);
  }
}

class LogPropertiesWidgetState extends State<LogPropertiesWidget> {
  Log4ListWidget _logItem;
  double _widthSliderValue;
  ColorExt _logColor;
  ColorTables _ct = ColorTables.none;
  double maxWidth = 20.0;
  bool _somethingChanged = false;

  LogPropertiesWidgetState(this._logItem);

  @override
  void initState() {
    _widthSliderValue = _logItem.width;
    if (_widthSliderValue > maxWidth) {
      _widthSliderValue = maxWidth;
    }

    var logColor =
        EnhancedColorUtility.splitEnhancedColorString(_logItem.color);
    _logColor = ColorExt(logColor[0]);
    _ct = logColor[1];

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (_somethingChanged) {
            // save color and width
            _logItem.width = _widthSliderValue;

            var c = ColorExt.asHex(_logColor);
            var newColorString =
                EnhancedColorUtility.buildEnhancedColor(c, ct: _ct);

            _logItem.color = newColorString;

            ProjectState projectState =
                Provider.of<ProjectState>(context, listen: false);
            projectState.projectDb
                .updateGpsLogStyle(_logItem.id, _logItem.color, _logItem.width);
            projectState.reloadProject(context);
          }
          Navigator.pop(context, _somethingChanged);
          return true;
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text("GPS Log Properties"),
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: SmashUI.defaultPadding(),
                  child: Card(
                    elevation: SmashUI.DEFAULT_ELEVATION,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    child: Padding(
                      padding: SmashUI.defaultPadding(),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Padding(
                            padding: const EdgeInsets.all(4.0),
                            child: EditableTextField(
                              "Log Name",
                              _logItem.name,
                              (res) {
                                if (res == null || res.trim().length == 0) {
                                  res = _logItem.name;
                                }
                                ProjectState projectState =
                                    Provider.of<ProjectState>(context,
                                        listen: false);
                                projectState.projectDb
                                    .updateGpsLogName(_logItem.id, res);
                                setState(() {
                                  _logItem.name = res;
                                });
                              },
                              validationFunction: noEmptyValidator,
                              doBold: true,
                            ),
                          ),
                          Table(
                            columnWidths: {
                              0: FlexColumnWidth(0.3),
                              1: FlexColumnWidth(0.7),
                            },
                            children: _getInfoTableCells(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
              ],
            ),
          ),
        ));
  }

  _getInfoTableCells(BuildContext context) {
    return [
      TableRow(
        children: [
          TableUtilities.cellForString("Start"),
          TableUtilities.cellForString(TimeUtilities.ISO8601_TS_FORMATTER
              .format(
                  new DateTime.fromMillisecondsSinceEpoch(_logItem.startTime))),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("End"),
          TableUtilities.cellForString(TimeUtilities.ISO8601_TS_FORMATTER
              .format(
                  new DateTime.fromMillisecondsSinceEpoch(_logItem.endTime))),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Duration"),
          TableUtilities.cellForString(StringUtilities.formatDurationMillis(
              _logItem.endTime - _logItem.startTime)),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Color"),
          TableCell(
            child: Padding(
              padding: SmashUI.defaultPadding(),
              child: ColorPickerButton(Color(_logColor.value), (newColor) {
                _logColor = ColorExt.fromColor(newColor);
                _somethingChanged = true;
              }),
            ),
          ),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Palette"),
          TableCell(
            child: Padding(
              padding: SmashUI.defaultPadding(),
              child: Align(
                alignment: Alignment.centerLeft,
                child: DropdownButton<ColorTables>(
                  value: _ct,
                  isExpanded: false,
                  items: ColorTables.valuesLogs.map((i) {
                    return DropdownMenuItem<ColorTables>(
                      child: Text(
                        i.name,
                        textAlign: TextAlign.center,
                      ),
                      value: i,
                    );
                  }).toList(),
                  onChanged: (selectedCt) async {
                    setState(() {
                      _ct = selectedCt;
                      _somethingChanged = true;
                    });
                  },
                ),
              ),
            ),
          ),
        ],
      ),
      TableRow(
        children: [
          TableUtilities.cellForString("Width"),
          Row(
            mainAxisSize: MainAxisSize.max,
            children: <Widget>[
              Flexible(
                  flex: 1,
                  child: Slider(
                    activeColor: SmashColors.mainSelection,
                    min: 1.0,
                    max: 20.0,
                    divisions: 10,
                    onChanged: (newRating) {
                      _somethingChanged = true;
                      setState(() => _widthSliderValue = newRating);
                    },
                    value: _widthSliderValue,
                  )),
              Container(
                width: 50.0,
                alignment: Alignment.center,
                child: SmashUI.normalText(
                  '${_widthSliderValue.toInt()}',
                ),
              ),
            ],
          )
        ],
      ),
    ];
  }

  TableCell cellForEditableName(BuildContext context, Log4ListWidget item) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.only(left: 4.0),
        child: EditableTextField(
          "Log Name",
          item.name,
          (res) {
            if (res == null || res.trim().length == 0) {
              res = item.name;
            }
            ProjectState projectState =
                Provider.of<ProjectState>(context, listen: false);
            projectState.projectDb.updateGpsLogName(item.id, res);
            setState(() {
              item.name = res;
            });
          },
          validationFunction: noEmptyValidator,
        ),
      ),
    );
  }
}

class LatLngExt extends ElevationPoint {
  double prog;
  double speed;
  double accuracy;
  int ts;

  LatLngExt(double latitude, double longitude, double altim, this.prog,
      this.speed, this.ts, this.accuracy)
      : super(latitude, longitude, altim);
}

class LogProfileView extends StatefulWidget {
  final Log4ListWidget logItem;

  LogProfileView(this.logItem, {Key key}) : super(key: key);

  @override
  _LogProfileViewState createState() => _LogProfileViewState();
}

class _LogProfileViewState extends State<LogProfileView> with AfterLayoutMixin {
  LatLngExt hoverPoint;
  List<LatLngExt> points = [];
  LatLng center;
  double totalLengthMeters;
  double minLineElev = double.infinity;
  double maxLineElev = double.negativeInfinity;

  void afterFirstLayout(BuildContext context) {
    ProjectState project = Provider.of<ProjectState>(context, listen: false);
    var logDataPoints = project.projectDb.getLogDataPoints(widget.logItem.id);
    bool useGpsFilteredGenerally =
        GpPreferences().getBooleanSync(KEY_GPS_USE_FILTER_GENERALLY, false);
    LatLngExt prevll;
    double progressiveMeters = 0;
    logDataPoints.forEach((p) {
      LatLng llTmp;
      if (useGpsFilteredGenerally && p.filtered_accuracy != null) {
        llTmp = LatLng(p.filtered_lat, p.filtered_lon);
      } else {
        llTmp = LatLng(p.lat, p.lon);
      }
      LatLngExt llExt;
      if (prevll == null) {
        llExt = LatLngExt(
            llTmp.latitude, llTmp.longitude, p.altim, 0, 0, p.ts, p.accuracy);
      } else {
        var distanceMeters = CoordinateUtilities.getDistance(prevll, llTmp);
        progressiveMeters += distanceMeters;
        var deltaTs = (p.ts - prevll.ts) / 1000;
        var speedMS = distanceMeters / deltaTs;

        llExt = LatLngExt(p.lat, p.lon, p.altim, progressiveMeters, speedMS,
            p.ts, p.accuracy);
      }

      points.add(llExt);
      minLineElev = min(minLineElev, p.altim);
      maxLineElev = max(maxLineElev, p.altim);
      prevll = llExt;
    });
    totalLengthMeters = progressiveMeters;
    Envelope env = Envelope.empty();
    logDataPoints.forEach((point) {
      var lat = point.lat;
      var lon = point.lon;
      env.expandToInclude(lon, lat);
    });

    center = LatLng(env.centre().y, env.centre().x);

    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    List<Marker> markers = [];
    var opacity = 0.7;

    if (hoverPoint is LatLng)
      markers.add(Marker(
          point: hoverPoint,
          width: 15,
          height: 15,
          builder: (BuildContext context) => Container(
                decoration: BoxDecoration(
                    color: SmashColors.mainDecorations,
                    borderRadius: BorderRadius.circular(8)),
              )));

    var height = ScreenUtilities.getHeight(context);

    String progString;
    if (hoverPoint != null) {
      var prog = hoverPoint.prog;
      var progFormatted = StringUtilities.formatMeters(prog);
      progString = "Distance at position: $progFormatted";
    }
    var totalNew;
    String totalString;
    if (totalLengthMeters != null) {
      if (totalLengthMeters > 1000) {
        var totalKm = totalLengthMeters / 1000.0;
        totalNew = "${totalKm.toStringAsFixed(1)} km";
      } else {
        totalNew = "${totalLengthMeters.toInt()} m";
      }
      totalString = "Total distance: $totalNew";
    }

    int durationMillis = widget.logItem.endTime - widget.logItem.startTime;
    String durationStr = StringUtilities.formatDurationMillis(durationMillis);
    String currentTouchStr;
    if (hoverPoint != null) {
      int currentTouchMillis = hoverPoint.ts - widget.logItem.startTime;
      currentTouchStr =
          StringUtilities.formatDurationMillis(currentTouchMillis);
    }

    PolylineLayerOptions polylines;
    if (center != null) {
      var clrSplit =
          EnhancedColorUtility.splitEnhancedColorString(widget.logItem.color);
      ColorTables colorTable = clrSplit[1];
      if (colorTable.isValid()) {
        List<Polyline> lines = [];
        EnhancedColorUtility.buildPolylines(lines, points, colorTable,
            widget.logItem.width, minLineElev, maxLineElev);

        polylines = PolylineLayerOptions(
          polylineCulling: true,
          polylines: lines,
        );
      } else {
        polylines = PolylineLayerOptions(
          polylineCulling: true,
          polylines: [
            Polyline(
              points: points,
              color: ColorExt(EnhancedColorUtility.splitEnhancedColorString(
                  widget.logItem.color)[0]),
              strokeWidth: widget.logItem.width,
            ),
          ],
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text("GPS Log Profile View"),
        actions: [
          IconButton(
            icon: Icon(MdiIcons.palette),
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          LogPropertiesWidget(widget.logItem)));
              setState(() {});
            },
          )
        ],
      ),
      body: center == null
          ? SmashCircularProgress(label: "Loading data...")
          : Stack(children: [
              FlutterMap(
                options: new MapOptions(
                  center: center,
                  zoom: 11.0,
                ),
                layers: [
                  TileLayerOptions(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                    subdomains: ['a', 'b', 'c'],
                  ),
                  polylines,
                  MarkerLayerOptions(markers: markers),
                ],
              ),
              hoverPoint != null
                  ? Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      // height: height / 3,
                      child: Container(
                        decoration: BoxDecoration(
                            color: SmashColors.mainBackground.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8)),
                        child: Padding(
                          padding: SmashUI.defaultPadding(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: SmashUI.normalText(widget.logItem.name,
                                    bold: true, underline: true),
                              ),
                              SmashUI.normalText(
                                  "Total duration: $durationStr"),
                              SmashUI.normalText(
                                  "Timestamp: ${TimeUtilities.ISO8601_TS_FORMATTER.format(DateTime.fromMillisecondsSinceEpoch(hoverPoint.ts))}"),
                              SmashUI.normalText(
                                  "Duration at position: $currentTouchStr"),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: SmashUI.normalText(totalString),
                              ),
                              SmashUI.normalText(progString),
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: SmashUI.normalText(
                                    "Speed: ${hoverPoint.speed.toStringAsFixed(0)} m/s (${(hoverPoint.speed * 3.6).toStringAsFixed(0)} km/h)"),
                              ),
                              SmashUI.normalText(
                                  "Elevation: ${hoverPoint.altitude.toInt()}m"),
                            ],
                          ),
                        ),
                      ),
                    )
                  : Container(),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: height / 4,
                child: Container(
                  decoration: BoxDecoration(
                      color: SmashColors.mainBackground.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8)),
                  // color: Colors.white.withOpacity(0.5),
                  child: NotificationListener<ElevationHoverNotification>(
                      onNotification:
                          (ElevationHoverNotification notification) {
                        setState(() {
                          hoverPoint = notification.position;
                        });

                        return true;
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(
                            top: 6.0, bottom: 6, right: 6),
                        child: Elevation(
                          points,
                          color:
                              SmashColors.mainDecorations.withOpacity(opacity),
                          // elevationGradientColors: ElevationGradientColors(
                          //     gt10: Colors.green.withOpacity(opacity),
                          //     gt20: Colors.orangeAccent.withOpacity(opacity),
                          //     gt30: Colors.redAccent.withOpacity(opacity)),
                        ),
                      )),
                ),
              ),
            ]),
    );
  }
}
