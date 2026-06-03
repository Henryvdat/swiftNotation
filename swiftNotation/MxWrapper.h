// MxWrapper.h
// Objective-C bridge over the mx C++ MusicXML parser.
// Swift cannot call C++ directly; this wrapper provides a pure ObjC interface.
//
// PRE-REQUISITE: libmx.a must be built and linked.
// See SETUP.md §3 for cmake build instructions.

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// ---------------------------------------------------------------------------
// MARK: - Transfer objects (ObjC plain objects, safe for Swift consumption)
// ---------------------------------------------------------------------------

/// A single note or rest extracted from mx's model.
@interface MxNoteTransfer : NSObject
@property (nonatomic) BOOL    isRest;
@property (nonatomic) BOOL    isMeasureRest;
@property (nonatomic) BOOL    isChord;      // simultaneous with previous note
@property (nonatomic) BOOL    isTieStart;
@property (nonatomic) BOOL    isTieStop;
// Pitch (ignored for rests)
@property (nonatomic) NSString *step;       // "C" "D" … "B", "" for rests
@property (nonatomic) double   alter;       // semitone offset: -2…+2
@property (nonatomic) BOOL    hasAlter;
@property (nonatomic) int      octave;
@property (nonatomic) NSString *accidental; // "sharp" "flat" "natural" "double-sharp"
                                            // "flat-flat" "natural-sharp" "natural-flat" or ""
// Duration
@property (nonatomic) NSString *noteType;   // "whole" "half" "quarter" "eighth" "16th" etc.
@property (nonatomic) int      dots;
@property (nonatomic) int      durationTicks;   // in ticksPerQuarter units
// Placement
@property (nonatomic) int      voice;
@property (nonatomic) int      staff;           // 1-based
@property (nonatomic) int      tickTimePosition;
@property (nonatomic) NSString *stemDirection;  // "up" "down" "none" or ""
@end

/// A barline inside a measure (left or right).
@interface MxBarlineTransfer : NSObject
@property (nonatomic) NSString *barlineType;      // "lightHeavy" "lightLight" "heavyLight" etc.
@property (nonatomic) NSString *location;         // "left" "right"
@property (nonatomic) BOOL    isRepeat;
@property (nonatomic) NSString *repeatDirection;  // "forward" "backward" or ""
@end

/// One measure's worth of music data.
@interface MxMeasureTransfer : NSObject
@property (nonatomic) int      number;
// Attributes — present only in the measure where the change occurs
@property (nonatomic) BOOL    hasClef;
@property (nonatomic) NSString *clefSign;  // "G" "F" "C" "percussion" "TAB"
@property (nonatomic) int      clefLine;
@property (nonatomic) BOOL    hasKey;
@property (nonatomic) int      keyFifths;
@property (nonatomic) NSString *keyMode;   // "major" "minor" or ""
@property (nonatomic) BOOL    hasTime;
@property (nonatomic) int      timeBeats;
@property (nonatomic) int      timeBeatType;
// Elements — notes sorted by (tickTimePosition, staff, voice)
@property (nonatomic) NSArray<MxNoteTransfer *>    *notes;
@property (nonatomic) NSArray<MxBarlineTransfer *> *barlines;
@end

/// One instrumental part.
@interface MxPartTransfer : NSObject
@property (nonatomic) NSString           *xmlID;
@property (nonatomic, nullable) NSString *name;
@property (nonatomic, nullable) NSString *abbreviation;
@property (nonatomic) NSArray<MxMeasureTransfer *> *measures;
@end

/// Top-level score result returned by -parseXML:error:.
@interface MxScoreTransfer : NSObject
@property (nonatomic, nullable) NSString *title;
@property (nonatomic, nullable) NSString *composer;
@property (nonatomic) int ticksPerQuarter;
@property (nonatomic) NSArray<MxPartTransfer *> *parts;
@end

// ---------------------------------------------------------------------------
// MARK: - Parser
// ---------------------------------------------------------------------------

/// Parses MusicXML using the mx C++ library.
/// All parsing happens synchronously on the calling thread.
@interface MxWrapper : NSObject

/// Parse a MusicXML string and return the structured transfer object.
/// Returns nil and sets *error on failure.
+ (nullable MxScoreTransfer *)parseXML:(NSString *)xml
                                 error:(NSError *_Nullable *_Nullable)error;

@end

NS_ASSUME_NONNULL_END
