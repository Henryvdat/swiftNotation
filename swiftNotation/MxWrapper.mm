// MxWrapper.mm
// ObjC++ implementation — uses mx C++ API internally.

#import "MxWrapper.h"

#include <mx/api/DocumentManager.h>
#include <mx/api/ScoreData.h>

#include <sstream>
#include <stdexcept>
#include <algorithm>

using namespace mx::api;

// ---------------------------------------------------------------------------
// MARK: - Transfer object implementations
// ---------------------------------------------------------------------------

@implementation MxNoteTransfer
- (instancetype)init {
    self = [super init];
    if (self) {
        _isRest = NO; _isMeasureRest = NO; _isChord = NO;
        _isTieStart = NO; _isTieStop = NO;
        _step = @""; _alter = 0; _hasAlter = NO; _octave = 4;
        _accidental = @""; _noteType = @""; _dots = 0;
        _durationTicks = 0; _voice = 1; _staff = 1;
        _tickTimePosition = 0; _stemDirection = @"";
    }
    return self;
}
@end

@implementation MxBarlineTransfer
- (instancetype)init {
    self = [super init];
    if (self) {
        _barlineType = @"normal"; _location = @"right";
        _isRepeat = NO; _repeatDirection = @"";
    }
    return self;
}
@end

@implementation MxMeasureTransfer
- (instancetype)init {
    self = [super init];
    if (self) {
        _number = 0;
        _hasClef = NO; _clefSign = @""; _clefLine = 2;
        _hasKey = NO; _keyFifths = 0; _keyMode = @"";
        _hasTime = NO; _timeBeats = 4; _timeBeatType = 4;
        _notes = @[]; _barlines = @[];
    }
    return self;
}
@end

@implementation MxPartTransfer
- (instancetype)init {
    self = [super init];
    if (self) { _xmlID = @""; _name = nil; _abbreviation = nil; _measures = @[]; }
    return self;
}
@end

@implementation MxScoreTransfer
- (instancetype)init {
    self = [super init];
    if (self) { _title = nil; _composer = nil; _ticksPerQuarter = 1; _parts = @[]; }
    return self;
}
@end

// ---------------------------------------------------------------------------
// MARK: - Helpers
// ---------------------------------------------------------------------------

static NSString *stepString(Step step) {
    switch (step) {
        case Step::c: return @"C";
        case Step::d: return @"D";
        case Step::e: return @"E";
        case Step::f: return @"F";
        case Step::g: return @"G";
        case Step::a: return @"A";
        case Step::b: return @"B";
        default:      return @"";
    }
}

static NSString *accidentalString(Accidental acc) {
    switch (acc) {
        case Accidental::sharp:              return @"sharp";
        case Accidental::flat:               return @"flat";
        case Accidental::natural:            return @"natural";
        case Accidental::doubleSharp:        return @"double-sharp";
        case Accidental::flatFlat:           return @"flat-flat";
        case Accidental::naturalSharp:       return @"natural-sharp";
        case Accidental::naturalFlat:        return @"natural-flat";
        case Accidental::quarterFlat:        return @"quarter-flat";
        case Accidental::quarterSharp:       return @"quarter-sharp";
        case Accidental::threeQuartersFlat:  return @"three-quarters-flat";
        case Accidental::threeQuartersSharp: return @"three-quarters-sharp";
        default:                             return @"";
    }
}

static NSString *durationNameString(DurationName d) {
    switch (d) {
        case DurationName::maxima:    return @"maxima";
        case DurationName::longa:     return @"long";
        case DurationName::breve:     return @"breve";
        case DurationName::whole:     return @"whole";
        case DurationName::half:      return @"half";
        case DurationName::quarter:   return @"quarter";
        case DurationName::eighth:    return @"eighth";
        case DurationName::dur16th:   return @"16th";
        case DurationName::dur32nd:   return @"32nd";
        case DurationName::dur64th:   return @"64th";
        case DurationName::dur128th:  return @"128th";
        case DurationName::dur256th:  return @"256th";
        case DurationName::dur512th:  return @"512th";
        case DurationName::dur1024th: return @"1024th";
        default:                      return @"";
    }
}

static NSString *clefSignString(ClefSymbol sym) {
    switch (sym) {
        case ClefSymbol::g:          return @"G";
        case ClefSymbol::f:          return @"F";
        case ClefSymbol::c:          return @"C";
        case ClefSymbol::percussion: return @"percussion";
        case ClefSymbol::tab:        return @"TAB";
        default:                     return @"";
    }
}

static NSString *barlineTypeString(BarlineType t) {
    switch (t) {
        case BarlineType::normal:      return @"regular";
        case BarlineType::lightLight:  return @"light-light";
        case BarlineType::lightHeavy:  return @"light-heavy";
        case BarlineType::heavyLight:  return @"heavy-light";
        case BarlineType::dotted:      return @"dotted";
        case BarlineType::dashed:      return @"dashed";
        case BarlineType::heavy:       return @"heavy";
        case BarlineType::heavyHeavy:  return @"heavy-heavy";
        case BarlineType::none:        return @"none";
        default:                       return @"regular";
    }
}

