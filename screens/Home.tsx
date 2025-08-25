import { Text, TouchableOpacity } from 'react-native';
import { useTranslate } from '../languages/provider';
import { SafeAreaView } from 'react-native-safe-area-context';

export default function Home() {
  const t = useTranslate();
  return (
    <SafeAreaView>
      <Text>
        {t('hello.title', {
          name: <Text style={{ color: 'red' }}>Sang; V</Text>,
        })}
      </Text>
      <TouchableOpacity onPress={() => t.change('vi')}>
        <Text>Change</Text>
      </TouchableOpacity>
    </SafeAreaView>
  );
}
