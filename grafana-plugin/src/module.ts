import { PanelPlugin } from '@grafana/data';
import { CoveragePanelOptions } from './types';
import { CoveragePanel } from './CoveragePanel';

const QUERY_HIT =
  'max by (method_id,class,method,file,line) (max_over_time(coverage_method_hit{job="$service_name"}[$__range]) * on(method_id) group_left(class,method,file,line) max by (method_id,class,method,file,line) (last_over_time(coverage_method_info{job="$service_name"}[$__range])))';

const QUERY_CALLS =
  'max by (method_id,class,method,file,line) (max_over_time(coverage_method_calls_total{job="$service_name"}[$__range]) * on(method_id) group_left(class,method,file,line) max by (method_id,class,method,file,line) (last_over_time(coverage_method_info{job="$service_name"}[$__range])))';

export const plugin = new PanelPlugin<CoveragePanelOptions>(CoveragePanel).setPanelOptions((builder) =>
  builder
    .addTextInput({
      path: 'queryHit',
      name: 'Query A — Hit (copy into query editor)',
      defaultValue: QUERY_HIT,
      description: 'Pre-filled PromQL for coverage_method_hit. Copy this into the panel query editor as ref ID A.',
    })
    .addTextInput({
      path: 'queryCalls',
      name: 'Query B — Total calls (copy into query editor)',
      defaultValue: QUERY_CALLS,
      description: 'Pre-filled PromQL for coverage_method_calls_total. Copy this into the panel query editor as ref ID B.',
    })
    .addTextInput({
      path: 'refIdHit',
      name: 'Ref ID — Hit (0/1)',
      defaultValue: 'A',
      description: 'Query ref ID for the coverage_method_hit Prometheus metric',
    })
    .addTextInput({
      path: 'refIdCalls',
      name: 'Ref ID — Total calls',
      defaultValue: 'B',
      description: 'Query ref ID for the coverage_method_calls_total Prometheus metric',
    })
);
