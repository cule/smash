/*
 * Copyright (c) 2019-2020. Antonello Andrea (www.hydrologis.com). All rights reserved.
 * Use of this source code is governed by a GPL3 license that can be
 * found in the LICENSE file.
 */
import 'package:badges/badges.dart';
import 'package:dart_hydrologis_db/dart_hydrologis_db.dart';
import 'package:dart_hydrologis_utils/dart_hydrologis_utils.dart'
    hide TextStyle;
import 'package:dart_jts/dart_jts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_geopackage/flutter_geopackage.dart';
import 'package:smash/eu/hydrologis/smash/mainview_utils.dart';
import 'package:smash/eu/hydrologis/smash/maps/feature_attributes_viewer.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/core/layermanager.dart';
import 'package:smash/eu/hydrologis/smash/maps/layers/types/geopackage.dart';
import 'package:smash/eu/hydrologis/smash/maps/plugins/feature_info_plugin.dart';
import 'package:smash/eu/hydrologis/smash/models/tools/geometryeditor_state.dart';
import 'package:smash/eu/hydrologis/smash/models/tools/info_tool_state.dart';
import 'package:smash/eu/hydrologis/smash/models/map_state.dart';
import 'package:smash/eu/hydrologis/smash/models/mapbuilder.dart';
import 'package:smash/eu/hydrologis/smash/models/tools/ruler_state.dart';
import 'package:smash/eu/hydrologis/smash/models/tools/tools.dart';
import 'package:smash/eu/hydrologis/smash/util/experimentals.dart';
import 'package:smashlibs/smashlibs.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:provider/provider.dart';

class BottomToolsBar extends StatefulWidget {
  final _iconSize;
  BottomToolsBar(this._iconSize, {Key key}) : super(key: key);

  @override
  _BottomToolsBarState createState() => _BottomToolsBarState();
}

