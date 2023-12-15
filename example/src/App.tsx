import * as React from 'react';

import { StyleSheet, View, Text, Pressable } from 'react-native';
import { multiply, createThumbnail } from 'react-native-create-thumbnail';
import { launchImageLibrary } from 'react-native-image-picker';

export default function App() {
  const [result, setResult] = React.useState<number | undefined>();
  const urlRef = React.useRef<string>();

  React.useEffect(() => {
    multiply(3, 7).then(setResult);
  }, []);

  return (
    <View style={styles.container}>
      <Text>Result: {result}</Text>
      <Pressable
        onPress={() => {
          getVideoUrl({
            onResult: (url) => {
              if (url && url.length > 0) urlRef.current = url;
            },
          })
            .then()
            .catch();
        }}
        style={{
          width: '100%',
          height: 50,
          backgroundColor: 'orange',
          marginBottom: 40,
        }}
      >
        <Text>{'select local video file'}</Text>
      </Pressable>

      <Pressable
        onPress={() => {
          if (!urlRef.current) {
            return;
          }
          createThumbnail({
            videoUrl: urlRef.current,
            timestamp: 0,
            cacheName: 'xxx',
          })
            .then((v) => {
              console.log('test:thumb:', v);
            })
            .catch((e) => {
              console.log('test:thumb:error:', e);
            });
        }}
        style={{ width: '100%', height: 50, backgroundColor: 'orange' }}
      >
        <Text>{'gen local video file thumb'}</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  box: {
    width: 60,
    height: 60,
    marginVertical: 20,
  },
});

export async function getVideoUrl(params: {
  onResult: (url?: string) => void;
}) {
  try {
    const ret = await launchImageLibrary(
      { mediaType: 'video', presentationStyle: 'fullScreen' },
      (response) => {
        console.log('test:video:', response);
        params.onResult(response.assets?.[0]?.uri ?? '');
      }
    );
    console.log('test:ret:', ret);
  } catch (error) {
    console.warn('test:e:', error);
  }
}
