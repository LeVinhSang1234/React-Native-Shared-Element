/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { LanguageProvider } from './languages/provider';
import Home from './screens/Home';

function App() {
  return (
    <LanguageProvider>
      <Home />
    </LanguageProvider>
  );
}

export default App;
