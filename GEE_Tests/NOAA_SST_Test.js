// ============================================================
// Mean SST over rectangular regions for ONE day
// Dataset: NOAA OISST v2.1 (GEE asset: NOAA/CDR/OISST/V2_1)
// ============================================================

// Day to analyze (format 'YYYY-MM-DD'; OISST starts on 1981-09-01)
var DATE = '1982-06-14';

// Region bounds: [minLat, maxLat, minLon, maxLon]
// Longitudes use NOAA's 0-360 convention (e.g., 355 = 5°W).
// If minLon > maxLon, the box crosses the 0° meridian (Greenwich).
var REGIONS = {
  'Sole':        [36.0, 44.0, 355.0, 10.0],   // 5°W-10°E
  'Campos':      [33.0, 45.0, 350.0, 25.0],   // 10°W-25°E
  'Pastor WMED': [30.0, 45.0, 354.4, 10.0],   // Gibraltar-10°E
  'Pastor CMED': [30.0, 45.0, 10.0, 22.0],    // 10°E-22°E
  'Pastor EMED': [30.0, 41.0, 22.0, 36.0],    // 22°E-36°E
  'Ossó NW':     [42.0, 52.0, 308.0, 320.0],  // 52°W-40°W
  'Ossó SE':     [35.0, 42.0, 325.0, 340.0],  // 35°W-20°W
  'Krüger':      [45.0, 60.0, 320.0, 345.0]   // 40°W-15°W
};

// Build one closed polygon ring from a lon/lat box.
// GEE expects [lon, lat] pairs, and the first point must repeat at the end.
function ring(lonMin, latMin, lonMax, latMax) {
  return [[[lonMin, latMin], [lonMax, latMin], [lonMax, latMax],
           [lonMin, latMax], [lonMin, latMin]]];
}

// Convert each region into an ee.Feature.
var fc = ee.FeatureCollection(Object.keys(REGIONS).map(function (name) {
  var b = REGIONS[name];
  var latMin = b[0], latMax = b[1], lonMin = b[2], lonMax = b[3];

  var polys;
  if (lonMin < lonMax) {
    // Normal case: the box does not cross 0°, so one polygon is enough.
    polys = [ring(lonMin, latMin, lonMax, latMax)];
  } else {
    // Box crosses 0°: split it into [lonMin, 360] and [0, lonMax].
    polys = [ring(lonMin, latMin, 360, latMax),
             ring(0, latMin, lonMax, latMax)];
  }

  // MultiPolygon with planar edges (geodesic = false) so the borders
  // follow constant lat/lon lines, i.e., true "rectangles" on the grid.
  return ee.Feature(ee.Geometry.MultiPolygon(polys, null, false),
                    {region: name});
}));

// Load the SST image for the chosen day.
var img = ee.ImageCollection('NOAA/CDR/OISST/V2_1')
  .filterDate(DATE, ee.Date(DATE).advance(1, 'day'))  // end date is exclusive
  .select('sst')                                       // daily SST band
  .first()                                             // one image per day
  .multiply(0.01);                                     // scale factor -> °C

// Spatial mean over each region.
// scale = 27830 m is roughly the native 0.25° resolution of OISST.
// Land pixels are masked in the dataset, so they are ignored.
var res = img.reduceRegions({
  collection: fc,
  reducer: ee.Reducer.mean(),
  scale: 27830
});

// Print a clean table (region, mean SST) to the Console tab.
print('Mean SST (°C) on ' + DATE,
      res.map(function (f) {
        return ee.Feature(null, {
          region: f.get('region'),
          sst_mean: f.get('mean')
        });
      }));
