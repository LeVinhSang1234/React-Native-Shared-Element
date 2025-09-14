import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import ShareView, { ShareViewRef } from '../packages/ShareView';
import { useRef, useState } from 'react';

export default function Home() {
  const navigation = useNavigation();
  const [copy, setCopy] = useState(false);
  const refShare = useRef<ShareViewRef>(null);

  return (
    <View style={styles.flex}>
      <ShareView
        shareTagElement="Video111"
        style={{ backgroundColor: 'red' }}
        sharingAnimatedDuration={5000}
      >
        <Text>Hello</Text>
        <Text>Hello</Text>
        <Image
          resizeMode="cover"
          source={require('./test.png')}
          style={{ width: 300, height: 100 }}
        />
      </ShareView>
      {copy ? (
        <ShareView
          sharingAnimatedDuration={5000}
          ref={refShare}
          shareTagElement="Video111"
          style={{ backgroundColor: 'red', height: 300 }}
        >
          <Text>Hello</Text>
          <Text>Hello</Text>
          <Image
            resizeMode="cover"
            source={require('./test.png')}
            style={{ width: 300, height: 200 }}
          />
        </ShareView>
      ) : null}
      {/* <Pressable onPress={() => navigation.navigate('Detail' as never)}>
        <Text>Detail</Text>
      </Pressable> */}
      <Pressable
        onPress={async () => {
          if (copy) {
            await refShare.current?.prepareForRecycle();
          }
          setCopy(!copy);
        }}
      >
        <Text>Detail</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1 },
  root: {
    height: 400,
    width: '100%',
    backgroundColor: 'black',
  },
});
