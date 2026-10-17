import React, { useMemo, useState } from 'react';
import { PanelProps, DataFrame, FieldType } from '@grafana/data';
import { useTheme2 } from '@grafana/ui';
import { CoveragePanelOptions, MethodData, FileTree } from './types';

type Props = PanelProps<CoveragePanelOptions>;

function parseFrames(
  series: DataFrame[],
  refIdHit: string,
  refIdCalls: string
): Map<string, MethodData> {
  const methods = new Map<string, MethodData>();

  for (const frame of series) {
    const isHit   = frame.refId === refIdHit;
    const isCalls = frame.refId === refIdCalls;
    if (!isHit && !isCalls) { continue; }

    const valueField = frame.fields.find((f) => f.type === FieldType.number);
    if (!valueField) { continue; }

    const labels   = valueField.labels ?? {};
    const methodId = labels['method_id'];
    if (!methodId) { continue; }

    const lastValue = valueField.values.length > 0
      ? (valueField.values.get(valueField.values.length - 1) as number)
      : 0;

    let entry = methods.get(methodId);
    if (!entry) {
      entry = {
        methodId,
        className:  labels['class']  ?? '',
        methodName: labels['method'] ?? '',
        file:       labels['file']   ?? '',
        line:       parseInt(labels['line'] ?? '0', 10),
        hit:   false,
        calls: 0,
      };
      methods.set(methodId, entry);
    }

    if (isHit)   { entry.hit   = lastValue > 0; }
    if (isCalls) { entry.calls = lastValue; }
  }

  return methods;
}

function buildTree(methods: Map<string, MethodData>): FileTree {
  const tree: FileTree = new Map();
  for (const m of methods.values()) {
    const file = m.file      || '(fichier inconnu)';
    const cls  = m.className || '(classe inconnue)';
    if (!tree.has(file))           { tree.set(file, new Map()); }
    const classes = tree.get(file)!;
    if (!classes.has(cls))         { classes.set(cls, []); }
    classes.get(cls)!.push(m);
  }
  return tree;
}

