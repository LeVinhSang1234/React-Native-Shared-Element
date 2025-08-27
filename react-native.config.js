module.exports = {
  dependency: {
    platforms: {
      android: {
        packageName: 'com.sharevideo.video.RCTVideoPackage',
        packageClassName: 'RCTVideoPackage',
      },
      ios: {
        podspecPath: 'rn-video-share-element.podspec',
      },
    },
  },
};
