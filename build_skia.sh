#!/bin/bash
set -e

# 1. Setup GN and Ninja
echo "Setting up build tools..."
./skia/bin/fetch-gn
./skia/bin/fetch-ninja

# Add bin to PATH
export PATH=$PWD/skia/bin:$PATH

# 1.5 Sync Dependencies
echo "Syncing dependencies (this may take a while)..."
cd skia
python3 tools/git-sync-deps
cd ..

# 2. Configure Skia Build
# We build a static library for simplicity, but shared is also fine.
# We disable skia_use_system_... to ensure we don't need to install system libs.
# is_official_build=true optimizes it.
echo "Configuring Skia..."
cd skia
rm -rf out/Release # Ensure clean build
gn gen out/Release --args='is_component_build=true is_official_build=false is_debug=false skia_use_fontconfig=false skia_use_expat=false skia_use_system_freetype2=false skia_use_system_libjpeg_turbo=false skia_use_system_libpng=false skia_use_system_zlib=false skia_use_system_icu=false skia_use_system_harfbuzz=false skia_use_gl=false skia_enable_pdf=false skia_use_libwebp_decode=false skia_use_libwebp_encode=false'

# 3. Build
echo "Building Skia..."
ninja -C out/Release skia

# 4. Copy library
echo "Copying library..."
cd ..
cp skia/out/Release/libskia.so . 
# Or libskia.so if you changed the config to is_component_build=true

echo "Done! libskia.a is ready."
