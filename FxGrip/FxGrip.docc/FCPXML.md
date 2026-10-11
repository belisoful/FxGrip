# FCPXML

Read and write Final Cut Pro's interchange format, capture an effect as an FCPXML filter, and apply one.

## Overview

FCPXML is the XML format Final Cut Pro exports and imports: a `.fcpxml` file, or a `.fcpxmld`
package whose `Info.fcpxml` holds the document. The format is versioned from 1.0 through 1.14, each
version with its own DTD inside the Final Cut Pro application. An FxPlug effect appears in a
project as a `filter-video` element whose `effect` resource carries the uid `FxPlug:` followed by
the plug-in's UUID, with one `param` per parameter.

FxGrip models the whole format and connects it to the parameter subsystem:

- ``FxGripFCPXMLDocument`` reads and writes files and packages, tracks the version, and
  validates against the schema or the installed DTD.
- ``FxGripFCPXMLElement`` is the typed view of any element; the typed subclasses cover resources,
  params and keyframes, filters, story elements, markers, metadata, the library tree, and text.
- ``FxGripFCPXMLSchema`` knows every element and attribute of every version, from a table
  `Scripts/make-fcpxml-schema.py` generates out of Apple's DTDs.
- ``FxGripFCPXMLAPI_v1-class`` captures the effect as a filter and applies a filter to it, through the
  API manager's `fcpxmlAPIv1`.
- ``FxGripFCPXMLPasteboard`` and ``FxGripFinalCutPro`` move documents to and from Final Cut Pro.

The workflow-extension side of the exchange is <doc:WorkflowExtensions>.

## The document

```objc
NSError *error = nil;
FxGripFCPXMLDocument *document = [[FxGripFCPXMLDocument alloc] initWithContentsOfURL:url error:&error];
for (FxGripFCPXMLProject *project in document.projects) {
    FxGripFCPXMLStoryElement *sequence = project.sequence;
    for (FxGripFCPXMLStoryElement *clip in sequence.spine.storyChildren) {
        for (FxGripFCPXMLFilter *filter in clip.videoFilters) {
            NSString *uuid = filter.effect.fxPlugUUID;   // nil for a Motion template
        }
    }
}
```

A new document starts at the latest version with an empty `resources` element. Resources take
identifiers in Final Cut Pro's `r1`, `r2`, … form from ``FxGripFCPXMLResources/addResource:``, and
``FxGripFCPXMLResources/effectForFxPlugUUID:name:`` adds the plug-in's effect once. Story
elements keep the DTD's child order when added through their typed methods, so a built document
validates.

Every element wraps an `NSXMLElement`, and wrappers hold no state of their own: two wrappers over
the same node are equal, unknown elements and attributes pass through a round trip untouched, and
`copy` is a deep, detached copy.

## Time

FCPXML writes a time as a rational number of seconds with an `s` suffix. ``FxGripFCPXMLTime``
converts in both directions and reduces to lowest terms, so a `CMTime` of 2002/60000 writes as
`1001/30000s`. The typed accessors read and write times directly:

```objc
clip.offset = CMTimeMake(30030, 30000);
CMTime frame = document.resources.formats.firstObject.frameDuration;
```

## Versions and validation

``FxGripFCPXMLDocument/validationProblems`` checks the tree against the schema at the document's
declared version: unknown elements and attributes, attributes a version lacks, missing required
attributes, enumeration values, times, disallowed children, duplicate identifiers, and dangling
references. ``FxGripFCPXMLDocument/minimumVersion`` answers the oldest version that defines
everything the document carries, so a writer can pick a version an older Final Cut Pro reads.
``FxGripFCPXMLDocument/validateAgainstDTDAtURL:error:`` validates with the DTD, taking the
installed Final Cut Pro's when passed nil.

The schema table is generated. After a Final Cut Pro update adds a DTD version, run
`Scripts/make-fcpxml-schema.py` and update the pin in `FxGripFCPXMLSchemaTests`.

## Capture and apply

