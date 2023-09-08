//
//  SequenceInspectorView.swift
//  Sequential
//
//  Created by Kyle Erhabor on 8/22/23.
//

import SwiftUI
import UniformTypeIdentifiers

struct SequenceInspectorMixedFileNameView: View {
  let count: Int

  var body: some View {
    text
  }

  @TextBuilder
  var text: Text {
    Text("Mixed")

    Text("(\(count) images)")
      .foregroundStyle(.secondary)
  }
}

struct SequenceInspectorMixedFileSizeView: View {
  let sizes: [Int]
  let style: ByteCountFormatStyle

  var body: some View {
    text
  }

  @TextBuilder
  var text: Text {
    let size = sizes.reduce(0, +)
    let average = Int(Double(size) / Double(sizes.count))

    Text(size.formatted(style))

    Text("(~\(average.formatted(style)))")
      .foregroundStyle(.secondary)
  }
}

func inspectSize(_ size: Size, with style: IntegerFormatStyle<Int>) -> String {
  "\(size.width.formatted(style)) × \(size.height.formatted(style))"
}

struct SequenceInspectorMixedImageSizeView: View {
  let sizes: [Size]
  let style: IntegerFormatStyle<Int>

  var body: some View {
    text
  }

  @TextBuilder
  var text: Text {
    let min = sizes.min { $0.area < $1.area }!
    let max = sizes.max { $0.area < $1.area }!

    if min == max {
      Text(inspectSize(min, with: style))
    } else {
      Text("Mixed")

      Text("(\(inspectSize(min, with: style)) — \(inspectSize(max, with: style)))")
        .foregroundStyle(.secondary)
    }
  }
}

struct SequenceInspectorView: View {
  let images: [SeqImage]

  var body: some View {
    Form {
      let count = images.count

      Section {
        LabeledContent("File name:") {
          Group {
            if count == 1 {
              Text(images.first!.url.lastPathComponent)
            } else {
              SequenceInspectorMixedFileNameView(count: count)
            }
          }.textSelection(.enabled)
        }

        LabeledContent("File type:") {
          let list: [String] = images.compactMap(\.type).removingDuplicates().map { type in
            type.localizedDescription ?? type.preferredFilenameExtension?.capitalized ?? type.description
          }

          Text(list, format: .list(type: .and, width: .narrow))
            .textSelection(.enabled)
        }

        LabeledContent("File size:") {
          let style = ByteCountFormatStyle(style: .file)
          let sizes = images.compactMap(\.fileSize)

          Group {
            if count == 1 {
              Text(sizes.first!.formatted(style))
            } else {
              SequenceInspectorMixedFileSizeView(sizes: sizes, style: style)
            }
          }.textSelection(.enabled)
        }

        // We're not going to bother supporting creation/modification fields since they're less relevant for the app here
        // (this is an image viewer, not an editor) plus require a declared privacy intent.
      }

      // TODO: Figure out how to make a Divider span both the label and content
      //
      // Color.clear takes up frame size regardless of the height of zero, so we've created an artificial border here.
      Color.clear.frame(height: 0)

      Section {
        LabeledContent("Image size:") {
          let style = IntegerFormatStyle<Int>.number.grouping(.never)

          if count == 1 {
            let image = images.first!

            Text(inspectSize(image.size, with: style))
          } else {
            SequenceInspectorMixedImageSizeView(sizes: images.map(\.size), style: style)
          }
        }
      }

      Spacer()
    }
    .formStyle(.columns)
    .textScale(.secondary)
    .padding()
  }
}

let chapterBaseURL = URL(string: "file:/Users/user/Downloads/The Ancient Magus' Bride (Manga) (Volume 1)")!

func chapter(
  at url: URL,
  size: Size,
  type: UTType,
  fileSize: Int
) -> SeqImage {
  .init(
    id: .init(),
    url: url,
    size: size,
    type: type,
    fileSize: fileSize
  )
}

func chapter(
  numbered number: Int,
  type: UTType,
  fileSize: Int
) -> SeqImage {
  chapter(
    at: chapterBaseURL.appending(path: "The Ancient Magus' Bride (Chapter \(number)).jpg"),
    size: .init(width: 2144, height: 3056),
    type: type,
    fileSize: fileSize
  )
}

struct SequenceInspectorPreviewView: View {
  let images: [SeqImage]

  var body: some View {
    SequenceInspectorView(images: images)
      .padding()
      .frame(width: 240)
  }
}

#Preview {
  SequenceInspectorPreviewView(images: [chapter(numbered: 1, type: .png, fileSize: 2_100_000)])
}

#Preview {
  SequenceInspectorPreviewView(
    images: [
      chapter(numbered: 2, type: .png, fileSize: 2_200_000),
      chapter(numbered: 3, type: .jpeg, fileSize: 1_900_000),
      chapter(numbered: 4, type: .avif, fileSize: 2_600_000)
    ]
  )
}

#Preview {
  SequenceInspectorPreviewView(
    images: [
      chapter(
        at: chapterBaseURL.appending(path: "The Ancient Magus' Bride - c001 (v01) - p004-005 [Digital-HD].jpg"),
        size: .init(width: 4290, height: 3056),
        type: .webP,
        fileSize: 10_300_000
      ),
      chapter(
        numbered: 6,
        type: .png,
        fileSize: 230_000
      )
    ]
  )
}
