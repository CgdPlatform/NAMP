import webpack from 'webpack';

export class BuildModeWebpackPlugin {
  apply(compiler: webpack.Compiler) {
    compiler.hooks.compilation.tap('BuildModeWebpackPlugin', (compilation) => {
      compilation.hooks.processAssets.tap(
        {
          name: 'BuildModeWebpackPlugin',
          stage: webpack.Compilation.PROCESS_ASSETS_STAGE_ADDITIONS,
        },
        (assets) => {
          for (const [filename, asset] of Object.entries(assets)) {
            if (filename.endsWith('plugin.json')) {
              const content = JSON.parse(asset.source().toString());
              const updated = { ...content, buildMode: compilation.options.mode };
              compilation.updateAsset(
                filename,
                new webpack.sources.RawSource(JSON.stringify(updated, null, 4))
              );
            }
          }
        }
      );
    });
  }
}
