/* eslint-disable react-hooks/rules-of-hooks */
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
    | 'headerHeight'
    | 'poster'
    | 'posterResizeMode'
    | 'hiddenWhenShareElement'
  > {
  resizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  posterResizeMode?: 'contain' | 'cover' | 'stretch' | 'center';
  source?: string | { uri: string } | number;
  poster?: string | { uri: string } | number;
}

const Video = forwardRef<VideoRef, VideoProps>((props, ref) => {
  const { source, poster, progressInterval = 250, volume = 1, ...p } = props;

  let headerHeight: number = 0;
  try {
    headerHeight = useHeaderHeight();
  } catch {}

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
      hiddenWhenShareElement
      headerHeight={headerHeight}
    />
  );
});

Video.displayName = 'Video';

export default memo(Video);
