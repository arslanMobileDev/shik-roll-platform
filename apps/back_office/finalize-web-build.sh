#!/bin/sh
set -eu
cd build/web
build_id=$(sha256sum main.dart.js | cut -d ' ' -f 1)
main_file="main.${build_id}.dart.js"
mv main.dart.js "$main_file"
# Only replace known filenames/placeholders, not minified registration code.
sed -i "s/main\.dart\.js/$main_file/g; s/'__SHIK_BUILD_ID__'/'$build_id'/g" index.html flutter_bootstrap.js
cp retire-service-worker.js flutter_service_worker.js
printf '{"buildId":"%s","mainJs":"%s"}\n' "$build_id" "$main_file" > version.json
test -s "$main_file"
grep -q "$main_file" index.html
grep -q 'SHIK retirement worker' flutter_service_worker.js
if grep -q "'__SHIK_BUILD_ID__'" index.html flutter_bootstrap.js; then exit 1; fi
