import VideoNativeComponent, {
  Commands,
  VideoNativeProps,
} from '../natives/VideoNativeComponent';
import {
  forwardRef,
  memo,
  useEffect,
  useImperativeHandle,
  useMemo,
  useRef,
} from 'react';
import { type MeasureOnSuccessCallback } from 'react-native';
import { preloadVideoSource } from './utils';

type TNativeRef = React.ComponentRef<typeof VideoNativeComponent>;

export interface VideoRef {
  measure: (callback: MeasureOnSuccessCallback) => void;
  pause: () => void;
  resume: () => void;
  seek: (seek: number) => void;
}

export interface VideoProps
  extends Omit<
    VideoNativeProps,
    | 'resizeMode'
    | 'source'
    | 'enableProgress'
    | 'enableOnLoad'
    | 'poster'
    | 'posterResizeMode'
    | 'hiddenWhenShareElement'
    | 'cacheMaxSize'
    | 'fullscreenOrientation'
  > {
  resizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  posterResizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  source?: string | { uri: string } | number;
  poster?: string | { uri: string } | number;
  fullscreenOrientation?: 'landscape' | 'portrait';
}

const config = { cacheMaxSize: 300 };

const Video = forwardRef<VideoRef, VideoProps>((props, ref) => {
  const { source, poster, progressInterval = 250, volume = 1, ...p } = props;

  const nativeRef = useRef<TNativeRef>(null);

  useImperativeHandle(ref, () => ({
    measure(callback) {
      nativeRef.current?.measure(callback);
    },
    pause() {
      if (nativeRef.current) Commands.setPausedCommand(nativeRef.current, true);
    },
    resume() {
      if (nativeRef.current) {
        Commands.setPausedCommand(nativeRef.current, false);
      }
    },
    seek(seek: number) {
      if (nativeRef.current) Commands.setSeekCommand(nativeRef.current, seek);
    },
  }));

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  const _source = useMemo(() => preloadVideoSource(source ?? ''), [source]);
  const _poster = useMemo(() => preloadVideoSource(poster ?? ''), [poster]);

  return (
    <VideoNativeComponent
      {...p}
      ref={nativeRef}
      source={_source}
      poster={_poster}
      enableProgress={!!p.onProgress}
      enableOnLoad={!!p.onLoad}
      progressInterval={progressInterval}
      volume={volume}
      cacheMaxSize={config.cacheMaxSize}
    />
  );
});

export function setCacheMaxSize(size: number = 300) {
  config.cacheMaxSize = size;
}

Video.displayName = 'Video';

export default memo(Video);