export function CoveragePanel({ data, options, width, height }: Props) {
  const theme = useTheme2();
  const [search,    setSearch]    = useState('');
  const [collapsed, setCollapsed] = useState<Set<string>>(new Set<string>());

  const methods = useMemo(
    () => parseFrames(data.series as DataFrame[], options.refIdHit ?? 'A', options.refIdCalls ?? 'B'),
    [data.series, options.refIdHit, options.refIdCalls]
  );

  const tree = useMemo(() => buildTree(methods), [methods]);

  const totalMethods = methods.size;
  const hitMethods   = [...methods.values()].filter((m) => m.hit).length;
  const pct          = totalMethods > 0 ? Math.round((hitMethods / totalMethods) * 100) : 0;

  const pctColor = pct >= 80 ? '#4caf50' : pct >= 50 ? '#ff9800' : '#f44336';

  const q = search.toLowerCase();

  const filteredTree: FileTree = new Map();
  for (const [file, classes] of tree) {
    const filteredClasses = new Map<string, MethodData[]>();
    for (const [cls, meths] of classes) {
      const kept = q
        ? meths.filter(
            (m) =>
              m.methodName.toLowerCase().includes(q) ||
              cls.toLowerCase().includes(q) ||
              file.toLowerCase().includes(q)
          )
        : meths;
      if (kept.length > 0) { filteredClasses.set(cls, kept); }
    }
    if (filteredClasses.size > 0) { filteredTree.set(file, filteredClasses); }
  }

  const toggle = (key: string) =>
    setCollapsed((prev) => {
      const next = new Set(prev);
      next.has(key) ? next.delete(key) : next.add(key);
      return next;
    });

  // ── Styles ─────────────────────────────────────────────────────────────────

  const s = {
    root: {
      width, height,
      overflow: 'auto',
      padding: '12px 16px',
      fontFamily: theme.typography.fontFamily,
      background: theme.colors.background.primary,
      color: theme.colors.text.primary,
      fontSize: '13px',
    } as React.CSSProperties,

    header: {
      display: 'flex',
      alignItems: 'center',
      gap: '16px',
      marginBottom: '16px',
      flexWrap: 'wrap' as const,
    },

    pct: { fontSize: '22px', fontWeight: 700, color: pctColor } as React.CSSProperties,

    sub: { fontSize: '12px', color: theme.colors.text.secondary } as React.CSSProperties,

    bar: {
      flexGrow: 1, minWidth: '100px', maxWidth: '260px',
      height: '6px', borderRadius: '3px',
      background: theme.colors.background.secondary,
      overflow: 'hidden',
    } as React.CSSProperties,

    barFill: {
      height: '100%', width: `${pct}%`,
      background: pctColor, transition: 'width .4s ease',
    } as React.CSSProperties,

    input: {
      padding: '5px 10px', borderRadius: '4px',
      border: `1px solid ${theme.colors.border.medium}`,
      background: theme.colors.background.secondary,
      color: theme.colors.text.primary,
      fontSize: '12px', width: '200px',
      outline: 'none',
    } as React.CSSProperties,

    fileRow: {
      display: 'flex', alignItems: 'center', gap: '6px',
      padding: '5px 4px', cursor: 'pointer', userSelect: 'none' as const,
      fontWeight: 600,
      borderTop: `1px solid ${theme.colors.border.weak}`,
      marginTop: '4px',
    },

    classRow: {
      display: 'flex', alignItems: 'center', gap: '6px',
      padding: '3px 4px 3px 22px', cursor: 'pointer', userSelect: 'none' as const,
      color: theme.colors.text.secondary,
    },

    methodRow: {
      display: 'flex', alignItems: 'center', gap: '6px',
      padding: '2px 4px 2px 42px',
    },

    badge: (hit: boolean) => ({
      display: 'inline-flex', alignItems: 'center', justifyContent: 'center',
      width: '14px', height: '14px', borderRadius: '50%',
      background: hit ? '#4caf50' : '#f44336',
      color: '#fff', fontSize: '9px', fontWeight: 700,
      flexShrink: 0,
    } as React.CSSProperties),

    methodName: (hit: boolean) => ({
      color: hit ? theme.colors.text.primary : theme.colors.text.disabled,
      flex: 1, overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' as const,
    } as React.CSSProperties),

    lineNum: {
      fontSize: '11px', color: theme.colors.text.disabled, flexShrink: 0,
    } as React.CSSProperties,

    callCount: {
      marginLeft: 'auto', fontSize: '11px',
      color: theme.colors.text.disabled, whiteSpace: 'nowrap' as const, flexShrink: 0,
    } as React.CSSProperties,

    pctTag: (v: number) => ({
      fontSize: '11px', fontWeight: 600,
      color: v === 100 ? '#4caf50' : v > 0 ? '#ff9800' : '#f44336',
      marginLeft: '6px', flexShrink: 0,
    } as React.CSSProperties),

    empty: {
      color: theme.colors.text.disabled, textAlign: 'center' as const,
      padding: '48px 16px', fontSize: '13px',
    },
  };

  // ── Render ─────────────────────────────────────────────────────────────────

  return (
    <div style={s.root}>
      {/* En-tête */}
      <div style={s.header}>
        <span style={s.pct}>{pct}%</span>
        <div style={s.bar}><div style={s.barFill} /></div>
        <span style={s.sub}>{hitMethods}/{totalMethods} methods covered</span>
        <input
          style={s.input}
          placeholder="Filter…"
          value={search}
          onChange={(e) => setSearch(e.target.value)}
        />
      </div>

      {/* Arbre */}
      {filteredTree.size === 0 ? (
        <div style={s.empty}>
          {totalMethods === 0
            ? 'No data. Configure queries A and B in the panel options.'
            : 'No results.'}
        </div>
      ) : (
        [...filteredTree.entries()]
          .sort(([a], [b]) => a.localeCompare(b))
          .map(([file, classes]) => {
            const fileKey     = `f:${file}`;
            const allMeths    = [...classes.values()].flat();
            const fileHit     = allMeths.filter((m) => m.hit).length;
            const filePct     = allMeths.length > 0 ? Math.round((fileHit / allMeths.length) * 100) : 0;
            const fileOpen    = !collapsed.has(fileKey);

            return (
              <div key={file}>
                {/* Ligne fichier */}
                <div style={s.fileRow} onClick={() => toggle(fileKey)}>
                  <span style={{ fontSize: '10px', color: theme.colors.text.secondary }}>
                    {fileOpen ? '▼' : '▶'}
                  </span>
                  <span>📄 {file}</span>
                  <span style={s.pctTag(filePct)}>{filePct}%</span>
                  <span style={{ ...s.sub, marginLeft: '4px' }}>
                    ({fileHit}/{allMeths.length})
                  </span>
                </div>

                {/* Classes */}
                {fileOpen &&
                  [...classes.entries()]
                    .sort(([a], [b]) => a.localeCompare(b))
                    .map(([cls, meths]) => {
                      const clsKey  = `c:${file}:${cls}`;
                      const clsHit  = meths.filter((m) => m.hit).length;
                      const clsPct  = meths.length > 0 ? Math.round((clsHit / meths.length) * 100) : 0;
                      const clsOpen = !collapsed.has(clsKey);

                      return (
                        <div key={cls}>
                          {/* Ligne classe */}
                          <div style={s.classRow} onClick={() => toggle(clsKey)}>
                            <span style={{ fontSize: '10px' }}>{clsOpen ? '▼' : '▶'}</span>
                            <span>{cls}</span>
                            <span style={s.pctTag(clsPct)}>{clsPct}%</span>
                            <span style={{ ...s.sub, marginLeft: '4px' }}>
                              ({clsHit}/{meths.length})
                            </span>
                          </div>

                          {/* Méthodes */}
                          {clsOpen &&
                            meths
                              .sort((a, b) => a.methodName.localeCompare(b.methodName))
                              .map((m) => (
                                <div key={m.methodId} style={s.methodRow}>
                                  <span style={s.badge(m.hit)}>{m.hit ? '✓' : '✕'}</span>
                                  <span style={s.methodName(m.hit)}>{m.methodName}</span>
                                  {m.line > 0 && (
                                    <span style={s.lineNum}>:{m.line}</span>
                                  )}
                                  <span style={s.callCount}>
                                    {m.calls > 0
                                      ? `${m.calls.toLocaleString('en-US')} calls`
                                      : 'never called'}
                                  </span>
                                </div>
                              ))}
                        </div>
                      );
                    })}
              </div>
            );
          })
      )}
    </div>
  );
}
