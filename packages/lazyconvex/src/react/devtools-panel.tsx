/* eslint-disable complexity */
// oxlint-disable complexity
'use client'
import { useEffect, useState } from 'react'

import type { DevCacheEntry, DevError, DevMutation, DevSubscription } from './devtools'

import { SLOW_THRESHOLD_MS, STALE_THRESHOLD_MS, useDevErrors } from './devtools'

type TabId = 'cache' | 'errors' | 'mutations' | 'subs'

const formatTime = (ts: number) => {
    const d = new Date(ts),
      h = String(d.getHours()).padStart(2, '0'),
      mn = String(d.getMinutes()).padStart(2, '0'),
      s = String(d.getSeconds()).padStart(2, '0')
    return `${h}:${mn}:${s}`
  },
  MAX_BADGE = 99,
  WATERFALL_MAX_MS = 10_000,
  isStale = (sub: DevSubscription) => sub.status === 'loaded' && Date.now() - sub.lastUpdate > STALE_THRESHOLD_MS,
  isSlow = (sub: DevSubscription) => sub.latencyMs > SLOW_THRESHOLD_MS,
  ErrorRow = ({ error }: { error: DevError }) => {
    const [expanded, setExpanded] = useState(false),
      code = error.data?.code,
      table = error.data?.table,
      op = error.data?.op
    return (
      <li className='border-b border-red-900/30 last:border-b-0'>
        <button
          className='flex w-full items-start gap-2 px-3 py-2 text-left text-xs hover:bg-red-950/30'
          onClick={() => setExpanded(v => !v)}
          type='button'>
          <span className='shrink-0 pt-px font-mono text-red-400/60'>{formatTime(error.timestamp)}</span>
          {code ? <span className='shrink-0 rounded-sm bg-red-900/50 px-1 font-mono text-red-300'>{code}</span> : null}
          <span className='min-w-0 flex-1 truncate text-red-200'>{error.message}</span>
          <span className='shrink-0 text-red-400/40'>{expanded ? '\u25B2' : '\u25BC'}</span>
        </button>
        {expanded ? (
          <div className='space-y-1 bg-red-950/20 px-3 py-2 text-xs'>
            {table || op ? (
              <p className='font-mono text-red-400/80'>
                {table ? `table: ${table}` : ''}
                {table && op ? ' \u00B7 ' : ''}
                {op ? `op: ${op}` : ''}
              </p>
            ) : null}
            <p className='break-all whitespace-pre-wrap text-red-300/90'>{error.detail}</p>
          </div>
        ) : null}
      </li>
    )
  },
  SubRow = ({ sub }: { sub: DevSubscription }) => {
    const stale = isStale(sub),
      slow = isSlow(sub),
      statusColor =
        sub.status === 'loaded'
          ? stale
            ? 'text-yellow-400'
            : 'text-emerald-400'
          : sub.status === 'error'
            ? 'text-red-400'
            : 'text-blue-400',
      statusLabel = stale ? 'stale' : sub.status,
      latencyLabel = sub.latencyMs > 0 ? `${sub.latencyMs}ms` : ''
    return (
      <li className='flex items-center gap-2 border-b border-zinc-800 px-3 py-2 text-xs last:border-b-0'>
        <span
          className={`size-1.5 shrink-0 rounded-full ${sub.status === 'loaded' ? (stale ? 'bg-yellow-400' : 'bg-emerald-400') : sub.status === 'error' ? 'bg-red-400' : 'bg-blue-400'}`}
        />
        <span className='min-w-0 flex-1 truncate font-mono text-zinc-300'>{sub.query}</span>
        {latencyLabel ? (
          <span className={`shrink-0 font-mono tabular-nums ${slow ? 'text-orange-400' : 'text-zinc-500'}`}>
            {latencyLabel}
          </span>
        ) : null}
        <span className={`shrink-0 font-mono ${statusColor}`}>{statusLabel}</span>
        <span className='shrink-0 text-zinc-500 tabular-nums'>{sub.updateCount}x</span>
      </li>
    )
  },
  MutationRow = ({ mutation }: { mutation: DevMutation }) => {
    const statusColor =
        mutation.status === 'success'
          ? 'text-emerald-400'
          : mutation.status === 'error'
            ? 'text-red-400'
            : 'text-blue-400',
      durationLabel = mutation.durationMs > 0 ? `${mutation.durationMs}ms` : 'pending'
    return (
      <li className='flex items-center gap-2 border-b border-zinc-800 px-3 py-2 text-xs last:border-b-0'>
        <span
          className={`size-1.5 shrink-0 rounded-full ${mutation.status === 'success' ? 'bg-emerald-400' : mutation.status === 'error' ? 'bg-red-400' : 'animate-pulse bg-blue-400'}`}
        />
        <span className='shrink-0 pt-px font-mono text-zinc-500'>{formatTime(mutation.startedAt)}</span>
        <span className='min-w-0 flex-1 truncate font-mono text-zinc-300'>{mutation.name}</span>
        <span className={`shrink-0 font-mono tabular-nums ${statusColor}`}>{durationLabel}</span>
      </li>
    )
  },
  CacheRow = ({ entry }: { entry: DevCacheEntry }) => {
    const total = entry.hitCount + entry.missCount,
      hitRate = total > 0 ? Math.round((entry.hitCount / total) * 100) : 0
    return (
      <li className='flex items-center gap-2 border-b border-zinc-800 px-3 py-2 text-xs last:border-b-0'>
        <span className={`size-1.5 shrink-0 rounded-full ${entry.stale ? 'bg-yellow-400' : 'bg-emerald-400'}`} />
        <span className='shrink-0 font-mono text-zinc-500'>{entry.table}</span>
        <span className='min-w-0 flex-1 truncate font-mono text-zinc-300'>{entry.key}</span>
        <span
          className={`shrink-0 font-mono tabular-nums ${hitRate > 80 ? 'text-emerald-400' : hitRate > 50 ? 'text-yellow-400' : 'text-red-400'}`}>
          {hitRate}%
        </span>
        <span className='shrink-0 text-zinc-500 tabular-nums'>
          {entry.hitCount}h/{entry.missCount}m
        </span>
        {entry.stale ? <span className='shrink-0 font-mono text-yellow-400'>stale</span> : null}
      </li>
    )
  },
  WaterfallBar = ({ minStart, sub }: { minStart: number; sub: DevSubscription }) => {
    const [now, setNow] = useState(() => Date.now())
    useEffect(() => {
      if (sub.latencyMs > 0 || now - sub.startedAt >= WATERFALL_MAX_MS) return
      const id = setInterval(() => setNow(Date.now()), 500)
      return () => clearInterval(id)
    }, [sub.latencyMs, sub.startedAt, now])
    const offset = sub.startedAt - minStart,
      duration = sub.latencyMs || now - sub.startedAt,
      leftPct = Math.min((offset / WATERFALL_MAX_MS) * 100, 100),
      widthPct = Math.max(Math.min((duration / WATERFALL_MAX_MS) * 100, 100 - leftPct), 1),
      barColor =
        sub.status === 'loaded'
          ? isSlow(sub)
            ? 'bg-orange-500'
            : 'bg-emerald-500'
          : sub.status === 'error'
            ? 'bg-red-500'
            : 'bg-blue-500'
    return (
      <li className='flex items-center gap-2 border-b border-zinc-800 px-2 py-1.5 text-xs last:border-b-0'>
        <span className='w-28 shrink-0 truncate font-mono text-zinc-400'>{sub.query}</span>
        <span className='relative h-3 min-w-0 flex-1 rounded-sm bg-zinc-800/50'>
          <span
            className={`absolute top-0 h-full rounded-sm ${barColor}`}
            style={{ left: `${leftPct}%`, width: `${widthPct}%` }}
          />
        </span>
        <span className='w-12 shrink-0 text-right font-mono text-zinc-500 tabular-nums'>
          {sub.latencyMs > 0 ? `${sub.latencyMs}ms` : '...'}
        </span>
      </li>
    )
  },
  TabBtn = ({ active, label, onClick }: { active: boolean; label: string; onClick: () => void }) => (
    <button
      className={`rounded-sm px-2 py-0.5 text-xs ${active ? 'bg-zinc-800 text-zinc-200' : 'text-zinc-400 hover:text-zinc-200'}`}
      onClick={onClick}
      type='button'>
      {label}
    </button>
  ),
  LazyConvexDevtools = () => {
    const { cache, clear, clearMutations, errors, mutations, subscriptions } = useDevErrors(),
      [open, setOpen] = useState(false),
      [tab, setTab] = useState<TabId>('errors'),
      [showWaterfall, setShowWaterfall] = useState(false)

    if (typeof process !== 'undefined' && process.env.NODE_ENV === 'production') return null

    const errorCount = errors.length,
      subCount = subscriptions.length,
      mutCount = mutations.length,
      cacheCount = cache.length,
      staleCount = subscriptions.filter(isStale).length,
      slowCount = subscriptions.filter(isSlow).length,
      pendingCount = mutations.filter(m => m.status === 'pending').length,
      count = errorCount,
      minStart = subscriptions.length > 0 ? Math.min(...subscriptions.map(s => s.startedAt)) : 0
    if (!open)
      return (
        <button
          className={`fixed right-4 bottom-4 z-9999 flex size-10 items-center justify-center rounded-full shadow-lg transition-colors ${count > 0 ? 'bg-red-600 text-white hover:bg-red-700' : staleCount > 0 || pendingCount > 0 ? 'bg-yellow-600 text-white hover:bg-yellow-700' : 'bg-zinc-800 text-zinc-400 hover:bg-zinc-700'}`}
          onClick={() => setOpen(v => !v)}
          title='LazyConvex DevTools'
          type='button'>
          {count > 0 ? (
            <span className='text-sm font-bold'>{count > MAX_BADGE ? `${MAX_BADGE}+` : count}</span>
          ) : pendingCount > 0 ? (
            <span className='text-sm font-bold'>{pendingCount}</span>
          ) : staleCount > 0 ? (
            <span className='text-sm font-bold'>{staleCount}</span>
          ) : (
            <span className='text-base'>⚡</span>
          )}
        </button>
      )

    return (
      <div className='fixed right-4 bottom-4 z-9999 flex w-96 max-w-[calc(100vw-2rem)] flex-col overflow-hidden rounded-lg border border-zinc-800 bg-zinc-950 shadow-2xl'>
        <div className='flex items-center justify-between border-b border-zinc-800 bg-zinc-900 px-3 py-2'>
          <div className='flex gap-1'>
            <TabBtn
              active={tab === 'errors'}
              label={`Errors${errorCount > 0 ? ` (${errorCount})` : ''}`}
              onClick={() => setTab('errors')}
            />
            <TabBtn
              active={tab === 'subs'}
              label={`Subs${subCount > 0 ? ` (${subCount})` : ''}${staleCount > 0 ? ` \u00B7 ${staleCount}\u26A0` : ''}${slowCount > 0 ? ` \u00B7 ${slowCount}\u{1F422}` : ''}`}
              onClick={() => setTab('subs')}
            />
            <TabBtn
              active={tab === 'mutations'}
              label={`Mut${mutCount > 0 ? ` (${mutCount})` : ''}${pendingCount > 0 ? ` \u00B7 ${pendingCount}\u23F3` : ''}`}
              onClick={() => setTab('mutations')}
            />
            <TabBtn
              active={tab === 'cache'}
              label={`Cache${cacheCount > 0 ? ` (${cacheCount})` : ''}`}
              onClick={() => setTab('cache')}
            />
          </div>
          <div className='flex gap-1'>
            {tab === 'errors' && errorCount > 0 ? (
              <button
                className='rounded-sm px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
                onClick={clear}
                type='button'>
                Clear
              </button>
            ) : null}
            {tab === 'mutations' && mutCount > 0 ? (
              <button
                className='rounded-sm px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
                onClick={clearMutations}
                type='button'>
                Clear
              </button>
            ) : null}
            {tab === 'subs' && subCount > 0 ? (
              <button
                className='rounded-sm px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
                onClick={() => setShowWaterfall(v => !v)}
                type='button'>
                {showWaterfall ? 'List' : 'Waterfall'}
              </button>
            ) : null}
            <button
              className='rounded-sm px-2 py-0.5 text-xs text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200'
              onClick={() => setOpen(v => !v)}
              type='button'>
              ✕
            </button>
          </div>
        </div>
        <div className='max-h-80 overflow-y-auto'>
          {tab === 'errors' ? (
            errorCount === 0 ? (
              <p className='px-3 py-6 text-center text-xs text-zinc-500'>No errors</p>
            ) : (
              <ul>
                {errors.map(e => (
                  <ErrorRow error={e} key={e.id} />
                ))}
              </ul>
            )
          ) : tab === 'subs' ? (
            subCount === 0 ? (
              <p className='px-3 py-6 text-center text-xs text-zinc-500'>No active subscriptions</p>
            ) : showWaterfall ? (
              <ul>
                {subscriptions.map(s => (
                  <WaterfallBar key={s.id} minStart={minStart} sub={s} />
                ))}
              </ul>
            ) : (
              <ul>
                {subscriptions.map(s => (
                  <SubRow key={s.id} sub={s} />
                ))}
              </ul>
            )
          ) : tab === 'mutations' ? (
            mutCount === 0 ? (
              <p className='px-3 py-6 text-center text-xs text-zinc-500'>No mutations tracked</p>
            ) : (
              <ul>
                {mutations.map(m => (
                  <MutationRow key={m.id} mutation={m} />
                ))}
              </ul>
            )
          ) : cacheCount === 0 ? (
            <p className='px-3 py-6 text-center text-xs text-zinc-500'>No cache entries</p>
          ) : (
            <ul>
              {cache.map(c => (
                <CacheRow entry={c} key={c.id} />
              ))}
            </ul>
          )}
        </div>
      </div>
    )
  }

export default LazyConvexDevtools
