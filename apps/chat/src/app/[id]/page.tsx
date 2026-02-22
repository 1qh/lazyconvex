import type { Id } from '@a/be/model'
import type { UIMessage } from 'ai'

import { api } from '@a/be'
import { fetchQuery } from 'convex/nextjs'
import { getToken, isAuthenticated } from 'lazyconvex/next'
import { redirect } from 'next/navigation'
import { connection } from 'next/server'
import { Suspense } from 'react'

import Client from './client'

const tryFetch = async <T,>(fn: () => Promise<T>): Promise<null | T> => {
    try {
      return await fn()
    } catch {
      return null
    }
  },
  toUIMessages = (messages: { _id: string; parts: unknown; role: 'assistant' | 'system' | 'user' }[]): UIMessage[] =>
    messages.map(m => ({
      id: m._id,
      parts: m.parts as UIMessage['parts'],
      role: m.role
    })),
  // eslint-disable-next-line max-statements
  Page = async ({ params }: { params: Promise<{ id: string }> }) => {
    await connection()
    const { id } = await params,
      chatId = id as Id<'chat'>,
      token = await getToken(),
      authed = await isAuthenticated(),
      opts = token ? { token } : {}

    if (authed) {
      const chat = await tryFetch(async () => fetchQuery(api.chat.read, { id: chatId }, opts))

      if (chat) {
        const messages = await fetchQuery(api.message.list, { chatId }, opts)
        return (
          <Suspense fallback={null}>
            <Client chatId={id} initialMessages={toUIMessages(messages)} />
          </Suspense>
        )
      }
    }

    const pubChat = await tryFetch(async () => fetchQuery(api.chat.pubRead, { id: chatId }))

    if (pubChat) {
      const messages = (await fetchQuery(api.message.pubList, { chatId })) as {
        _id: string
        parts: unknown
        role: 'assistant' | 'system' | 'user'
      }[]
      return (
        <Suspense fallback={null}>
          <Client chatId={id} initialMessages={toUIMessages(messages)} readOnly />
        </Suspense>
      )
    }

    redirect('/')
  }

export default Page
