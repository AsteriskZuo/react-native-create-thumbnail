import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-create-thumbnail' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const CreateThumbnail = NativeModules.CreateThumbnail
  ? NativeModules.CreateThumbnail
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function multiply(a: number, b: number): Promise<number> {
  return CreateThumbnail.multiply(a, b);
}

export async function createThumbnail(params: {
  videoUrl: string;
  timestamp: number;
  thumbFormat?: string;
  thumbSize?: number;
  cacheName: String;
}): Promise<{
  path: string;
  size: number;
  mime: string;
  width: number;
  height: number;
}> {
  const ret = await CreateThumbnail.create({
    url: params.videoUrl,
    timeStamp: params.timestamp,
    format: params.thumbFormat,
    dirSize: params.thumbSize,
    cacheName: params.cacheName,
  });
  return ret;
}
