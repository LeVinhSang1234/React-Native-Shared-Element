/* eslint-disable react-hooks/rules-of-hooks */
import {
  forwardRef,
  memo,
  useCallback,
  useEffect,
  useImperativeHandle,
  useRef,
} from 'react';
import type { View } from 'react-native';
import type { Ref } from 'react';

import type { ShareViewNativeProps } from '../natives/ShareViewNativeComponent';
import ShareViewNativeComponent, {
  Commands,
} from '../natives/ShareViewNativeComponent';

let useHeaderHeight: () => number;
try {
  const nav = require('@react-navigation/elements');
  useHeaderHeight = nav.useHeaderHeight;
} catch (e) {
  useHeaderHeight = () => 0;
}

type TNativeRef = React.ComponentRef<typeof ShareViewNativeComponent>;

export interface ShareViewProps
  extends Omit<ShareViewNativeProps, 'headerHeight'> {}

// 👉 Đây là type ref export ra cho dev dùng
export interface ShareViewRef extends View {
  prepareForRecycle: () => Promise<void>;
}

const ShareView = forwardRef<ShareViewRef, ShareViewProps>(
  (props, ref: Ref<ShareViewRef>) => {
    const nativeRef = useRef<TNativeRef>(null);

    let headerHeight: number = 0;
    try {
      headerHeight = useHeaderHeight();
    } catch {}

    const prepareForRecycle = useCallback(async () => {
      return new Promise(res => {
        if (nativeRef.current) {
          Commands.prepareForRecycle(nativeRef.current);
        }
        setTimeout(() => res(null), 0);
      });
    }, []);

    useImperativeHandle(
      ref,
      () => {
        return {
          ...(nativeRef.current as unknown as View),
          prepareForRecycle,
        } as ShareViewRef;
      },
      [prepareForRecycle],
    );

    useEffect(() => {
      if (nativeRef.current) Commands.initialize(nativeRef.current);
    }, []);

    return (
      <ShareViewNativeComponent
        {...props}
        ref={nativeRef}
        headerHeight={headerHeight}
      />
    );
  },
);

ShareView.displayName = 'ShareView';

export default memo(ShareView);
