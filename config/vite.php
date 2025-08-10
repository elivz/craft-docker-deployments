<?php

use craft\helpers\App;

return [
    'useDevServer' => App::env('ENVIRONMENT') === 'dev' || App::env('CRAFT_ENVIRONMENT') === 'dev',
    'manifestPath' => '@webroot/assets/.vite/manifest.json',
    'devServerPublic' => 'http://localhost:5173/',
    'serverPublic' => App::env('PRIMARY_SITE_URL') . '/assets/',
    'errorEntry' => '',
    'cacheKeySuffix' => '',
    'devServerInternal' => '',
    'checkDevServer' => false,
];
