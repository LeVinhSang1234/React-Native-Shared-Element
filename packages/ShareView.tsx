import {
  forwardRef,
  memo,
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

type TNativeRef = React.ComponentRef<typeof ShareViewNativeComponent>;

export interface ShareViewProps
  extends Omit<ShareViewNativeProps, 'headerHeight'> {}

const ShareView = forwardRef<View, ShareViewProps>((props, ref: Ref<View>) => {
  const nativeRef = useRef<TNativeRef>(null);

  useImperativeHandle(
    ref,
    () => nativeRef.current as React.ComponentRef<typeof View>,
    [],
  );

  useEffect(() => {
    if (nativeRef.current) Commands.initialize(nativeRef.current);
  }, []);

  return <ShareViewNativeComponent {...props} ref={nativeRef} />;
});

ShareView.displayName = 'ShareView';

export default memo(ShareView);
