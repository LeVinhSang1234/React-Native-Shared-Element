# @rn-slv/react-native-shared-element

A custom React Native component for shared element transitions, supporting both **video** and **any view** (images, text, custom layouts).

---

## Features

- Shared element transitions for video and any React Native view
- Smooth, native-powered animations between screens
- Full support for React Navigation (auto integration)
- Exposes imperative methods for advanced control
- TypeScript ready
- All transitions and animations are handled fully on the native side (no JS overlays or hacks)

---

> **Note:**
> The video component uses [KTVHTTPCache](https://github.com/ChangbaDevs/KTVHTTPCache) for advanced HTTP caching on **iOS**, and [OkHttp](https://square.github.io/okhttp/) for efficient networking on **Android**.

---

## Source

GitHub: [https://github.com/LeVinhSang1234/React-Native-Shared-Element/tree/share-element](https://github.com/LeVinhSang1234/React-Native-Shared-Element/tree/share-element)

---

---

## Installation

```bash
npm install @rn-slv/react-native-shared-element
# or
yarn add @rn-slv/react-native-shared-element
```

### iOS

After installation, run pod install in the ios directory:

```bash
cd ios && pod install
```

---

## Note: KTVHTTPCache iOS Build Fix

If you encounter build errors related to `LONG_LONG_MAX` when building for iOS, the Podfile includes an automatic fix using the following script:

```ruby
files = `find Pods -name KTVHCRange.h`.split("\n")
files.each do |file|
  system("sed -i '' -e 's/LONG_LONG_MAX/LLONG_MAX/g' \"#{file}\"")
end
```

Example:

```ruby
post_install do |installer|
    react_native_post_install(
      installer,
      config[:reactNativePath],
      :mac_catalyst_enabled => false,
    )
    files = `find Pods -name KTVHCRange.h`.split("\n")
    files.each do |file|
      system("sed -i '' -e 's/LONG_LONG_MAX/LLONG_MAX/g' \"#{file}\"")
    end
  end
```

---

### Android

Native code is autolinked. No extra steps needed.

---

## Important Note for Navigation Patch

If you are using React Navigation please add the following command to your app's `package.json`:

```json
"postinstall": "if [ -d ./node_modules/@react-navigation/core/lib/module ]; then cp ./node_modules/@rn-slv/react-native-shared-element/packages/auto-navigation.txt ./node_modules/@react-navigation/core/lib/module/useNavigation.js; fi"
```

This ensures the navigation patch is always applied after installing dependencies.

---

## Usage

# Shared Video

You can change the video cache size limit by calling the function `setCacheMaxSize(size: number)` (unit: MB), imported from the package. The default is 300MB.

**Tip:** Call `setCacheMaxSize` as early as possible in your app (ideally before any video is loaded) to ensure the cache limit is applied correctly.

Example:

```tsx
import { Video, setCacheMaxSize } from '@rn-slv/react-native-shared-element';

// Set maximum cache size to 500MB
setCacheMaxSize(500);
```

```tsx
import { Video } from '@rn-slv/react-native-shared-element';

<Video
  source={{
    uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
  }}
  shareTagElement="myVideo"
  sharingAnimatedDuration={500}
  // ...other props
/>;
```

---

The `Video` component also supports passing children, allowing you to overlay any React Native views (such as buttons, text, or icons) on top of the video.

Example:

```tsx
<Video
  source={{ uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' }}
  shareTagElement="myVideo"
  sharingAnimatedDuration={500}
>
  <View>
    <Text style={{ color: 'white' }}>Overlay Text</Text>
    <TouchableOpacity onPress={...}>
      <Icon name="play" />
    </TouchableOpacity>
  </View>
</Video>
```

## Props

| Prop                      | Type                                          | Default      | Description                                                                                                                                      |
| ------------------------- | --------------------------------------------- | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `source`                  | string / { uri: string } / number             | **Required** | Video source. Can be a URL string, local asset, or resource ID.                                                                                  |
| `poster`                  | string / { uri: string } / number             |              | Poster image to display before the video loads.                                                                                                  |
| `loop`                    | boolean                                       | `false`      | If true, the video will loop when it ends.                                                                                                       |
| `muted`                   | boolean                                       | `false`      | If true, the video will be muted.                                                                                                                |
| `paused`                  | boolean                                       | `false`      | If true, the video will be paused.                                                                                                               |
| `seek`                    | number                                        |              | Seek to a specific time (in seconds).                                                                                                            |
| `volume`                  | number                                        | `1`          | Video volume (0 to 1).                                                                                                                           |
| `shareTagElement`         | string                                        |              | Tag for shared element transition.                                                                                                               |
| `resizeMode`              | 'contain' \| 'cover' \| 'stretch' \| 'center' | `'contain'`  | Video resize mode.                                                                                                                               |
| `posterResizeMode`        | 'contain' \| 'cover' \| 'stretch' \| 'center' |              | Poster resize mode.                                                                                                                              |
| `progressInterval`        | number                                        | `250`        | Interval (ms) for progress updates via onProgress.                                                                                               |
| `enableProgress`          | boolean                                       |              | Enable onProgress event (auto if onProgress is provided).                                                                                        |
| `enableOnLoad`            | boolean                                       |              | Enable onLoad event (auto if onLoad is provided).                                                                                                |
| `sharingAnimatedDuration` | number                                        | `350`        | Duration (ms) for shared element transition animation.<br>Note: Will try to get from React Navigation if available, otherwise defaults to 350ms. |
| `fullscreen`              | boolean                                       | `false`      | Enable fullscreen mode for video.                                                                                                                |
| `children`                | ReactNode                                     |              | Any React Native view(s) to overlay on top of the video.                                                                                         |

## Event Props (Video only)

The following event props apply only to the `Video` component:

| Prop          | Type     | Description                                      |
| ------------- | -------- | ------------------------------------------------ |
| `onEnd`       | function | Called when the video reaches the end.           |
| `onLoad`      | function | Called when the video is loaded.                 |
| `onError`     | function | Called when an error occurs.                     |
| `onProgress`  | function | Called periodically with playback progress.      |
| `onLoadStart` | function | Called when the video starts loading.            |
| `onBuffering` | function | Called when the video starts or stops buffering. |

---

## Imperative Methods (Ref)

### Video Ref Methods

```tsx
const videoRef = useRef<VideoRef>(null);

<Video ref={videoRef} source={...} />

// Pause the video playback
videoRef.current?.pause();

// Resume the video playback
videoRef.current?.resume();

// Seek to a specific time (in seconds)
videoRef.current?.seek(30);

// Measure the component's dimensions (returns {x, y, width, height, pageX, pageY})
videoRef.current?.measure((data) => {
  console.log('Dimensions:', data);
});

// Prepare for recycle (preserves shared element for transition)
// Triggers shared element back transition.
// This is the main method for backShareElement. Call it manually if you want to run the shared element transition when navigating back, especially in cases where you do not use navigation.
await videoRef.current?.prepareForRecycle();

// Present the fullscreen video player
videoRef.current?.presentFullscreenPlayer();

// Dismiss the fullscreen video player
videoRef.current?.dismissFullscreenPlayer();
```

# Shared View

```tsx
import { ShareView } from '@rn-slv/react-native-shared-element';

<ShareView shareTagElement="myView">
  <Text style={{ fontSize: 24, color: 'tomato' }}>Hello Shared View</Text>
  <Image source={require('./test.png')} style={{ width: 200, height: 120 }} />
  {/* Any children except <Video> */}
</ShareView>;
```

> **Note:**
> You can place a `<Video>` component inside a `ShareView`, but `ShareView` itself will not share the video as a shared element. If you want to share the video, use the `shareTagElement` prop directly on the `<Video>` component. For images, text, and other standard React Native views, you can use `ShareView` as usual.

| Prop                      | Type      | Default | Description                                                                                                                                                                                                                                       |
| ------------------------- | --------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `shareTagElement`         | string    |         | Tag for shared element transitions between views.                                                                                                                                                                                                 |
| `sharingAnimatedDuration` | number    | `350`   | Duration (ms) for shared element transition animation.<br>**Note:** The component will attempt to get `sharingAnimatedDuration` from React Navigation if available, but in some cases it may not be present. If not set, the default is `350` ms. |
| `children`                | ReactNode |         | Any React Native view(s) to be shared.                                                                                                                                                                                                            |

---

```tsx
const shareViewRef = useRef<ShareViewRef>(null);

<ShareView ref={shareViewRef} shareTagElement="myView">
  {/* ... */}
</ShareView>;

// Prepare for recycling (advanced)
await shareViewRef.current?.prepareForRecycle();
```

> **Note:**  
> Shared element transitions can work between any two tags on the same screen, not just between screens or with react-navigation. You can trigger a shared transition between two `shareTagElement` values anywhere in your UI.
>
> The `prepareForRecycle` method is designed specifically to address an Android limitation:  
> When navigating back on Android, the content of the previous screen may be destroyed or lost before the shared element transition can occur.  
> By calling `prepareForRecycle()` manually **before** triggering a back navigation in React Native, you ensure that the shared content is preserved and can be animated smoothly during the transition.
>
> **Usage:**
>
> - You are **not required** to call this method. If you don't call it, the shared element transition will not run and the screen will just go back as normal.
> - If you want to ensure the shared element effect works on Android when going back, call `await shareViewRef.current?.prepareForRecycle();` right before navigating back (e.g. in your custom back handler or before calling `navigation.goBack()`).
> - Not needed on iOS, but safe to call on both platforms.

---

## License

MIT License - see the [LICENSE](LICENSE) file for details.

---

## Author

Sang Le (lsang2884@gmail.com)

<video src="https://github.com/user-attachments/assets/24d59a51-fd69-41c0-b299-1e031c982607" controls width="400"></video>
