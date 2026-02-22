// biome-ignore-all lint/style/noProcessEnv: x

import { createEnv } from '@t3-oss/env-core'
import { string } from 'zod/v4'

export default createEnv({
  server: {
    TMDB_KEY: string()
  },
  runtimeEnv: process.env,
  skipValidation: Boolean(process.env.CI) || process.env.npm_lifecycle_event === 'lint'
})
