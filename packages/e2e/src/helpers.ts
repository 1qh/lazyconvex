/* eslint-disable no-await-in-loop */
import type { Page } from '@playwright/test'

import { api, ensureTestUser, tc } from './org-helpers'

const login = async (_page: Page) => {
    await ensureTestUser()
  },
  cleanupTestData = async () => {
    await ensureTestUser()
    let result = await tc.mutation(api.testauth.cleanupTestData, {})
    while (!result.done) result = await tc.mutation(api.testauth.cleanupTestData, {})
  }

export { cleanupTestData, login }
