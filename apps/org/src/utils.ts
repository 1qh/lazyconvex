import { ConvexHttpClient } from 'convex/browser'

const getTestClient = () =>
  // eslint-disable-next-line no-restricted-properties, @typescript-eslint/prefer-nullish-coalescing
  new ConvexHttpClient(process.env.NEXT_PUBLIC_CONVEX_URL || process.env.CONVEX_URL || '')

export { getTestClient }
