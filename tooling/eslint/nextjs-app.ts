import { defineConfig } from 'eslint/config'

import baseConfig from './base'
import convexApi from './convex-api'
import nextjsConfig from './nextjs'
import reactConfig from './react'
import restrictEnvAccess from './restrict-env'

export default defineConfig(
  { ignores: ['.next/**', 'e2e/**'] },
  baseConfig,
  reactConfig,
  nextjsConfig,
  restrictEnvAccess,
  convexApi
)
