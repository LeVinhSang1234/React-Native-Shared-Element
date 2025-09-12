import { Image, Pressable, StyleSheet, Text, View } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import ShareView from '../packages/ShareView';

export default function Home() {
  const navigation = useNavigation();

  return (
    <View style={styles.flex}>
      <ShareView shareTagElement="Video111" style={{ backgroundColor: 'red' }}>
        <Text>Hello</Text>
        <Text>Hello</Text>
        <Image
          source={require('./test.png')}
          style={{ width: 300, height: 100 }}
        />
      </ShareView>
      <Pressable onPress={() => navigation.navigate('Detail' as never)}>
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
