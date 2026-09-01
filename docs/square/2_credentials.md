# Square Credentials

Square does not use a single platform API key in Pay. The per-merchant OAuth access token
is supplied at runtime by `Pay::Square.access_token_provider` (see
[Overview](1_overview.md)). The values below are app-level configuration, resolved like
every other Pay credential: `ENV`, then env-scoped Rails credentials, then unscoped Rails
credentials.

## Environment

Selects the Square API host (`production` or `sandbox`). Defaults to `production`.

```yaml
# rails credentials
square:
  environment: sandbox
```

```bash
export SQUARE_ENVIRONMENT=sandbox
```

## Webhook signing secret

The app-level signature key from your Square webhook subscription. This is **not** a
merchant OAuth token — it is a single app-level secret used to verify inbound webhooks.

```bash
export SQUARE_SIGNING_SECRET=...
```

## Webhook notification URL

Square computes the webhook HMAC over `notification_url + body`, so verification needs the
exact public URL registered with your Square webhook subscription. Behind a proxy or load
balancer `request.original_url` may not match, so set it explicitly:

```bash
export SQUARE_WEBHOOK_NOTIFICATION_URL=https://example.com/pay/webhooks/square
```

If unset, Pay falls back to the request URL.
