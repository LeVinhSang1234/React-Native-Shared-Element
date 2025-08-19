# Video Component Props

This document describes all the props supported by the custom `Video` React Native component.

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
| `progressInterval`       | number    | `250`     | Interval (ms) for progress updates via `onProgress`.                                          |
| `enableProgress`         | boolean   | `false`   | Enable progress events (`onProgress`).                                                        |
| `enableOnLoad`           | boolean   | `false`   | Enable load events (`onLoad`).                                                                |
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

## Example Usage

```tsx
<Video
  source={{ uri: 'https://example.com/video.mp4' }}
  loop
  muted={false}
  paused={false}
  volume={0.8}
  resizeMode="cover"
  progressInterval={500}
  enableProgress
  onProgress={data => console.log(data)}
  onEnd={() => console.log('Video ended')}
  sharingAnimatedDuration={500}
  shareTagElement="myVideo"
  hiddenWhenShareElement={true}
/>
```
