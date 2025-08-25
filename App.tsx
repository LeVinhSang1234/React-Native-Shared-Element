/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { SafeAreaProvider } from 'react-native-safe-area-context';
import { LanguageProvider } from './languages/provider';
import Home from './screens/Home';

function App() {
  return (
    <SafeAreaProvider>
      <LanguageProvider>
        <Home />
      </LanguageProvider>
    </SafeAreaProvider>
  );
}

export default App;
