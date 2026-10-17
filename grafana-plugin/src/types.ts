export interface CoveragePanelOptions {
  refIdHit: string;
  refIdCalls: string;
  queryHit: string;
  queryCalls: string;
}

export interface MethodData {
  methodId: string;
  className: string;
  methodName: string;
  file: string;
  line: number;
  hit: boolean;
  calls: number;
}

// file path → class name → methods
export type FileTree = Map<string, Map<string, MethodData[]>>;
