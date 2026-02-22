import { test as baseTest } from '@playwright/test'

import ChatPage from './pages/chat'

interface Fixtures {
  chatPage: ChatPage
}

const test = baseTest.extend<Fixtures>({
  chatPage: async ({ page }, run) => {
    const chatPage = new ChatPage(page)
    await run(chatPage)
  }
})

export { test }
export { expect } from '@playwright/test'
