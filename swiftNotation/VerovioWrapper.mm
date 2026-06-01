// VerovioWrapper.mm
// Objective-C++ implementation — bridges vrv::Toolkit to ObjC/Swift.

#import "VerovioWrapper.h"

// ---------------------------------------------------------------------------
// Verovio C++ headers.
// These are available once you've added Packages/verovio as a submodule and
// set HEADER_SEARCH_PATHS to include "$(SRCROOT)/Packages/verovio/include".
// ---------------------------------------------------------------------------
#include "vrv/toolkit.h"
#include "vrv/options.h"

static NSString *const kVerovioErrorDomain = @"VerovioError";

@implementation VerovioWrapper {
    vrv::Toolkit *_toolkit;
}

// MARK: - Lifecycle

- (instancetype)init {
    self = [super init];
    if (self) {
        _toolkit = new vrv::Toolkit(false); // false = don't load resource path yet

        // Point the toolkit at the bundled Verovio data directory.
        // The data/ folder from the Verovio repo must be copied into the app bundle.
        // See SETUP.md §2 for details.
        NSString *dataPath = [NSBundle.mainBundle pathForResource:@"data" ofType:nil];
        if (dataPath) {
            _toolkit->SetResourcePath(dataPath.UTF8String);
        }

        // Default rendering options — tuned for an editor view
        std::string defaults = R"({
            "pageWidth":  2100,
            "pageHeight": 2970,
            "scale": 40,
            "adjustPageHeight": true,
            "svgBoundingBoxes": true,
            "svgHtml5": false
        })";
        _toolkit->SetOptions(defaults);
    }
    return self;
}

- (void)dealloc {
    delete _toolkit;
    _toolkit = nullptr;
}

// MARK: - Public API

- (BOOL)loadMusicXML:(NSString *)xmlString error:(NSError **)error {
    if (!_toolkit) return NO;
    bool ok = _toolkit->LoadData(xmlString.UTF8String);
    if (!ok && error) {
        *error = [NSError errorWithDomain:kVerovioErrorDomain
                                     code:1
                                 userInfo:@{NSLocalizedDescriptionKey: @"Verovio failed to parse MusicXML"}];
    }
    return ok ? YES : NO;
}

- (nullable NSString *)renderPage:(NSInteger)page error:(NSError **)error {
    if (!_toolkit) return nil;
    std::string svg = _toolkit->RenderToSVG((int)page);
    if (svg.empty()) {
        if (error) {
            *error = [NSError errorWithDomain:kVerovioErrorDomain
                                         code:2
                                     userInfo:@{NSLocalizedDescriptionKey: @"Verovio returned empty SVG"}];
        }
        return nil;
    }
    return [NSString stringWithUTF8String:svg.c_str()];
}

- (NSInteger)pageCount {
    if (!_toolkit) return 0;
    return _toolkit->GetPageCount();
}

- (void)setOptionsJSON:(NSString *)json {
    if (!_toolkit) return;
    _toolkit->SetOptions(json.UTF8String);
}

@end
