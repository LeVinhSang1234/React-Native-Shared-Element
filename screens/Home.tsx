import { Text, TouchableOpacity, View } from 'react-native';
import { useTranslate } from '../languages/provider';

export default function Home() {
  const t = useTranslate();
  return (
    <View>
      <Text>
        {t('hello.title', {
          name: <Text style={{ color: 'red' }}>Sang; V</Text>,
        })}
      </Text>
      <TouchableOpacity onPress={() => t.change('vi')}>
        <Text>Change</Text>
      </TouchableOpacity>
    </View>
  );
}
