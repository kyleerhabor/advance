# Sequential

A macOS app for viewing a collection of images.

## Rationale

The Preview app built-in to macOS is probably one of the most useful features the operating system has to offer. As an app, its capability of opening documents (here, PDFs and images) in a compact form with various options has allowed many people to rely on Preview in their basic workflows. A large, contributing factor to this is the level of integration Preview has with the rest of the system, allowing anyone who knows how to use a Mac to implicitly know how to use Preview.

If Preview is such a great app, why does Sequential—an image viewing app in the same category—exist? Well, Preview has a catch: it excels at managing PDFs, yet is average when invoked with images.

As an app, Preview supports reading and basic editing for documents. To users, this offers a natural experience where documents can be manipulated in a single canvas; however, for an app, this adds considerable complexity to the interactions it must tolerate (think user interactions, but also the data it must process). With [Live Text][live-text], for example, it can be observed that the feature works flawlessly for PDFs, but can have trouble activating for user interactions involving images. This is due to Preview supporting selection in images, where you may have meant to either select a region of an image or to highlight a Live Text interaction. While this may appear to be a single, inconvenient case, Preview is full of instances like so, where PDFs have excellent support for a feature while images lag behind (often times not supporting a feature at all!)

Sequential is an app for reading images. It borrows heavily from Preview for its interaction design choices, but is not constrained by them. The primary purpose of the app is to view a collection of images in a scrolling format, and with a native interface maximizing that focus, the app reaches for the stars. A large part in maintaining that focus is limiting Sequential's scope to image viewing, where the complexity of edit operations can't creep on the app's viewing capabilities.

## Features

- A main canvas for viewing images, and a sidebar for managing them
- Margins:
  - Allow images to cover their whole frame, or make some room for yourself
  - Hide elements in the interface to fully immerse yourself in the imagery
- Continuous scrolling
- Support for Live Text
- Bookmarking
- Copying:
  - Copy images as-is to select folders in a single action
  - No Finder dialog, no file conflicts; just copy
- Fast:
  - Only loads what is required up front, reducing initialization dramatically[^1]
  - Performs downsampling on images to match their on-screen size, improving CPU and memory usage while not compromising image quality.[^2] You can drop thousands of 4K+ images and Sequential won't complain

## Screenshot

<details>
  <summary>An image collection featuring the manga series "Wonder Cat Kyuu-chan"</summary>
  
  <img src="Documentation/Screenshots/Wonder Cat Kyuu-chan.png" alt="The app showcasing the main canvas with one image, and a sidebar with three images. The toolbar contains the title of the current image, a button for configuring image visual effects, and a toggle for the Live Text icon. At the bottom of the sidebar is a tab for listing bookmarked images.">
</details>

<details>
  <summary>A page from the manga series "Children of the Whales" with the sidebar closed and margins set to none</summary>

  <img src="Documentation/Screenshots/Children of the Whales.png" alt="The app showcasing the visible frame of a page from Children of the Whales (volume 18, chapter 73, page 5). The sidebar is closed, so only the toolbar and image featuring the work are present, with the image extending to cover the full width.">
</details>

[^1]: A local copy of the 1st volume of the manga [The Ancient Magus' Bride][the-ancient-magus-bride] (~350 MB) loads in under 1 second on my 2019 MacBook Pro. To compare, Preview loads the same set of images in 7 seconds, and continues to heavily utilize the CPU in the background for much longer.
[^2]: Downsampling involves processing an image to create a representation at a lower resolution. For Sequential, it's important to support displaying many images at many different sizes without sacrificing image quality or memory consumption. Before an image appears on-screen, it is downsampled at the size of the frame it's given with respect to how many pixels can fit in the frame. The result is that, at smaller frame sizes (e.g. in the sidebar), images appear roughly how they would at larger frame sizes while not introducing side effects like high pixelation.

[live-text]: https://support.apple.com/guide/preview/interact-with-text-in-a-photo-prvw625a5b2c/mac
[the-ancient-magus-bride]: https://en.wikipedia.org/wiki/The_Ancient_Magus%27_Bride
