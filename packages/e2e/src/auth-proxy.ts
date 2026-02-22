/* eslint-disable no-empty, no-empty-function */
import { serve } from 'bun'
const BACKEND_API = 'http://127.0.0.1:3212'
const BACKEND_WS = 'ws://127.0.0.1:3212'
const SITE_URL = 'http://127.0.0.1:3211'

process.on('uncaughtException', () => {})
process.on('unhandledRejection', () => {})

serve({
  port: 3210,

  // eslint-disable-next-line max-statements
  async fetch(req, server) {
    try {
      const url = new URL(req.url)

      if (req.headers.get('upgrade')?.toLowerCase() === 'websocket') {
        if (server.upgrade(req, { data: { url: `${BACKEND_WS}${url.pathname}${url.search}` } })) {
          return
        }
        return new Response('WebSocket upgrade failed', { status: 500 })
      }

      const target = url.pathname.startsWith('/api/auth') ? SITE_URL : BACKEND_API
      const targetUrl = `${target}${url.pathname}${url.search}`

      const headers = new Headers(req.headers)
      headers.delete('host')

      const response = await fetch(targetUrl, {
        method: req.method,
        headers,
        body: req.body,
        redirect: 'manual'
      })

      return new Response(response.body, {
        status: response.status,
        statusText: response.statusText,
        headers: response.headers
      })
    } catch {
      return new Response('Proxy error', { status: 502 })
    }
  },

  websocket: {
    open(ws) {
      try {
        const { url } = ws.data as { url: string }
        const upstream = new WebSocket(url)
        ;(ws.data as Record<string, unknown>).upstream = upstream
        upstream.addEventListener('open', () => {
          ;(ws.data as Record<string, unknown>).ready = true
          const q = (ws.data as Record<string, unknown>).queue as (string | Buffer)[] | undefined
          if (q) {
            for (const m of q) upstream.send(m)
            ;(ws.data as Record<string, unknown>).queue = undefined
          }
        })
        upstream.addEventListener('message', event => {
          try {
            ws.send(event.data as string)
          } catch {}
        })
        upstream.addEventListener('close', () => {
          try {
            ws.close()
          } catch {}
        })
        upstream.addEventListener('error', () => {
          try {
            ws.close()
          } catch {}
        })
      } catch {}
    },
    message(ws, message) {
      try {
        const d = ws.data as Record<string, unknown>
        if (d.ready && d.upstream) {
          ;(d.upstream as WebSocket).send(message)
        } else {
          d.queue = d.queue ?? []
          ;(d.queue as (string | Buffer | ArrayBuffer)[]).push(message)
        }
      } catch {}
    },
    close(ws) {
      try {
        const d = ws.data as Record<string, unknown>
        ;(d.upstream as WebSocket)?.close()
      } catch {}
    }
  }
})
