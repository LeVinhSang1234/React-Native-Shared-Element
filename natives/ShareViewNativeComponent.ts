/* eslint-disable @react-native/no-deep-imports */
import {
  codegenNativeCommands,
  codegenNativeComponent,
  HostComponent,
  ViewProps,
} from 'react-native';
import { Double } from 'react-native/Libraries/Types/CodegenTypes';

export interface ShareViewNativeProps extends ViewProps {
  readonly shareTagElement?: string;
  readonly headerHeight?: Double;
  readonly sharingAnimatedDuration?: Double;
}

interface NativeCommands {
  initialize: (
    viewRef: React.ElementRef<HostComponent<ShareViewNativeProps>>,
  ) => void;
}

export const Commands = codegenNativeCommands<NativeCommands>({
  supportedCommands: ['initialize'],
});

export default codegenNativeComponent<ShareViewNativeProps>(
  'ShareView',
) as HostComponent<ShareViewNativeProps>;