class _BottomToolsBarState extends State<BottomToolsBar> {
  @override
  Widget build(BuildContext context) {
    return Consumer<GeometryEditorState>(
        builder: (context, geomEditState, child) {
      if (geomEditState.editableGeometry == null) {
        return BottomAppBar(
          color: SmashColors.mainDecorations,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              if (EXPERIMENTAL_GEOMEDITOR__ENABLED)
                GeomEditorButton(widget._iconSize),
              FeatureQueryButton(widget._iconSize),
              RulerButton(widget._iconSize),
              Spacer(),
              getZoomIn(),
              getZoomOut(),
            ],
          ),
        );
      } else {
        return BottomAppBar(
          color: SmashColors.mainDecorations,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              getRemoveFeatureButton(),
              getOpenFeatureAttributesButton(geomEditState),
              getSaveFeatureButton(geomEditState),
              getCancelEditButton(geomEditState),
              Spacer(),
              getZoomIn(),
              getZoomOut(),
            ],
          ),
        );
      }
    });
  }

  Consumer<SmashMapState> getZoomOut() {
    return Consumer<SmashMapState>(builder: (context, mapState, child) {
      return IconButton(
        onPressed: () {
          mapState.zoomOut();
        },
        tooltip: 'Zoom out',
        icon: Icon(
          SmashIcons.zoomOutIcon,
          color: SmashColors.mainBackground,
        ),
        iconSize: widget._iconSize,
      );
    });
  }

  Consumer<SmashMapState> getZoomIn() {
    return Consumer<SmashMapState>(builder: (context, mapState, child) {
      return DashboardUtils.makeToolbarZoomBadge(
        IconButton(
          onPressed: () {
            mapState.zoomIn();
          },
          tooltip: 'Zoom in',
          icon: Icon(
            SmashIcons.zoomInIcon,
            color: SmashColors.mainBackground,
          ),
          iconSize: widget._iconSize,
        ),
        mapState.zoom.toInt(),
        iconSize: widget._iconSize,
      );
    });
  }

  Widget getCancelEditButton(GeometryEditorState geomEditState) {
    return Tooltip(
      message: "Cancel current edit.",
      child: GestureDetector(
        child: Padding(
          padding: SmashUI.defaultPadding(),
          child: InkWell(
            child: Icon(
              MdiIcons.markerCancel,
              color: SmashColors.mainBackground,
              size: widget._iconSize,
            ),
          ),
        ),
        onLongPress: () {
          setState(() {
            geomEditState.editableGeometry = null;
            GeometryEditManager().stopEditing();
            SmashMapBuilder mapBuilder =
                Provider.of<SmashMapBuilder>(context, listen: false);
            mapBuilder.reBuild();
          });
        },
      ),
    );
  }

  Widget getSaveFeatureButton(GeometryEditorState geomEditState) {
    return Tooltip(
      message: "Save current edit.",
      child: GestureDetector(
        child: Padding(
          padding: SmashUI.defaultPadding(),
          child: InkWell(
            child: Icon(
              MdiIcons.contentSaveEdit,
              color: SmashColors.mainBackground,
              size: widget._iconSize,
            ),
          ),
        ),
        onTap: () async {
          var editableGeometry = geomEditState.editableGeometry;
          GeometryEditManager().saveCurrentEdit(geomEditState);

          // stop editing
          geomEditState.editableGeometry = null;
          GeometryEditManager().stopEditing();

          // reload layer geoms
          var layerSources = LayerManager().getLayerSources(onlyActive: true);
          layerSources.forEach((layer) {
            if (layer is GeopackageSource &&
                layer.getName() == editableGeometry.table &&
                layer.db == editableGeometry.db) {
              layer.isLoaded = false;
            }
          });

          // rebuild map
          SmashMapBuilder mapBuilder =
              Provider.of<SmashMapBuilder>(context, listen: false);
          var layers = await LayerManager().loadLayers(mapBuilder.context);
          mapBuilder.oneShotUpdateLayers = layers;
          setState(() {
            mapBuilder.reBuild();
          });
        },
      ),
    );
  }

  // Widget getAddFeatureButton() {
  //   return Tooltip(
  //     message: "Add a new feature.",
  //     child: GestureDetector(
  //       child: Padding(
  //         padding: SmashUI.defaultPadding(),
  //         child: InkWell(
  //           child: Icon(
  //             MdiIcons.plus,
  //             color: SmashColors.mainBackground,
  //             size: widget._iconSize,
  //           ),
  //         ),
  //       ),
  //       onTap: () {
  //         setState(() {
  //           GeometryEditManager().stopEditing();
  //           GeometryEditManager().startEditing(null, () {
  //             SmashMapBuilder mapBuilder =
  //                 Provider.of<SmashMapBuilder>(context, listen: false);
  //             mapBuilder.reBuild();
  //           });
  //         });
  //       },
  //     ),
  //   );
  // }

  Widget getRemoveFeatureButton() {
    return Tooltip(
      message: "Remove selected feature.",
      child: GestureDetector(
        child: Padding(
          padding: SmashUI.defaultPadding(),
          child: InkWell(
            child: Icon(
              MdiIcons.trashCan,
              color: SmashColors.mainBackground,
              size: widget._iconSize,
            ),
          ),
        ),
        onTap: () {
          setState(() {
            // GeometryEditManager().stopEditing();
            // GeometryEditManager().startEditing(null, () {
            //   SmashMapBuilder mapBuilder =
            //       Provider.of<SmashMapBuilder>(context, listen: false);
            //   mapBuilder.reBuild();
            // });
          });
        },
      ),
    );
  }

  Widget getOpenFeatureAttributesButton(
      GeometryEditorState geometryEditorState) {
    return Tooltip(
      message: "Show feature attributes.",
      child: GestureDetector(
        child: Padding(
          padding: SmashUI.defaultPadding(),
          child: InkWell(
            child: Icon(
              MdiIcons.tableEdit,
              color: SmashColors.mainBackground,
              size: widget._iconSize,
            ),
          ),
        ),
        onTap: () {
          var editableGeometry = geometryEditorState.editableGeometry;
          var id = editableGeometry.id;
          if (id != null) {
            var table = editableGeometry.table;
            var db = editableGeometry.db;
            var tableName = SqlName(table);
            var key = db.getPrimaryKey(tableName);
            var geometryColumn = db.getGeometryColumnsForTable(tableName);
            var tableColumns = db.getTableColumns(tableName);
            Map<String, String> typesMap = {};
            tableColumns.forEach((column) {
              typesMap[column[0]] = column[1];
            });
            var tableData = db.getTableData(tableName, where: "$key=$id");
            if (tableData.data.isNotEmpty) {
              EditableQueryResult totalQueryResult = EditableQueryResult();
              totalQueryResult.editable = [true];
              totalQueryResult.fieldAndTypemap = [];
              totalQueryResult.ids = [];
              totalQueryResult.primaryKeys = [];
              totalQueryResult.dbs = [];
              tableData.geoms.forEach((g) {
                totalQueryResult.ids.add(table);
                totalQueryResult.primaryKeys.add(key);
                totalQueryResult.dbs.add(db);
                totalQueryResult.fieldAndTypemap.add(typesMap);
                totalQueryResult.editable.add(true);
                if (geometryColumn.srid != SmashPrj.EPSG4326_INT) {
                  var from = SmashPrj.fromSrid(geometryColumn.srid);
                  SmashPrj.transformGeometryToWgs84(from, g);
                }
                totalQueryResult.geoms.add(g);
              });
              tableData.data.forEach((d) {
                totalQueryResult.data.add(d);
              });
              Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          FeatureAttributesViewer(totalQueryResult)));
            }
          } else {
            SmashDialogs.showWarningDialog(context,
                "The feature does not have a primary key. Editing is not allowed.");
          }
        },
      ),
    );
  }
}

