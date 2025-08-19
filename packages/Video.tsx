import VideoNativeComponent, {
  Commands,
  VideoNativeProps,
} from 'natives/VideoNativeComponent';
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

let useHeaderHeight: () => number;
try {
  const nav = require('@react-navigation/elements');
  useHeaderHeight = nav.useHeaderHeight;
} catch (e) {
  useHeaderHeight = () => 0;
}

type TNativeRef = React.ComponentRef<typeof VideoNativeComponent>;

export interface VideoRef {
  measure: (callback: MeasureOnSuccessCallback) => void;
}

export interface VideoProps
  extends Omit<
    VideoNativeProps,
    'resizeMode' | 'source' | 'enableProgress' | 'enableOnLoad' | 'headerHeight'
  > {
  resizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  source: string | { uri: string } | number;
}

const Video = forwardRef<VideoRef, VideoProps>((props, ref) => {
  const {
    source,
    progressInterval = 250,
    volume = 1,
    sharingAnimatedDuration = 350,
    hiddenWhenShareElement = true,
    ...p
  } = props;

  const headerHeight = useHeaderHeight();

  const nativeRef = useRef<TNativeRef>(null);

  useImperativeHandle(ref, () => ({
    measure(callback) {
      nativeRef.current?.measure(callback);
    },
    pause() {
      if (nativeRef.current) Commands.setPaused(nativeRef.current, true);
    },
    resume() {
      if (nativeRef.current) Commands.setPaused(nativeRef.current, false);
    },
    seek(seek: number) {
      if (nativeRef.current) Commands.setSeek(nativeRef.current, seek);
    },
  }));

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  const _source = useMemo(() => preloadVideoSource(source), [source]);

  return (
    <VideoNativeComponent
      {...p}
      ref={nativeRef}
      source={_source}
      enableProgress={!!p.onProgress}
      enableOnLoad={!!p.onLoad}
      progressInterval={progressInterval}
      volume={volume}
      sharingAnimatedDuration={sharingAnimatedDuration}
      hiddenWhenShareElement={hiddenWhenShareElement}
      headerHeight={headerHeight}
    />
  );
});

export default memo(Video);