/// Collect all NoteTransfer objects from one measure across all staves & voices,
/// sorted by (tickTimePosition, staffIndex, voiceNumber).
static NSArray<MxNoteTransfer *> *notesFromMeasure(const MeasureData &measure) {
    struct RawNote {
        NoteData note;
        int staffIndex;
        int voiceNumber;
    };
    std::vector<RawNote> rawNotes;

    for (int si = 0; si < (int)measure.staves.size(); ++si) {
        const auto &staff = measure.staves[si];
        for (const auto &[voiceNum, voiceData] : staff.voices) {
            for (const auto &n : voiceData.notes) {
                rawNotes.push_back({n, si, voiceNum});
            }
        }
    }

    // Sort by tick, then staff, then voice so merge order is deterministic.
    std::stable_sort(rawNotes.begin(), rawNotes.end(), [](const RawNote &a, const RawNote &b) {
        if (a.note.tickTimePosition != b.note.tickTimePosition)
            return a.note.tickTimePosition < b.note.tickTimePosition;
        if (a.staffIndex != b.staffIndex)
            return a.staffIndex < b.staffIndex;
        return a.voiceNumber < b.voiceNumber;
    });

    NSMutableArray<MxNoteTransfer *> *result = [NSMutableArray array];

    for (const auto &raw : rawNotes) {
        const NoteData &n = raw.note;
        MxNoteTransfer *t = [[MxNoteTransfer alloc] init];
        t.isRest        = n.isRest;
        t.isMeasureRest = n.isMeasureRest;
        t.isChord       = n.isChord;
        t.isTieStart    = n.isTieStart;
        t.isTieStop     = n.isTieStop;

        if (!n.isRest) {
            t.step   = stepString(n.pitchData.step);
            t.octave = n.pitchData.octave;
            if (n.pitchData.alter != 0) {
                t.alter    = n.pitchData.alter;
                t.hasAlter = YES;
            }
            t.accidental = accidentalString(n.pitchData.accidental);
        }

        t.noteType        = durationNameString(n.durationData.durationName);
        t.dots            = n.durationData.durationDots;
        t.durationTicks   = n.durationData.durationTimeTicks;
        t.voice           = n.userRequestedVoiceNumber > 0 ? n.userRequestedVoiceNumber : (raw.voiceNumber + 1);
        t.staff           = raw.staffIndex + 1;
        t.tickTimePosition = n.tickTimePosition;

        switch (n.stem) {
            case Stem::up:   t.stemDirection = @"up";   break;
            case Stem::down: t.stemDirection = @"down"; break;
            case Stem::none: t.stemDirection = @"none"; break;
            default:         t.stemDirection = @"";     break;
        }

        [result addObject:t];
    }

    return result;
}

static NSArray<MxBarlineTransfer *> *barlinesFromMeasure(const MeasureData &measure) {
    NSMutableArray<MxBarlineTransfer *> *result = [NSMutableArray array];

    for (const auto &b : measure.barlines) {
        if (b.barlineType == BarlineType::unspecified ||
            b.barlineType == BarlineType::unsupported ||
            b.barlineType == BarlineType::normal)
            continue;

        NSString *location;
        switch (b.location) {
            case HorizontalAlignment::left:   location = @"left";   break;
            case HorizontalAlignment::center: location = @"middle"; break;
            default:                          location = @"right";  break;
        }

        MxBarlineTransfer *t = [[MxBarlineTransfer alloc] init];
        t.barlineType = barlineTypeString(b.barlineType);
        t.location    = location;
        t.isRepeat    = b.repeat;
        if (b.repeat) {
            // Infer repeat direction from barline location.
            t.repeatDirection = [location isEqualToString:@"left"] ? @"forward" : @"backward";
        }
        [result addObject:t];
    }

    return result;
}

// ---------------------------------------------------------------------------
// MARK: - Measure builder
// ---------------------------------------------------------------------------

