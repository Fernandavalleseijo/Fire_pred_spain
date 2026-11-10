// ============================================================
// SPEI map for one month over Spain
// Dataset: SPEIbase v2.11 (GEE asset: CSIC/SPEI/2_11), 0.5° monthly
// Control check of the SPEIbase NetCDF files cropped with Python
// ============================================================

// ---- Settings ----
var SCALE = 12;                       // SPEI timescale (months)
var DATE  = '2022-08-01';             // month to map (YYYY-MM-01)
var band  = 'SPEI_' + (SCALE < 10 ? '0' : '') + SCALE + '_month';

// ---- Data ----
var spei = ee.ImageCollection('CSIC/SPEI/2_11')
  .filterDate(DATE, ee.Date(DATE).advance(1, 'month'))  // end date is exclusive
  .select(band)
  .first();

// ---- Spain bounding box (same as the Python crop) and borders ----
var bbox = ee.Geometry.Rectangle([-9.5, 35.8, 4.5, 43.9]);
var countries = ee.FeatureCollection('USDOS/LSIB_SIMPLE/2017');
var spain = countries.filter(ee.Filter.eq('country_na', 'Spain'));

// ---- Map ----
var palette = ['#67001f', '#b2182b', '#d6604d', '#f4a582', '#fddbc7', '#f7f7f7',
               '#d1e5f0', '#92c5de', '#4393c3', '#2166ac', '#053061'];  // RdBu

Map.setCenter(-3.5, 40, 6);
Map.addLayer(spei.clip(bbox), {min: -3, max: 3, palette: palette},
             'SPEI-' + SCALE + ' ' + DATE);
Map.addLayer(countries.style({color: '333333', fillColor: '00000000', width: 1}),
             {}, 'Country borders');
Map.addLayer(spain.style({color: '000000', fillColor: '00000000', width: 2}),
             {}, 'Spain');

// ---- Legend ----
var legend = ui.Panel({style: {position: 'bottom-left', padding: '8px'}});
legend.add(ui.Label('SPEI-' + SCALE + ', ' + DATE.slice(0, 7), {fontWeight: 'bold'}));
legend.add(ui.Thumbnail({
  image: ee.Image.pixelLonLat().select(1),
  params: {bbox: [0, -3, 1, 3], dimensions: '20x120', min: -3, max: 3,
           palette: palette.slice().reverse()},
  style: {margin: '4px 0'}
}));
legend.add(ui.Label('+3 (wet)  ...  -3 (dry)'));
Map.add(legend);

// ---- Check against the NetCDF: value at a grid-cell centre ----
// SPEIbase cell centres sit at .25/.75, so this avoids cell-edge ambiguity.
var pt = ee.Geometry.Point([-3.75, 40.25]);
print('SPEI at point (GEE):',
      spei.reduceRegion({reducer: ee.Reducer.first(), geometry: pt, scale: 55660}));
