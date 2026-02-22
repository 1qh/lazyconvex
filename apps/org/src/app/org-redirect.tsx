const OrgRedirect = ({ orgId, slug, to }: { orgId: string; slug: string; to: string }) => (
  <script
    dangerouslySetInnerHTML={{
      __html: `window.location.href="/api/set-org?orgId=${encodeURIComponent(orgId)}&slug=${encodeURIComponent(slug)}&to=${encodeURIComponent(to)}"`
    }}
  />
)

export default OrgRedirect
