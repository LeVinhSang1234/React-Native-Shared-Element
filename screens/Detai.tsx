import { Image, Text, View } from 'react-native';
import ShareView from '../packages/ShareView';

export default function Detail() {
  return (
    <View style={{ paddingTop: 100 }}>
      <ShareView
        shareTagElement="Video111"
        style={{ backgroundColor: 'red', height: 200 }}
      >
        <Text>Hello</Text>
        <Text>Hello</Text>
        <Image
          source={require('./test.png')}
          style={{ width: 300, height: 100 }}
        />
      </ShareView>
    </View>
  );
}
