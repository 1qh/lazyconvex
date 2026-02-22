import { makeImageRoute } from 'lazyconvex/next'

import env from './env'

const { GET, POST } = await makeImageRoute({ convexUrl: env.NEXT_PUBLIC_CONVEX_URL })

export { GET, POST }
