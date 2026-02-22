import { expect as baseExpect, test as baseTest } from '@playwright/test'

import OnboardingPage from './pages/onboarding'

interface Fixtures {
  onboardingPage: OnboardingPage
}

const test = baseTest.extend<Fixtures>({
  onboardingPage: async ({ page }, run) => {
    const onboardingPage = new OnboardingPage(page)
    await run(onboardingPage)
  }
})

export { baseExpect as expect, test }
