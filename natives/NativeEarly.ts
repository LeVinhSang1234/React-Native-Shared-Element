import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  prepareForGoBackSync(): boolean;
}

export default TurboModuleRegistry.getEnforcing<Spec>('RCTNativeEarly');
