import { Pressable, StyleSheet, Text, View } from 'react-native';
import Video from '../packages/Video';
import { useNavigation } from '@react-navigation/native';

export default function Home() {
  const navigation = useNavigation();

  return (
    <View style={styles.flex}>
      <Video
        style={styles.root}
        poster={{ uri: 'https://picsum.photos/300/200' }}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        shareTagElement="Video"
      >
        <Text>asdasdadsa</Text>
      </Video>
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
