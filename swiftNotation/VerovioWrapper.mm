// VerovioWrapper.mm
// Objective-C++ implementation — bridges vrv::Toolkit to ObjC/Swift.
//
// Thread-safety: the caller (VerovioRenderer) serialises all calls on a
// private DispatchQueue.  This class itself adds no synchronisation.

#import "VerovioWrapper.h"
#include "vrv/toolkit.h"
#include "vrv/options.h"

#include <stdexcept>
#include <climits>

// ---------------------------------------------------------------------------
// Error domain
// ---------------------------------------------------------------------------

static NSString *const kVerovioErrorDomain = @"com.swiftnotation.VerovioError";

typedef NS_ENUM(NSInteger, VerovioErrorCode) {
    VerovioErrorCodeLoadFailed   = 1,
    VerovioErrorCodeRenderFailed = 2,
};

// ---------------------------------------------------------------------------
// Implementation
// ---------------------------------------------------------------------------

@implementation VerovioWrapper {
    /// Heap-allocated toolkit instance.  Owned exclusively by this object;
    /// lifetime matches the ObjC object lifetime (created in -init, destroyed
    /// in -dealloc).  Never nil between init and dealloc.
    vrv::Toolkit *_toolkit;
}

// MARK: - Lifecycle

- (instancetype)init {
    self = [super init];
    if (!self) { return nil; }

    // false = do not attempt to auto-discover a resource path at construction.
    _toolkit = new vrv::Toolkit(false);

    // Point the toolkit at the Verovio data directory bundled in the app.
    // The data/ folder from the Verovio source tree must be copied into the
    // app bundle under Resources/.  See SETUP.md §2.
    NSString *dataPath = [NSBundle.mainBundle pathForResource:@"data" ofType:nil];
    if (dataPath) {
        _toolkit->SetResourcePath(dataPath.UTF8String);
    }

    // Default rendering options tuned for an interactive editor view.
    // A4 portrait at 40 % scale, SVG bounding boxes enabled for future
    // hit-testing support.
    static const std::string kDefaultOptions = R"({
        "pageWidth":  2100,
        "pageHeight": 2970,
        "scale": 40,
        "adjustPageHeight": true,
        "svgBoundingBoxes": true,
        "svgHtml5": false
    })";
    _toolkit->SetOptions(kDefaultOptions);

    return self;
}

- (void)dealloc {
    delete _toolkit;
    // Setting to nullptr here is defensive — if any future ObjC method is
    // called after dealloc (e.g. via an errant __unsafe_unretained pointer),
    // the nil-guard will catch it rather than crashing on a dangling pointer.
    _toolkit = nullptr;
}

// MARK: - Public API

- (BOOL)loadMusicXML:(NSString *)xmlString error:(NSError **)error {
    NSParameterAssert(xmlString);
    if (!_toolkit) { return NO; }

    bool ok = false;
    try {
        ok = _toolkit->LoadData(xmlString.UTF8String);
    } catch (const std::exception &ex) {
        if (error) {
            NSString *reason = [NSString stringWithUTF8String:ex.what()];
            *error = [NSError errorWithDomain:kVerovioErrorDomain
                                         code:VerovioErrorCodeLoadFailed
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return NO;
    }

    if (!ok && error) {
        // Verovio does not throw on parse failure; it returns false.
        // Retrieve its internal log for a more informative message.
        std::string log = _toolkit->GetLog();
        NSString *reason = log.empty()
            ? @"Verovio failed to parse the MusicXML document."
            : [NSString stringWithUTF8String:log.c_str()];
        *error = [NSError errorWithDomain:kVerovioErrorDomain
                                     code:VerovioErrorCodeLoadFailed
                                 userInfo:@{NSLocalizedDescriptionKey: reason}];
    }
    return ok ? YES : NO;
}

- (nullable NSString *)renderPage:(NSInteger)page error:(NSError **)error {
    if (!_toolkit) { return nil; }

    // Verovio uses int internally; guard against overflow on 64-bit.
    if (page < 1 || page > INT_MAX) {
        if (error) {
            NSString *reason = [NSString stringWithFormat:
                @"Page number %ld is out of range.", (long)page];
            *error = [NSError errorWithDomain:kVerovioErrorDomain
                                         code:VerovioErrorCodeRenderFailed
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return nil;
    }

    std::string svg;
    try {
        svg = _toolkit->RenderToSVG(static_cast<int>(page));
    } catch (const std::exception &ex) {
        if (error) {
            NSString *reason = [NSString stringWithUTF8String:ex.what()];
            *error = [NSError errorWithDomain:kVerovioErrorDomain
                                         code:VerovioErrorCodeRenderFailed
                                     userInfo:@{NSLocalizedDescriptionKey: reason}];
        }
        return nil;
    }

    if (svg.empty()) {
        if (error) {
            *error = [NSError errorWithDomain:kVerovioErrorDomain
                                         code:VerovioErrorCodeRenderFailed
                                     userInfo:@{NSLocalizedDescriptionKey:
                                         @"Verovio returned an empty SVG for this page."}];
        }
        return nil;
    }

    return [NSString stringWithUTF8String:svg.c_str()];
}

- (NSInteger)pageCount {
    if (!_toolkit) { return 0; }
    return static_cast<NSInteger>(_toolkit->GetPageCount());
}

- (void)setOptionsJSON:(NSString *)json {
    NSParameterAssert(json);
    if (!_toolkit) { return; }
    _toolkit->SetOptions(json.UTF8String);
}

@end
