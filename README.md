# Advance

A macOS app that simplifies browsing large collections of images.

## Rationale

The Preview app built-in to macOS is probably one of the most useful features the OS has to offer. As a simple productivity app, it fits in many people's workflows for managing documents, but can feel cumbersome when all you need is to view images. This can be seen in features like [Live Text][live-text], where the default automatic selection is unreliable for image viewing, unlike a dedicated image viewer that can unconditionally support this.

Advance is an image viewer that has a plethora of features. In particular: 

- **UI**

  View all your images in a scrollable canvas, supporting customizations like margins and hiding the cursor when scrolling.

- **Bookmarking**

  Bookmark specific images and filter them in the sidebar.

- **Live Text**

  Select text and manipulate subjects in images.

- **Folders**

  Copy images to select folders with the same level of convenience as saving to Photos.

- **Search**

  Configure a search engine to use when opening links in the default web browser, instead of just Safari.

- **Performance**

  Load thousands of images and let Advance handle the rest.[^1]

## Installation

### Downloads

> [!IMPORTANT]
>
> Advance has not been notarized by Apple. To run the app, open it and [follow these instructions][apple-notarization-bypass].

You can download a version of the app from [Releases][releases].

macOS Sonoma 14 or later is required.

### Xcode 

1. Clone the repository (e.g., `git clone https://github.com/kyleerhabor/advance Advance`)
2. Open the project (e.g., `open Advance/Advance.xcodeproj`)
3. Build an archive of Advance (e.g., `Product > Archive`)
4. From Organizer, export a copy of the archived app (i.e., `Distribute App > Custom > Copy App > Next > Export`)
5. Move the exported app to Applications
6. Open the app 

Xcode 26 or later is required.

## Screenshots

<details>
  <summary>Wonder Cat Kyuu-chan</summary>
  <img src="Documentation/Screenshots/Wonder Cat Kyuu-chan.png">
</details>

[^1]: On my 2019 MacBook Pro, loading [Wonder Cat Kyuu-chan][wonder-cat-kyuu-chan], volume 1 (129 images, ~123.8 MB) takes ~1 second, while the complete set of 8 volumes (1,047 images, ~957.8 MB) takes ~2.5 seconds.

[live-text]: https://support.apple.com/guide/preview/interact-with-text-in-a-photo-prvw625a5b2c/mac
[apple-notarization-bypass]: https://support.apple.com/en-us/102445#openanyway
[releases]: https://github.com/kyleerhabor/advance/releases
[wonder-cat-kyuu-chan]: https://en.wikipedia.org/wiki/Wonder_Cat_Kyuu-chan