class FeatureQueryButton extends StatefulWidget {
  final _iconSize;

  FeatureQueryButton(this._iconSize, {Key key}) : super(key: key);

  @override
  _FeatureQueryButtonState createState() => _FeatureQueryButtonState();
}

class _FeatureQueryButtonState extends State<FeatureQueryButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<InfoToolState>(builder: (context, infoState, child) {
      return Tooltip(
        message: "Query features from loaded vector layers.",
        child: GestureDetector(
          child: Padding(
            padding: SmashUI.defaultPadding(),
            child: InkWell(
              child: Icon(
                MdiIcons.layersSearch,
                color: infoState.isEnabled
                    ? SmashColors.mainSelection
                    : SmashColors.mainBackground,
                size: widget._iconSize,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              BottomToolbarToolsRegistry.setEnabled(context,
                  BottomToolbarToolsRegistry.FEATUREINFO, !infoState.isEnabled);
            });
          },
        ),
      );
    });
  }
}

class RulerButton extends StatelessWidget {
  final _iconSize;

  RulerButton(this._iconSize, {Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<RulerState>(builder: (context, rulerState, child) {
      Widget w = InkWell(
        child: Icon(
          MdiIcons.ruler,
          color: rulerState.isEnabled
              ? SmashColors.mainSelection
              : SmashColors.mainBackground,
          size: _iconSize,
        ),
      );
      if (rulerState.lengthMeters != null) {
        w = Badge(
          badgeColor: SmashColors.mainSelection,
          shape: BadgeShape.square,
          borderRadius: 10,
          toAnimate: false,
          position: BadgePosition.topStart(
              top: -_iconSize / 2, start: 0.1 * _iconSize),
          badgeContent: Text(
            StringUtilities.formatMeters(rulerState.lengthMeters),
            style: TextStyle(color: Colors.white),
          ),
          child: w,
        );
      }
      return Tooltip(
        message: "Measure distances on the map with your finger.",
        child: GestureDetector(
          child: Padding(
            padding: SmashUI.defaultPadding(),
            child: w,
          ),
          onTap: () {
            BottomToolbarToolsRegistry.setEnabled(context,
                BottomToolbarToolsRegistry.RULER, !rulerState.isEnabled);
          },
        ),
      );
    });
  }
}

class GeomEditorButton extends StatefulWidget {
  final _iconSize;

  GeomEditorButton(this._iconSize, {Key key}) : super(key: key);

  @override
  _GeomEditorButtonState createState() => _GeomEditorButtonState();
}

class _GeomEditorButtonState extends State<GeomEditorButton> {
  @override
  Widget build(BuildContext context) {
    return Consumer<GeometryEditorState>(
        builder: (context, editorState, child) {
      return Tooltip(
        message: "Modify geometries in editable vector layers.",
        child: GestureDetector(
          child: Padding(
            padding: SmashUI.defaultPadding(),
            child: InkWell(
              child: Icon(
                MdiIcons.vectorLine,
                color: editorState.isEnabled
                    ? SmashColors.mainSelection
                    : SmashColors.mainBackground,
                size: widget._iconSize,
              ),
            ),
          ),
          onTap: () {
            setState(() {
              BottomToolbarToolsRegistry.setEnabled(
                  context,
                  BottomToolbarToolsRegistry.GEOMEDITOR,
                  !editorState.isEnabled);
              SmashMapBuilder mapBuilder =
                  Provider.of<SmashMapBuilder>(context, listen: false);
              mapBuilder.reBuild();
            });
          },
        ),
      );
    });
  }
}
