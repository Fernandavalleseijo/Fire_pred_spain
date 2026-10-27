// Dataset diario agregado de ERA5-Land
var era5 = ee.ImageCollection('ECMWF/ERA5_LAND/DAILY_AGGR');

// Bounding box aproximado de tus archivos (81 x 141 celdas a 0.1°)
var spain = ee.Geometry.Rectangle([-10, 36, 4, 44]);

// 1) Un solo día (el mismo de tu archivo)
var img = era5
  .filterDate('1950-01-02', '1950-01-03')
  .first()
  .select('volumetric_soil_water_layer_1');   // equivale a swvl1

print('Imagen', img);
print('Bandas', era5.first().bandNames());

Map.centerObject(spain, 5);
Map.addLayer(img.clip(spain),
  {min: 0.05, max: 0.45, palette: ['#a50026','#f46d43','#fee08b','#a6d96a','#1a9850','#313695']},
  'swvl1 1950-01-15');

// 2) Valor en un punto (Madrid) para comparar con R
var madrid = ee.Geometry.Point([-3.7, 40.4]);
var val = img.reduceRegion({
  reducer: ee.Reducer.first(),
  geometry: madrid,
  scale: 11132       // resolución nativa de ERA5-Land (~0.1°)
});
print('swvl1 en Madrid', val);

// 3) Serie temporal en el punto
var serie = era5
  .filterDate('1950-01-01', '1951-01-01')
  .select('volumetric_soil_water_layer_1');

print(ui.Chart.image.series({
  imageCollection: serie,
  region: madrid,
  reducer: ee.Reducer.first(),
  scale: 11132
}).setOptions({title: 'swvl1 Madrid 1950', vAxis: {title: 'm³/m³'}}));

// 4) Media espacial sobre España
print(ui.Chart.image.series({
  imageCollection: serie,
  region: spain,
  reducer: ee.Reducer.mean(),
  scale: 11132
}).setOptions({title: 'swvl1 media España 1950'}));
