import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import Video from '../packages/Video';
import { useNavigation } from '@react-navigation/native';

export default function Detail() {
  const navigation = useNavigation();
  return (
    <View>
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
      <TouchableOpacity onPress={navigation.goBack}>
        <Text>Goback</Text>
      </TouchableOpacity>
    </View>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '100%',
    height: 300,
    backgroundColor: 'red',
    marginTop: 100,
  },
});
