import QtQuick
import qs.Commons

Item {
  id: root

  property string text: ""
  property string fontFamily: Style.font.family
  property real fontSize: Style.font.body
  property color color: Color.foreground
  property bool debugBounds: false

  readonly property int renderedFontSize: Math.max(1, Math.round(fontSize))
  readonly property real tightWidth: Math.max(1, glyphMetrics.tightBoundingRect.width)
  readonly property real horizontalCorrection: glyph.implicitWidth / 2 - (glyphMetrics.tightBoundingRect.x + tightWidth / 2)
  readonly property real paintedCenterX: glyph.x + glyphMetrics.tightBoundingRect.x + tightWidth / 2
  readonly property real baselineY: glyph.y + glyph.baselineOffset

  TextMetrics {
    id: glyphMetrics
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    text: root.text
  }

  Text {
    id: glyph
    textFormat: Text.PlainText
    // Position explicitly with subpixel coordinates. anchors.centerIn rounds
    // the base x to an integer before horizontalCenterOffset is applied, so
    // the correction could never fully center the painted bounds (up to 1px
    // off for glyphs whose tight box is wider than the advance width).
    // Keep the shared line box and baseline intact; correcting only the
    // horizontal painted bounds avoids per-glyph vertical drift.
    x: parent.width / 2 - implicitWidth / 2 + root.horizontalCorrection
    y: parent.height / 2 - implicitHeight / 2
    text: root.text
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    renderType: Text.NativeRendering
  }

  Rectangle {
    visible: root.debugBounds
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: "#4488ff"
  }

  Rectangle {
    visible: root.debugBounds
    x: 0
    y: Math.round(root.baselineY)
    width: parent.width
    height: 1
    color: "#44ff88"
  }
}
