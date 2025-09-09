// import Video from './packages/Video';
import { useState } from 'react';
import { ScrollView, StyleSheet, Text, TouchableOpacity } from 'react-native';
import ShareView from './packages/ShareView';

function App() {
  return <AppContent />;
}

function AppContent() {
  const [copy, setCopy] = useState(false);

  return (
    <ScrollView style={{ marginTop: 100 }}>
      {/* <Video
        style={styles.root}
        source={{
          uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        }}
        shareTagElement="Video"
      />
      {copy ? (
        <Video
          style={styles.rootCopy}
          source={{
            uri: 'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
          }}
          shareTagElement="Video"
        />
      ) : null} */}
      <ShareView
        shareTagElement="text copu"
        style={{ backgroundColor: 'red' }}
        sharingAnimatedDuration={5000}
      >
        <Text>Copy Text</Text>
      </ShareView>
      {copy ? (
        <ShareView
          shareTagElement="text copu"
          style={{ marginTop: 200, height: 300, backgroundColor: 'red' }}
          sharingAnimatedDuration={5000}
        >
          <Text>Copy Text</Text>
        </ShareView>
      ) : null}
      <TouchableOpacity style={styles.copy} onPress={() => setCopy(!copy)}>
        <Text>Copy</Text>
      </TouchableOpacity>
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  root: {
    width: '100%',
    height: 400,
    backgroundColor: 'black',
  },
  rootCopy: {
    width: '55%',
    height: 200,
    marginLeft: '10%',
    backgroundColor: 'black',
  },
  copy: {
    height: 33,
    marginTop: 20,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'blue',
  },
  shareView: {
    marginTop: 20,
    backgroundColor: 'red',
  },
});

export default App;
