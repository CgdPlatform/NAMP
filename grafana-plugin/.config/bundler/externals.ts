import type { Configuration } from 'webpack';

export const externals: Configuration['externals'] = [
  'lodash',
  'jquery',
  'moment',
  'slate',
  'prismjs',
  'react',
  'react-dom',
  'redux',
  'rxjs',
  'd3',
  'angular',
  'amd-module',
  '@grafana/ui',
  '@grafana/data',
  '@grafana/runtime',
  '@grafana/schema',
  ({ request }: { request?: string }, callback: (err?: Error | null, result?: string) => void) => {
    if (request?.startsWith('grafana/')) {
      return callback(undefined, request.replace('grafana/', ''));
    }
    callback();
  },
];
