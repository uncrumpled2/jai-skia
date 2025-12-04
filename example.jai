#import "Basic";
#load "skia.jai";
#import "POSIX"; 

main :: () {
    print("Initializing Skia...\n");
    print("Size of SkImageInfo: %\n", size_of(SkImageInfo));

    width := 800;
    height := 600;

    // Create a raster surface
    // info := SkImageInfo.MakeN32Premul(cast(s32)width, cast(s32)height);
    dimensions: SkISize;
    dimensions.fWidth = cast(s32)width;
    dimensions.fHeight = cast(s32)height;

    colorInfo: SkColorInfo;
    colorInfo.fColorType = .RGBA_8888_SkColorType;
    colorInfo.fAlphaType = .Premul_SkAlphaType;
    // colorInfo.fColorSpace is default initialized to null sk_sp

        info: SkImageInfo;
        info.fDimensions = dimensions;
        info.fColorInfo = colorInfo;
    
    print("Calling WrapPixels...\n");
    
    pixel_size := width * height * 4;
    pixels := alloc(pixel_size);
    memset(pixels, 0, pixel_size);

    // WrapPixels returns sk_sp(SkSurface)
    sp_surface := SkSurfaces.WrapPixels(info, pixels, cast(u64)(width * 4), null);    surface := sp_surface.fPtr;
    
    if !surface {
        print("Failed to create surface.\n");
        return;
    }

    canvas := SkSurface.getCanvas(surface);
    if !canvas {
        print("Failed to get canvas.\n");
        return;
    }

    // Draw background (White)
    white: SkColor4f;
    white.fR = 1.0;
    white.fG = 1.0;
    white.fB = 1.0;
    white.fA = 1.0;
    SkCanvas.drawColor(canvas, white, .Src);

    // Setup paint for red rect
    paint: SkPaint;
    SkPaint.Constructor(*paint);
    SkPaint.setColor(*paint, 0xFFFF0000); // Red

    rect: SkRect;
    rect.fLeft = 100.0;
    rect.fTop = 100.0;
    rect.fRight = 300.0;
    rect.fBottom = 300.0;

    SkCanvas.drawRect(canvas, rect, paint);

    // Test SkFont bindings
    print("Testing SkFont bindings...\n");
    font: SkFont;
    SkFont.Constructor(*font); // Default constructor

    print("  SkFont size: % bytes\n", size_of(SkFont));
    print("  Font size (default): %\n", font.fSize);
    print("  Font scaleX: %\n", font.fScaleX);
    print("  Font skewX: %\n", font.fSkewX);

    // Set font size
    SkFont.setSize(*font, 24.0);
    print("  Font size (after setSize 24): %\n", font.fSize);

    // Draw text using the font
    textPaint: SkPaint;
    SkPaint.Constructor(*textPaint);
    SkPaint.setColor(*textPaint, 0xFF000000); // Black

    text := "Hello from Skia!";
    SkCanvas.drawSimpleText(canvas, text.data, cast(u64)text.count, SkTextEncoding.kUTF8, 100.0, 450.0, font, textPaint);

    // Test font metrics
    metrics: SkFontMetrics;
    spacing := SkFont.getMetrics(*font, *metrics);
    print("  Font metrics - ascent: %, descent: %, leading: %\n", metrics.fAscent, metrics.fDescent, metrics.fLeading);
    print("  Recommended line spacing: %\n", spacing);

    SkPaint.Destructor(*textPaint);

    print("Drawing complete. Encoding to PNG...\n");

    // Encode to PNG
    // makeImageSnapshot returns sk_sp(SkImage)
    sp_image := SkSurface.makeImageSnapshot(surface);
    image := sp_image.fPtr;
    
    if !image {
        print("Failed to snapshot image.\n");
        return;
    }
    
    stream: SkFILEWStream;
    SkFILEWStream.Constructor(*stream, "test.png");
    
    if !stream.fFILE {
        print("Failed to open output file.\n");
        return;
    }
    
    options: SkPngEncoder.Options;
    
    pixmap: SkPixmap;
    // SkPixmap.Constructor(*pixmap); // Default constructor not available, zero-init is fine.
    
    if !SkImage.peekPixels(image, *pixmap) {
        print("Failed to peek pixels.\n");
        return;
    }

    result := SkPngEncoder.Encode(*stream, pixmap, options);

    if result {
        print("Successfully saved to test.png\n");
    } else {
        print("Failed to encode PNG.\n");
    }
    
    // Cleanup
    SkFILEWStream.Destructor_Base(*stream);
    SkPaint.Destructor(*paint);
    
    // Unref RefCnt objects.
    // We need to check if we need to unref 'image' and 'surface'.
    // Since we got them from sk_sp, the sk_sp "owns" a ref.
    // But our sk_sp struct in Jai is likely just a POD wrapper and doesn't call unref in destructor (unless generated with bindings).
    // If the bindings generator does NOT add a destructor to sk_sp, we must unref manually.
    // It's safer to assume we must unref the pointer inside sp_surface and sp_image.
    
    // SkRefCntBase.unref(surface); 
    // SkRefCntBase.unref(image);
}
