import { Image } from 'react-native';

const sourceCache = new Map<string, string>();

export const preloadVideoSource = (
  source: string | { uri: string } | number,
): string => {
  if (!source) return '';
  return resolveSource(source);
};

const resolveSource = (source: string | { uri: string } | number): string => {
  const cacheKey =
    typeof source === 'object' ? JSON.stringify(source) : String(source);

  if (sourceCache.has(cacheKey)) {
    const cached = sourceCache.get(cacheKey)!;
    return cached;
  }

  let resolvedSource = '';

  if (typeof source === 'string') {
    resolvedSource = source;
  } else if (typeof source === 'object' && source.uri) {
    resolvedSource = source.uri;
  } else if (typeof source === 'number') {
    const resolved = Image.resolveAssetSource(source);
    resolvedSource = resolved?.uri || '';
    if (
      resolvedSource &&
      !resolvedSource.startsWith('file://') &&
      !resolvedSource.startsWith('http')
    ) {
      if (resolvedSource.startsWith('/')) {
        resolvedSource = 'file://' + resolvedSource;
      }
    }
  }
  sourceCache.set(cacheKey, resolvedSource);
  return resolvedSource;
};
