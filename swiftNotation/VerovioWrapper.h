// VerovioWrapper.h
// Objective-C++ bridge that exposes the Verovio C++ toolkit to Swift.
// Swift cannot call C++ directly; this wrapper provides a pure ObjC interface.
//
// PRE-REQUISITE: libverovio.a must be built and linked.
// See SETUP.md §1 for cmake build instructions.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps vrv::Toolkit — the core Verovio rendering engine.
@interface VerovioWrapper : NSObject

/// Initialise with default page settings suitable for a notation editor.
- (instancetype)init;

/// Load a MusicXML string into the toolkit.
/// Returns YES on success, NO on parse failure.
- (BOOL)loadMusicXML:(NSString *)xmlString error:(NSError **)error;

/// Render page number `page` (1-based) to an SVG string.
/// Call -loadMusicXML:error: first.
- (nullable NSString *)renderPage:(NSInteger)page error:(NSError **)error;

/// Total number of pages in the currently loaded score.
@property (nonatomic, readonly) NSInteger pageCount;

/// Set Verovio options as a JSON string.
/// Example: @"{\"scale\": 40, \"adjustPageHeight\": true}"
- (void)setOptionsJSON:(NSString *)json;

@end

NS_ASSUME_NONNULL_END
