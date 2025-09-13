import { Image, Text, View } from 'react-native';
import ShareView from '../packages/ShareView';

export default function Detail() {
  return (
    <View style={{ paddingTop: 100 }}>
      <ShareView shareTagElement="Video111" style={{ backgroundColor: 'red' }}>
        <Text>Hello</Text>
        <Text>Hello</Text>
        <Image
          source={require('./test.png')}
          style={{ width: '100%', height: 200 }}
        />
      </ShareView>
    </View>
  );
}
