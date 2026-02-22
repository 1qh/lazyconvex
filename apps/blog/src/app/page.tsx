'use client'

import { api } from '@a/be'
import { Input } from '@a/ui/input'
import { useList } from 'lazyconvex/react'
import { Search } from 'lucide-react'
import { useCallback, useDeferredValue, useState } from 'react'

import { Create, List } from './common'

const Page = () => {
  const { items, loadMore, status } = useList(api.blog.list, { where: { or: [{ published: true }, { own: true }] } }),
    [removedIds, setRemovedIds] = useState<Set<string>>(new Set()),
    [query, setQuery] = useState(''),
    deferredQuery = useDeferredValue(query.toLowerCase()),
    filtered = items.filter(b => {
      if (removedIds.has(b._id)) return false
      if (!deferredQuery) return true
      return (
        b.title.toLowerCase().includes(deferredQuery) ||
        b.content.toLowerCase().includes(deferredQuery) ||
        b.tags?.some((t: string) => t.toLowerCase().includes(deferredQuery))
      )
    }),
    handleRemove = useCallback((id: string) => {
      setRemovedIds(prev => new Set(prev).add(id))
    }, [])
  return (
    <div data-testid='crud-dynamic-page'>
      <Create />
      <div className='relative mb-4'>
        <Search className='absolute top-1/2 left-3 size-4 -translate-y-1/2 text-muted-foreground' />
        <Input
          className='pl-9'
          data-testid='blog-search-input'
          onChange={e => setQuery(e.target.value)}
          placeholder='Search blogs...'
          type='search'
          value={query}
        />
      </div>
      <List blogs={filtered} onRemove={handleRemove} />
      {!deferredQuery && status === 'CanLoadMore' ? (
        <button
          className='mx-auto mt-4 block text-sm text-muted-foreground hover:text-foreground'
          onClick={() => loadMore()}
          type='button'>
          Load more
        </button>
      ) : null}
    </div>
  )
}

export default Page
