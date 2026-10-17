import type { Configuration } from 'webpack';
import baseConfig from './.config/webpack/webpack.config.ts';

type Env = Parameters<typeof baseConfig>[0];

// The scaffolded config prepends `grafana-public-path` (which imports `amd-module`) to the plugin
// entry on Linux/macOS only: its regex expects "/" in the path, so it never matches on Windows.
// Recent Grafana versions (13.x) cannot resolve `amd-module`, so the panel fails with
// "Error loading: netampowering-apm-panel". This plugin has no lazy-loaded chunks and does not need
// a runtime public path, so drop that rule to get the same bundle on every platform.
const config = async (env: Env): Promise<Configuration> => {
  const config = await baseConfig(env);
  config.module!.rules = config.module!.rules!.filter(
    (rule) => !JSON.stringify(rule).includes('grafana-public-path')
  );
  return config;
};

export default config;