The API captures the effect's parameters as a filter, or as a document that also carries the
effect resource and a clip:

```objc
id<FxGripFCPXMLAPI_v1> fcpxml = self.apiManager.fcpxmlAPIv1;
FxGripFCPXMLDocument *document = nil;
[fcpxml captureDocument:&document atTime:time options:FxGripFCPXMLCaptureKeyframes];
[document writeToURL:url error:&error];
```

Each parameter becomes a `param` named after the parameter and keyed by its ID; a color writes
as `r g b a`, a point as `x y`, a toggle as `0` or `1`, and a menu as its index.
`FxGripFCPXMLCaptureKeyframes` reads the host's keyframes through `FxKeyframeAPI_v3` into a
`keyframeAnimation`; `FxGripFCPXMLCaptureCustomValues` archives a custom value into a nested
`archive` param.

Applying matches each param by key, then by name when asked, and writes through the presets API
so the plug-in compatibility check and the tag boundary hold. A keyframed param writes at each
keyframe time, with a host keyframe added first where the keyframe API is vended. The options
relax the apply: ignore compatibility, match names, ignore keyframes, ignore the tag boundary,
and bracket the writes in an undo group.

```objc
FxGripFCPXMLDocument *incoming = [FxGripFCPXMLPasteboard documentFromPasteboard:pasteboard error:&error];
[fcpxml applyDocument:incoming atTime:time options:FxGripFCPXMLApplyMatchNames | FxGripFCPXMLApplyUndoGroup];
```

A preset converts to a filter and back without a host through `FxGripPreset (FCPXML)`; the
API's `presetFromFilter:label:` and `filterFromPreset:inDocument:` add the plug-in identity and
the parameter names.

## Reaching Final Cut Pro

``FxGripFinalCutPro`` finds the installed application and its DTDs, and opens a document in it,
which imports the document into the open library. ``FxGripFCPXMLPasteboard`` writes a document
under the `com.apple.finalcutpro.xml` type, which Final Cut Pro accepts as a drop, and reads a
document from that type, a dropped file, or a string. A plug-in's inspector cannot start a drag
into the host, so the drag paths serve the workflow extension.

## Topics

### Documents

- ``FxGripFCPXMLDocument``
- ``FxGripFCPXMLVersion``
- ``FxGripFCPXMLTime``
- ``FxGripFCPXMLSchema``
- ``FxGripFCPXMLSchemaElement``
- ``FxGripFCPXMLSchemaAttribute``

### Elements

- ``FxGripFCPXMLElement``
- ``FxGripFCPXMLResources``
- ``FxGripFCPXMLResource``
- ``FxGripFCPXMLFormat``
- ``FxGripFCPXMLAsset``
- ``FxGripFCPXMLMediaRep``
- ``FxGripFCPXMLEffect``
- ``FxGripFCPXMLMedia``
- ``FxGripFCPXMLLocator``
- ``FxGripFCPXMLParam``
- ``FxGripFCPXMLKeyframeAnimation``
- ``FxGripFCPXMLKeyframe``
- ``FxGripFCPXMLFade``
- ``FxGripFCPXMLFilter``
- ``FxGripFCPXMLFilterMask``
- ``FxGripFCPXMLData``
- ``FxGripFCPXMLStoryElement``
- ``FxGripFCPXMLMarker``
- ``FxGripFCPXMLMetadata``
- ``FxGripFCPXMLLibrary``
- ``FxGripFCPXMLEvent``
- ``FxGripFCPXMLProject``
- ``FxGripFCPXMLText``
- ``FxGripFCPXMLTextStyle``

### Parameter values

- ``FxGripFCPXMLValue``
- ``FxGripFCPXMLAPI_v1-protocol``
- ``FxGripFCPXMLAPI_v1-class``
- ``FxGripFCPXMLCaptureOptions``
- ``FxGripFCPXMLApplyOptions``

### Final Cut Pro

- ``FxGripFinalCutPro``
- ``FxGripFCPXMLPasteboard``
- ``FxGripFCPXMLPasteboardType``
