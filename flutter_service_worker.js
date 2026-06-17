'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"flutter.js": "4b2350e14c6650ba82871f60906437ea",
"assets/FontManifest.json": "7b2a36307916a9721811788013e65289",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"assets/assets/images/bullets/player_green.png": "7a4096cfa7389aa86476e4d8a03d6882",
"assets/assets/images/bullets/enemy_red.png": "86c72e53cfba4888af4fbdda296e2058",
"assets/assets/images/bullets/impact.png": "f813ab35f84db9a65e1779ffef7ee52d",
"assets/assets/images/bullets/player_blue.png": "704e0d2f1d9fc63ea910b9ad957d1cc7",
"assets/assets/images/powerups/health.png": "fe2224f89b59caf1a909e4f75f9ec1e3",
"assets/assets/images/powerups/coin.png": "33dbd8b98af596f2ec03b4c1457f3258",
"assets/assets/images/powerups/freeze.png": "274764503eec5d3fff91595f79a22763",
"assets/assets/images/powerups/shield.png": "4aa776de875ef314555737827dfa4b72",
"assets/assets/images/powerups/damage.png": "0505be7ff9a482bdfb5e27e445836cbf",
"assets/assets/images/powerups/magnet.png": "8db4ab469f486249d14da9aa3af48661",
"assets/assets/images/powerups/rapid.png": "fff5f85fb87239a64ad2a57bbc791152",
"assets/assets/images/README.md": "3161d2fbd1f46b8f583c448f72d3cc3f",
"assets/assets/images/enemies/fast.png": "4328c0cf30458117271f9c7987ea6409",
"assets/assets/images/enemies/normal.png": "7082c3c772cf613cc5d0342d56f0aff7",
"assets/assets/images/enemies/kamikaze.png": "42b6e052dc0005117f3983a013c2fa22",
"assets/assets/images/enemies/galacticboss.png": "21ae7cb65d9062dd49e8d9ce5e8546e7",
"assets/assets/images/enemies/variant1.png": "69b0403908e60fc6c934fadec96e02ce",
"assets/assets/images/enemies/miniboss.png": "d284b9ed7e5e54e82579f4fa9bcedbe7",
"assets/assets/images/enemies/variant2.png": "b46dc0a15816e4b068ca4ec1a4461b55",
"assets/assets/images/enemies/laser.png": "39787d2a37e5b74ac9d94fb9ce0c5a97",
"assets/assets/images/enemies/armored.png": "9649734bb0af0abe54a46c1f51156ad9",
"assets/assets/images/ui/life.png": "6853a12014c976fb987a6da886b69191",
"assets/assets/images/fx/spark_yellow.png": "11752848c21ef3f9545d286981bb9648",
"assets/assets/images/fx/explosion_sheet.png": "5ddcf208bfb5ee103c39ea71c64a107f",
"assets/assets/images/fx/shield.png": "310b96e5807494cab5d4985812b3603c",
"assets/assets/images/fx/thruster0.png": "6c3d8bc89cd33c03a0953418e8bdc5de",
"assets/assets/images/fx/spark_blue.png": "431b99d2aa2576def6aa2b940c6fff1f",
"assets/assets/images/fx/thruster1.png": "f694eb318c51740cce8d5cb0b2e24f57",
"assets/assets/images/bg/nebula.jpg": "7d701d92e09118e3eed1248f5c3e77d8",
"assets/assets/images/bg/starfield.png": "ed28a7506f3fdb4e142b6a46aa93520a",
"assets/assets/images/ship/player_falcon.png": "27cecc12df3a7844472efb2954610f32",
"assets/assets/images/ship/player_damage.png": "51d11d02c93f8ca8a0958c06054c7090",
"assets/assets/images/ship/player_titan.png": "7e905a5a5bf78445fa00a38f3c6123bd",
"assets/assets/images/ship/player_phoenix.png": "117cb318d1295fd017c89a18bfef4927",
"assets/assets/images/ship/player_viper.png": "f3e1bb132dcbbbd2e1d1a798e9d33b63",
"assets/assets/audio/bgm_battle.wav": "954db58b9614fa23f23b522d128a8b21",
"assets/assets/audio/README.md": "23fc82c48e51e83e2149e78be067b859",
"assets/assets/audio/level_up.wav": "1345405d03cc6b8de4e61e325c235374",
"assets/assets/audio/nuke.mp3": "49ae95724fcf5860ad24773e3915dd22",
"assets/assets/audio/explosion.mp3": "c31f41e9e5c1c4b856e7492282d09453",
"assets/assets/audio/boss_roar.wav": "6a135b1acfd7bef50f12fad971764443",
"assets/assets/audio/powerup.wav": "ebadfb564163a5432be24e7819ecf8e0",
"assets/assets/audio/click.wav": "80ac8b468da31432f69b068fcff82d60",
"assets/assets/audio/laser.mp3": "6ecab59ad8987bbe57f4e2e9ba8ac09d",
"assets/assets/audio/hit.wav": "18ce932043c62c0181f07c046a356e8e",
"assets/assets/audio/coin.wav": "5bab877fb0f23a3e343fd14cf7b692c2",
"assets/assets/data/balance.json": "f21470a3c5f34520b86a221a3a7ad3e7",
"assets/AssetManifest.bin.json": "be33455664de787798765da731e74cf8",
"assets/fonts/MaterialIcons-Regular.otf": "ae02bc773c8cae85fe58909c966571de",
"assets/AssetManifest.bin": "57948c7ec4ad500b0ab99e3d12cc539d",
"assets/NOTICES": "b1303690fb597d8fd5d850f057727ea4",
"assets/AssetManifest.json": "0580334305e127a7c60463e840341a8f",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"flutter_bootstrap.js": "f15d0fe0ab8c750fdde9d68a79ed5266",
"canvaskit/skwasm.wasm": "828c26a0b1cc8eb1adacbdd0c5e8bcfa",
"canvaskit/skwasm.js.symbols": "96263e00e3c9bd9cd878ead867c04f3c",
"canvaskit/chromium/canvaskit.js": "b7ba6d908089f706772b2007c37e6da4",
"canvaskit/chromium/canvaskit.js.symbols": "e115ddcfad5f5b98a90e389433606502",
"canvaskit/chromium/canvaskit.wasm": "ea5ab288728f7200f398f60089048b48",
"canvaskit/canvaskit.js": "26eef3024dbc64886b7f48e1b6fb05cf",
"canvaskit/canvaskit.js.symbols": "efc2cd87d1ff6c586b7d4c7083063a40",
"canvaskit/canvaskit.wasm": "e7602c687313cfac5f495c5eac2fb324",
"canvaskit/skwasm.js": "ac0f73826b925320a1e9b0d3fd7da61c",
"canvaskit/skwasm.worker.js": "89990e8c92bcb123999aa81f7e203b1c",
"index.html": "fe7f96b66ba76aecc9f4064f0140c77a",
"/": "fe7f96b66ba76aecc9f4064f0140c77a",
"main.dart.js": "b18475da6efb07091ab0c34c9401bcd1",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"manifest.json": "704ea244355d2ecdc493362574542485",
"version.json": "fd7cfe41a9212f55c2b75319e7f93e8a"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
