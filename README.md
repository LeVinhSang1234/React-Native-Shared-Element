# @rn-video/video-share-element

A custom React Native video component with shared element transitions support.

## Installation

```bash
npm install @rn-video/video-share-element
# or
yarn add @rn-video/video-share-element
```

### iOS

After installation, run pod install in the ios directory:

```bash
cd ios && pod install
```

### Android

For Android, the native code will be automatically linked through autolinking.

## Usage

```tsx
import Video from '@rn-video/video-share-element';

<Video
  source={{ uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4' }}
  loop
  muted={false}
  paused={false}
  volume={0.8}
  resizeMode="cover"
  progressInterval={500}
  onProgress={data => console.log(data)}
  onEnd={() => console.log('Video ended')}
  sharingAnimatedDuration={500}
  shareTagElement="myVideo"
  hiddenWhenShareElement={true}
/>
```

## Props

| Prop                     | Type      | Default   | Description                                                                                   |
|--------------------------|-----------|-----------|-----------------------------------------------------------------------------------------------|
| `source`                 | string / { uri: string } / number | **Required** | Video source. Can be a URL string, a local asset, or a resource ID.                           |
| `loop`                   | boolean   | `false`   | If `true`, the video will loop when it reaches the end.                                       |
| `muted`                  | boolean   | `false`   | If `true`, the video will be muted.                                                           |
| `paused`                 | boolean   | `false`   | If `true`, the video will be paused.                                                          |
| `seek`                   | number    |           | Seek to a specific time (in seconds).                                                         |
| `volume`                 | number    | `1`       | Set the video volume (range: `0` to `1`).                                                     |
| `resizeMode`             | string    | `'contain'` | Video resize mode: `'contain'`, `'cover'`, `'stretch'`, `'center'`.                           |
| `shareTagElement`        | string    |           | Tag for shared element transitions between video views.                                       |
| `progressInterval`       | number    | `250`     | Interval (ms) for progress updates via `onProgress`.     |
| `hiddenWhenShareElement` | boolean   | `true`    | Hide video when sharing as a shared element.                                                  |
| `sharingAnimatedDuration`| number    | `350`     | Duration (ms) for shared element transition animation.                                        |

## Event Props

| Prop           | Type      | Description                                                                 |
|----------------|-----------|-----------------------------------------------------------------------------|
| `onEnd`        | function  | Called when the video reaches the end.                                      |
| `onLoad`       | function  | Called when the video is loaded.                                            |
| `onError`      | function  | Called when an error occurs.                                                |
| `onProgress`   | function  | Called periodically with playback progress.                                 |
| `onLoadStart`  | function  | Called when the video starts loading.                                       |
| `onBuffering`  | function  | Called when the video starts or stops buffering.                            |

## Imperative Methods (Ref)

The Video component exposes imperative methods through ref:

```tsx
const videoRef = useRef<VideoRef>(null);

<Video ref={videoRef} source={...} />

// Control video playback
videoRef.current?.pause();     // Pause video
videoRef.current?.resume();    // Resume video
videoRef.current?.seek(30);    // Seek to 30 seconds

// Measure component
videoRef.current?.measure((data) => {
  console.log('Dimensions:', data); // {x, y, width, height, pageX, pageY}
});
```

### VideoRef Methods

| Method                  | Parameters              | Description                                                                 |
|-------------------------|-------------------------|-----------------------------------------------------------------------------|
| `pause()`              | -                       | Pause video playback immediately                                           |
| `resume()`             | -                       | Resume video playback from current position                                |
| `seek(seconds)`        | `seconds: number`       | Seek to specific time position (in seconds)                                |
| `measure(callback)`    | `callback: function`    | Measure component dimensions and position                                  |

## Requirements

- React >= 18.0.0
- React Native >= 0.76.0
- iOS >= 13.0

## License

MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Sang Le lsang2884@gmail.com