static MxMeasureTransfer *buildMeasure(const MeasureData &measure, int measureNumber,
                                       bool firstMeasure) {
    MxMeasureTransfer *t = [[MxMeasureTransfer alloc] init];
    t.number = measureNumber;

    // Time signature — beats and beatType are strings in mx (e.g. "4", "4").
    if (!measure.timeSignature.beats.empty()) {
        int beats    = std::atoi(measure.timeSignature.beats.c_str());
        int beatType = std::atoi(measure.timeSignature.beatType.c_str());
        if (beats > 0 && beatType > 0) {
            t.hasTime      = YES;
            t.timeBeats    = beats;
            t.timeBeatType = beatType;
        }
    }

    // Key — from MeasureData.keys (applies to all staves).
    if (!measure.keys.empty()) {
        const auto &key = measure.keys.front();
        t.hasKey    = YES;
        t.keyFifths = key.fifths;
        switch (key.mode) {
            case KeyMode::major: t.keyMode = @"major"; break;
            case KeyMode::minor: t.keyMode = @"minor"; break;
            default:             t.keyMode = @"";      break;
        }
    }

    // Clef — from first staff's first clef at tick 0 (or any clef if first measure).
    if (!measure.staves.empty()) {
        const auto &staff = measure.staves[0];
        if (!staff.clefs.empty()) {
            const auto &clef = staff.clefs.front();
            if (firstMeasure || clef.tickTimePosition == 0) {
                NSString *sign = clefSignString(clef.symbol);
                if (sign.length > 0) {
                    t.hasClef  = YES;
                    t.clefSign = sign;
                    t.clefLine = clef.line > 0 ? clef.line : 2;
                }
            }
        }
    }

    t.notes    = notesFromMeasure(measure);
    t.barlines = barlinesFromMeasure(measure);
    return t;
}

// ---------------------------------------------------------------------------
// MARK: - MxWrapper
// ---------------------------------------------------------------------------

@implementation MxWrapper

+ (nullable MxScoreTransfer *)parseXML:(NSString *)xml
                                 error:(NSError *_Nullable *_Nullable)error {
    if (!xml || xml.length == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"MxWrapper"
                                         code:1
                                     userInfo:@{NSLocalizedDescriptionKey: @"Empty XML string"}];
        }
        return nil;
    }

    std::string cppXml = xml.UTF8String;
    ScoreData scoreData;
    int docID = -1;

    try {
        auto &mgr = DocumentManager::getInstance();
        std::istringstream ss(cppXml);
        docID = mgr.createFromStream(ss);
        if (docID < 0) {
            if (error) {
                *error = [NSError errorWithDomain:@"MxWrapper"
                                             code:2
                                         userInfo:@{NSLocalizedDescriptionKey: @"mx failed to parse the MusicXML document"}];
            }
            return nil;
        }
        scoreData = mgr.getData(docID);
        mgr.destroyDocument(docID);
    } catch (const std::exception &e) {
        if (docID >= 0) {
            try { DocumentManager::getInstance().destroyDocument(docID); } catch (...) {}
        }
        if (error) {
            NSString *msg = [NSString stringWithUTF8String:e.what()];
            *error = [NSError errorWithDomain:@"MxWrapper"
                                         code:3
                                     userInfo:@{NSLocalizedDescriptionKey: msg}];
        }
        return nil;
    } catch (...) {
        if (docID >= 0) {
            try { DocumentManager::getInstance().destroyDocument(docID); } catch (...) {}
        }
        if (error) {
            *error = [NSError errorWithDomain:@"MxWrapper"
                                         code:4
                                     userInfo:@{NSLocalizedDescriptionKey: @"Unknown error in mx parser"}];
        }
        return nil;
    }

    MxScoreTransfer *result = [[MxScoreTransfer alloc] init];

    // Title: prefer movementTitle, fall back to workTitle.
    if (!scoreData.movementTitle.empty())
        result.title = [NSString stringWithUTF8String:scoreData.movementTitle.c_str()];
    else if (!scoreData.workTitle.empty())
        result.title = [NSString stringWithUTF8String:scoreData.workTitle.c_str()];

    if (!scoreData.composer.empty())
        result.composer = [NSString stringWithUTF8String:scoreData.composer.c_str()];

    result.ticksPerQuarter = scoreData.ticksPerQuarter > 0 ? scoreData.ticksPerQuarter : 1;

    NSMutableArray<MxPartTransfer *> *parts = [NSMutableArray array];
    for (const auto &part : scoreData.parts) {
        MxPartTransfer *pt = [[MxPartTransfer alloc] init];

        if (!part.uniqueId.empty())
            pt.xmlID = [NSString stringWithUTF8String:part.uniqueId.c_str()];
        if (!part.name.empty())
            pt.name = [NSString stringWithUTF8String:part.name.c_str()];
        if (!part.abbreviation.empty())
            pt.abbreviation = [NSString stringWithUTF8String:part.abbreviation.c_str()];

        NSMutableArray<MxMeasureTransfer *> *measures = [NSMutableArray array];
        for (int mi = 0; mi < (int)part.measures.size(); ++mi) {
            MxMeasureTransfer *mt = buildMeasure(part.measures[mi], mi + 1, mi == 0);
            // Override measure number with the parsed value if available.
            if (!part.measures[mi].number.empty()) {
                int n = std::atoi(part.measures[mi].number.c_str());
                if (n > 0) mt.number = n;
            }
            [measures addObject:mt];
        }
        pt.measures = measures;
        [parts addObject:pt];
    }
    result.parts = parts;
    return result;
}

@end
