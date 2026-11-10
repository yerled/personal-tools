# Third-party notices

The scroll-wheel inversion in this app is derived from
[mouse-scroll-flip](https://github.com/yerled/mouse-scroll-flip),
copyright (c) 2026 yerled, MIT License.

Derived files:

- `Sources/PersonalToolsCore/ScrollClassifier.swift`
- `Sources/PersonalToolsCore/ScrollInverter.swift`
- `Sources/PersonalTools/HIDScroll.swift`
- `Sources/PersonalTools/ScrollEventTap.swift`
- `Tests/PersonalToolsCoreTests/ScrollClassifierTests.swift`
- `Tests/PersonalToolsCoreTests/ScrollInverterTests.swift`

The behavior that is preserved on purpose: a scroll event is treated as a
mouse wheel only when it is not continuous, has no gesture phase, and has no
momentum phase. Trackpad and Magic Mouse events are passed through. Vertical
wheel notches are negated. Horizontal notches are negated only when that
option is on. Quartz deltas are written line, then fixed-point, then point,
and the embedded IOHID scroll value is negated for WebKit.

The original license follows.

---

MIT License

Copyright (c) 2026 yerled

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
