import { codegenNativeCommands, codegenNativeComponent } from 'react-native';
import type { Double } from 'react-native/Libraries/Types/CodegenTypes';
import type { HostComponent, ViewProps } from 'react-native';

export interface ShareViewNativeProps extends ViewProps {
  readonly shareTagElement?: string;
  readonly headerHeight?: Double;
  readonly sharingAnimatedDuration?: Double;
}

interface NativeCommands {
  initialize: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
  prepareForRecycle: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['initialize', 'prepareForRecycle'],
});

export default codegenNativeComponent<ShareViewNativeProps>(
  'ShareView',
) as HostComponent<ShareViewNativeProps>;
